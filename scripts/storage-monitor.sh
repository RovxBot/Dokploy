#!/bin/bash

# Storage Monitoring Script for Docker Swarm Cluster
# Sends alerts when storage usage exceeds thresholds

set -e

# Configuration
WARNING_THRESHOLD=85
CRITICAL_THRESHOLD=90
WEBHOOK_URL="${STORAGE_ALERT_WEBHOOK_URL:-}"
EMAIL_TO="${STORAGE_ALERT_EMAIL:-}"
LOG_FILE="/var/log/storage-monitor.log"

# Node identification
NODE_NAME=$(hostname)
NODE_IP=$(hostname -I | awk '{print $1}')

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Get disk usage for all mounted filesystems
get_disk_usage() {
    df -h | grep -E '^/dev/' | while read line; do
        filesystem=$(echo $line | awk '{print $1}')
        size=$(echo $line | awk '{print $2}')
        used=$(echo $line | awk '{print $3}')
        available=$(echo $line | awk '{print $4}')
        usage_percent=$(echo $line | awk '{print $5}' | sed 's/%//')
        mountpoint=$(echo $line | awk '{print $6}')
        
        echo "$filesystem|$size|$used|$available|$usage_percent|$mountpoint"
    done
}

# Check Docker-specific usage
get_docker_usage() {
    if command -v docker &> /dev/null; then
        # Get Docker root directory usage
        docker_root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
        if [ -d "$docker_root" ]; then
            docker_size=$(du -sh "$docker_root" 2>/dev/null | cut -f1 || echo "Unknown")
            echo "docker_root|$docker_size|$docker_root"
        fi
        
        # Get Docker system usage
        docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}" 2>/dev/null | tail -n +2 | while read line; do
            type=$(echo $line | awk '{print $1}')
            count=$(echo $line | awk '{print $2}')
            size=$(echo $line | awk '{print $3}')
            reclaimable=$(echo $line | awk '{print $4}')
            echo "docker_$type|$count|$size|$reclaimable"
        done
    fi
}

# Get application data usage
get_app_data_usage() {
    if [ -d "/srv/appdata" ]; then
        for app_dir in /srv/appdata/*/; do
            if [ -d "$app_dir" ]; then
                app_name=$(basename "$app_dir")
                size=$(du -sh "$app_dir" 2>/dev/null | cut -f1 || echo "Unknown")
                echo "app_$app_name|$size|$app_dir"
            fi
        done
    fi
}

# Send webhook notification
send_webhook_alert() {
    local severity="$1"
    local message="$2"
    local details="$3"
    
    if [ -n "$WEBHOOK_URL" ]; then
        # Create JSON payload for Microsoft Teams/Power Automate
        json_payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "$([ "$severity" = "CRITICAL" ] && echo "FF0000" || echo "FFA500")",
    "summary": "Storage Alert - $NODE_NAME",
    "sections": [{
        "activityTitle": "🚨 Storage Alert - $severity",
        "activitySubtitle": "$NODE_NAME ($NODE_IP)",
        "facts": [
            {
                "name": "Node",
                "value": "$NODE_NAME"
            },
            {
                "name": "Severity",
                "value": "$severity"
            },
            {
                "name": "Message",
                "value": "$message"
            },
            {
                "name": "Details",
                "value": "$details"
            },
            {
                "name": "Timestamp",
                "value": "$(date)"
            }
        ]
    }],
    "potentialAction": [{
        "@type": "OpenUri",
        "name": "View Node Dashboard",
        "targets": [{
            "os": "default",
            "uri": "http://$NODE_IP:19999"
        }]
    }]
}
EOF
        )
        
        # Send webhook
        curl -X POST \
            -H "Content-Type: application/json" \
            -d "$json_payload" \
            "$WEBHOOK_URL" \
            --silent --show-error >> "$LOG_FILE" 2>&1 || log_message "Failed to send webhook alert"
    fi
}

# Send email notification (if configured)
send_email_alert() {
    local severity="$1"
    local message="$2"
    local details="$3"
    
    if [ -n "$EMAIL_TO" ] && command -v mail &> /dev/null; then
        subject="Storage Alert [$severity] - $NODE_NAME"
        body="Storage alert for node $NODE_NAME ($NODE_IP)

Severity: $severity
Message: $message
Details: $details

Timestamp: $(date)

Please check the node and take appropriate action."
        
        echo "$body" | mail -s "$subject" "$EMAIL_TO" || log_message "Failed to send email alert"
    fi
}

# Main monitoring function
monitor_storage() {
    log_message "Starting storage monitoring check"
    
    # Track if any alerts were sent
    alerts_sent=false
    alert_details=""
    
    # Check disk usage
    get_disk_usage | while IFS='|' read filesystem size used available usage_percent mountpoint; do
        if [ "$usage_percent" -ge "$CRITICAL_THRESHOLD" ]; then
            message="CRITICAL: $mountpoint is ${usage_percent}% full (${used}/${size})"
            log_message "$message"
            alert_details="$alert_details\n$message"
            alerts_sent=true
            
            # Send immediate critical alert
            send_webhook_alert "CRITICAL" "$message" "Filesystem: $filesystem\nMount: $mountpoint\nUsage: ${usage_percent}%\nUsed: $used\nTotal: $size"
            send_email_alert "CRITICAL" "$message" "Filesystem: $filesystem\nMount: $mountpoint\nUsage: ${usage_percent}%\nUsed: $used\nTotal: $size"
            
        elif [ "$usage_percent" -ge "$WARNING_THRESHOLD" ]; then
            message="WARNING: $mountpoint is ${usage_percent}% full (${used}/${size})"
            log_message "$message"
            alert_details="$alert_details\n$message"
            
            # Send warning alert (less frequent)
            send_webhook_alert "WARNING" "$message" "Filesystem: $filesystem\nMount: $mountpoint\nUsage: ${usage_percent}%\nUsed: $used\nTotal: $size"
        else
            log_message "OK: $mountpoint is ${usage_percent}% full (${used}/${size})"
        fi
    done
    
    # Check Docker usage
    log_message "Checking Docker resource usage..."
    get_docker_usage | while IFS='|' read type info1 info2 info3; do
        log_message "Docker $type: $info1 $info2 $info3"
    done
    
    # Check application data usage
    log_message "Checking application data usage..."
    get_app_data_usage | while IFS='|' read app size path; do
        log_message "App data $app: $size ($path)"
    done
    
    log_message "Storage monitoring check completed"
}

# Generate storage report
generate_report() {
    echo "=== Storage Report for $NODE_NAME ==="
    echo "Generated: $(date)"
    echo ""
    
    echo "=== Disk Usage ==="
    get_disk_usage | while IFS='|' read filesystem size used available usage_percent mountpoint; do
        status="OK"
        if [ "$usage_percent" -ge "$CRITICAL_THRESHOLD" ]; then
            status="CRITICAL"
        elif [ "$usage_percent" -ge "$WARNING_THRESHOLD" ]; then
            status="WARNING"
        fi
        printf "%-20s %-10s %-8s %-8s %-8s %s\n" "$mountpoint" "$status" "${usage_percent}%" "$used" "$size" "$filesystem"
    done
    echo ""
    
    echo "=== Docker Usage ==="
    if command -v docker &> /dev/null; then
        docker system df
    else
        echo "Docker not available"
    fi
    echo ""
    
    echo "=== Application Data ==="
    get_app_data_usage | while IFS='|' read app size path; do
        app_clean=$(echo $app | sed 's/app_//')
        printf "%-20s %-10s %s\n" "$app_clean" "$size" "$path"
    done
    echo ""
    
    echo "=== Recommendations ==="
    get_disk_usage | while IFS='|' read filesystem size used available usage_percent mountpoint; do
        if [ "$usage_percent" -ge "$CRITICAL_THRESHOLD" ]; then
            echo "🚨 URGENT: $mountpoint needs immediate attention"
            echo "   - Run cleanup scripts immediately"
            echo "   - Consider emergency storage expansion"
        elif [ "$usage_percent" -ge "$WARNING_THRESHOLD" ]; then
            echo "⚠️  WARNING: $mountpoint approaching capacity"
            echo "   - Schedule cleanup maintenance"
            echo "   - Monitor growth trends"
        fi
    done
}

# Main execution
case "${1:-monitor}" in
    "monitor")
        monitor_storage
        ;;
    "report")
        generate_report
        ;;
    "test-alert")
        log_message "Testing alert system..."
        send_webhook_alert "TEST" "Storage monitoring test alert" "This is a test of the storage monitoring alert system from $NODE_NAME"
        send_email_alert "TEST" "Storage monitoring test alert" "This is a test of the storage monitoring alert system from $NODE_NAME"
        log_message "Test alert sent"
        ;;
    "help")
        echo "Usage: $0 [monitor|report|test-alert|help]"
        echo ""
        echo "Commands:"
        echo "  monitor    - Run storage monitoring check (default)"
        echo "  report     - Generate detailed storage report"
        echo "  test-alert - Send test alert to verify notification setup"
        echo "  help       - Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  STORAGE_ALERT_WEBHOOK_URL - Webhook URL for alerts"
        echo "  STORAGE_ALERT_EMAIL       - Email address for alerts"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
