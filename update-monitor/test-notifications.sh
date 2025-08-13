#!/bin/bash

# Test script for update monitor notifications

echo "🧪 Testing Update Monitor Notifications..."
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Source environment variables
source .env

echo "📋 Configuration Check:"
echo "   Webhook URL: ${WEBHOOK_URL:0:50}..."
echo "   Email To: ${EMAIL_TO}"
echo "   SMTP Host: ${SMTP_HOST}"
echo ""

# Test Power Automate webhook notification
if [ ! -z "$WEBHOOK_URL" ]; then
    echo "🔗 Testing Power Automate workflow notification..."

    test_payload='{
        "title": "Update Monitor Test",
        "service": "test-service",
        "registry": "docker.io",
        "currentVersion": "1.0.0",
        "latestVersion": "1.1.0",
        "releaseDate": "'"$(date '+%Y-%m-%d %H:%M:%S')"'",
        "dockerHubUrl": "https://hub.docker.com/r/test/service",
        "fullImageName": "docker.io/test/service:1.1.0",
        "timestamp": "'"$(date '+%Y-%m-%d %H:%M:%S')"'",
        "updateAvailable": true,
        "severity": "test"
    }'
    
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$test_payload" \
        "$WEBHOOK_URL")
    
    http_code="${response: -3}"
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 204 ]; then
        echo "   ✅ Webhook test successful (HTTP $http_code)"
    else
        echo "   ❌ Webhook test failed (HTTP $http_code)"
        echo "   Response: ${response%???}"
    fi
else
    echo "   ⚠️  No webhook URL configured, skipping webhook test"
fi

echo ""

# Check Docker services with monitoring labels
echo "🏷️  Checking services with monitoring labels:"
services_with_labels=$(docker service ls --filter label=diun.enable=true --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}" 2>/dev/null)

if [ ! -z "$services_with_labels" ]; then
    echo "$services_with_labels"
    service_count=$(echo "$services_with_labels" | tail -n +2 | wc -l)
    echo ""
    echo "   📊 Found $service_count services configured for monitoring"
else
    echo "   ⚠️  No services found with monitoring labels"
    echo "   Run ./add-monitoring-labels.sh to add labels to your services"
fi

echo ""

# Check if update monitor stack is deployed
echo "🚀 Checking update monitor deployment:"
if docker stack ls | grep -q "update-monitor"; then
    echo "   ✅ Update monitor stack is deployed"
    
    # Check service status
    echo ""
    echo "📊 Service Status:"
    docker stack services update-monitor
else
    echo "   ⚠️  Update monitor stack not deployed"
    echo "   Run: docker stack deploy -c compose.yml update-monitor"
fi

echo ""
echo "🎉 Test completed!"
echo ""
echo "Next steps:"
echo "1. If webhook test failed, check your webhook URL in .env"
echo "2. If no services have labels, run ./add-monitoring-labels.sh"
echo "3. If stack not deployed, run: docker stack deploy -c compose.yml update-monitor"
echo "4. Monitor will run every Sunday at 9 AM Australia/Adelaide time"
