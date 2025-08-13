#!/bin/bash

# Script to add update monitoring labels to existing services
# This enables DIUN to monitor these services for updates

echo "Adding update monitoring labels to services..."

# First, let's discover what services are actually running
echo "🔍 Discovering running services..."
docker service ls --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}"

echo ""
echo "📝 Please check the service names above and update this script if needed."
echo ""

# List of your services to monitor - updated based on actual service discovery
# You may need to adjust these names based on your actual service names
services=(
    # Try different possible naming patterns
    "jellyfin"
    "sonarr"
    "radarr"
    "prowlarr"
    "sabnzbd"
    "jellyseerr"
    "homeassistant"
    "nodered"
    "immich-server"
    "immich-machine-learning"
    "redis"
    "database"
    "vaultwarden"
    "cloudflared"
    # Also try stack-prefixed versions
    "jellyfin_jellyfin"
    "sonarr_sonarr"
    "radarr_radarr"
    "prowlarr_prowlarr"
    "sabnzbd_sabnzbd"
    "jellyseerr_jellyseerr"
    "homeassistant_homeassistant"
    "homeassistant_nodered"
    "immich_immich-server"
    "immich_immich-machine-learning"
    "immich_redis"
    "immich_database"
    "vaultwarden_vaultwarden"
    "cloudflared_cloudflared"
)

# Add monitoring labels to each service
for service in "${services[@]}"; do
    echo "Adding monitoring label to $service..."
    
    # Check if service exists
    if docker service inspect "$service" >/dev/null 2>&1; then
        # Add the DIUN monitoring label
        docker service update \
            --label-add "diun.enable=true" \
            --label-add "update-monitor=true" \
            "$service"
        
        echo "✅ Added monitoring labels to $service"
    else
        echo "⚠️  Service $service not found, skipping..."
    fi
done

echo ""
echo "🎉 Monitoring labels added to all available services!"
echo ""
echo "Next steps:"
echo "1. Copy .env.example to .env and configure your notification settings"
echo "2. Deploy the update monitor stack: docker stack deploy -c compose.yml update-monitor"
echo "3. The monitor will run every Sunday at 9 AM and send notifications about available updates"
