#!/bin/bash

# Test script for Power Automate webhook with adaptive card data
# This sends a test payload that matches what DIUN will send

# Load environment variables
if [[ -f .env ]]; then
    source .env
else
    echo "❌ .env file not found. Please create it first."
    exit 1
fi

if [[ -z "$WEBHOOK_URL" ]]; then
    echo "❌ WEBHOOK_URL not set in .env file"
    exit 1
fi

echo "🧪 Testing Power Automate webhook with adaptive card data..."
echo "📡 Webhook URL: ${WEBHOOK_URL:0:50}..."

# Test payload that matches the DIUN template
TEST_PAYLOAD='{
  "service": "nginx",
  "registry": "docker.io",
  "currentVersion": "1.21.0",
  "latestVersion": "1.25.3",
  "releaseDate": "2024-01-15 10:30:00",
  "dockerHubUrl": "https://hub.docker.com/r/_/nginx",
  "fullImageName": "docker.io/nginx:1.25.3",
  "platform": "linux/amd64",
  "timestamp": "2024-01-21 09:00:00",
  "updateAvailable": true,
  "severity": "info"
}'

echo "📤 Sending test payload..."
echo "📋 Payload:"
echo "$TEST_PAYLOAD" | jq .

# Send the test payload
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$TEST_PAYLOAD" \
  "$WEBHOOK_URL")

# Extract HTTP code and response body
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo ""
echo "📨 Response:"
echo "HTTP Status: $HTTP_CODE"

if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "202" ]]; then
    echo "✅ Test successful! Check your Teams channel for the adaptive card."
    echo "🎯 The card should now show:"
    echo "   - Image: nginx"
    echo "   - Host: docker.io"
    echo "   - Current Version: 1.21.0"
    echo "   - Latest Version: 1.25.3"
    echo "   - Created: 2024-01-15 10:30:00"
else
    echo "❌ Test failed with HTTP $HTTP_CODE"
    if [[ -n "$RESPONSE_BODY" ]]; then
        echo "Response body: $RESPONSE_BODY"
    fi
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   1. Check that your Power Automate flow is enabled"
    echo "   2. Verify the webhook URL is correct"
    echo "   3. Check Power Automate run history for errors"
fi

echo ""
echo "🔄 To deploy the updated configuration:"
echo "   docker stack deploy -c compose-powerautomate.yml update-monitor"
