#!/bin/bash

# Script to discover and add monitoring labels to Docker Swarm services
# This script automatically finds your services and adds monitoring labels

echo "🔍 Discovering Docker Swarm services..."
echo ""

# Get all running services
all_services=$(docker service ls --format "{{.Name}}")

if [ -z "$all_services" ]; then
    echo "❌ No Docker Swarm services found. Are you running this on a manager node?"
    echo "   Make sure Docker Swarm is initialized and services are deployed."
    exit 1
fi

echo "📋 Found these services:"
docker service ls --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}"
echo ""

# Define patterns for services we want to monitor
# These patterns will match your application services
monitor_patterns=(
    "jellyfin"
    "sonarr"
    "radarr" 
    "prowlarr"
    "sabnzbd"
    "jellyseerr"
    "homeassistant"
    "nodered"
    "immich"
    "vaultwarden"
    "cloudflared"
    "redis"
    "database"
    "postgres"
)

# Services to exclude from monitoring (system services)
exclude_patterns=(
    "traefik"
    "dokploy"
    "shepherd"
    "swarm-cronjob"
    "update-monitor"
    "diun"
)

echo "🏷️  Adding monitoring labels to application services..."
echo ""

labeled_count=0
skipped_count=0

# Process each service
for service in $all_services; do
    should_monitor=false
    should_exclude=false
    
    # Check if service matches monitoring patterns
    for pattern in "${monitor_patterns[@]}"; do
        if [[ "$service" == *"$pattern"* ]]; then
            should_monitor=true
            break
        fi
    done
    
    # Check if service should be excluded
    for pattern in "${exclude_patterns[@]}"; do
        if [[ "$service" == *"$pattern"* ]]; then
            should_exclude=true
            break
        fi
    done
    
    if [ "$should_exclude" = true ]; then
        echo "⏭️  Skipping system service: $service"
        ((skipped_count++))
        continue
    fi
    
    if [ "$should_monitor" = true ]; then
        echo "📦 Adding monitoring labels to: $service"
        
        # Add the monitoring labels
        if docker service update \
            --label-add "diun.enable=true" \
            --label-add "update-monitor=true" \
            "$service" >/dev/null 2>&1; then
            echo "   ✅ Successfully labeled $service"
            ((labeled_count++))
        else
            echo "   ❌ Failed to label $service"
        fi
    else
        echo "⏭️  Skipping unrecognized service: $service"
        ((skipped_count++))
    fi
done

echo ""
echo "📊 Summary:"
echo "   ✅ Services labeled for monitoring: $labeled_count"
echo "   ⏭️  Services skipped: $skipped_count"
echo ""

if [ $labeled_count -gt 0 ]; then
    echo "🎉 Monitoring labels added successfully!"
    echo ""
    echo "📋 Services now being monitored:"
    docker service ls --filter label=diun.enable=true --format "table {{.Name}}\t{{.Image}}"
    echo ""
    echo "Next steps:"
    echo "1. Configure your .env file with the Power Automate webhook URL"
    echo "2. Test notifications: ./test-notifications.sh"
    echo "3. Deploy the monitor: docker stack deploy -c compose-powerautomate.yml update-monitor"
else
    echo "⚠️  No services were labeled. This might mean:"
    echo "   - Your services use different naming conventions"
    echo "   - Services are not deployed as Docker Swarm services"
    echo "   - You need to run this on a manager node"
    echo ""
    echo "🔧 Manual labeling:"
    echo "   You can manually add labels to specific services:"
    echo "   docker service update --label-add 'diun.enable=true' SERVICE_NAME"
fi
