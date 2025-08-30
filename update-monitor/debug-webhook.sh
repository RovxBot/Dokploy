#!/bin/bash

# Debug script to see what DIUN actually sends
# This will help us understand the JSON structure

echo "🔍 DIUN Webhook Debug Tool"
echo "=========================="
echo ""
echo "This script will:"
echo "1. Start a temporary webhook receiver"
echo "2. Show you exactly what JSON DIUN sends"
echo "3. Help you fix your Power Automate adaptive card"
echo ""

# Check if nc (netcat) is available
if ! command -v nc &> /dev/null; then
    echo "❌ netcat (nc) not found. Installing..."
    # Try different package managers
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y netcat
    elif command -v yum &> /dev/null; then
        sudo yum install -y nc
    elif command -v apk &> /dev/null; then
        sudo apk add netcat-openbsd
    else
        echo "❌ Cannot install netcat. Please install it manually."
        exit 1
    fi
fi

# Create a simple HTTP server to capture the webhook
PORT=8888
echo "🌐 Starting webhook receiver on port $PORT..."
echo "📡 Webhook URL: http://$(hostname -I | awk '{print $1}'):$PORT/webhook"
echo ""
echo "⚠️  IMPORTANT: Update your .env file temporarily:"
echo "   WEBHOOK_URL=http://$(hostname -I | awk '{print $1}'):$PORT/webhook"
echo ""
echo "Then redeploy DIUN:"
echo "   docker stack deploy -c compose-powerautomate.yml update-monitor"
echo ""
echo "🔄 Waiting for webhook data... (Press Ctrl+C to stop)"
echo "=================================================="

# Simple HTTP server that logs all requests
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK" | nc -l -p $PORT -q 1 | while IFS= read -r line; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') | $line"
    done
done
