#!/bin/bash

# Automated Docker Cleanup Script for Cron
# Designed to run regularly to prevent storage issues

set -e

# Configuration
LOG_FILE="/var/log/docker-cleanup.log"
MAX_LOG_SIZE="50M"
CLEANUP_THRESHOLD=80  # Run cleanup when disk usage exceeds this percentage

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if we need to rotate our own log file
rotate_log_if_needed() {
    if [ -f "$LOG_FILE" ]; then
        # Check if log file is larger than MAX_LOG_SIZE
        if [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 52428800 ]; then  # 50MB in bytes
            mv "$LOG_FILE" "${LOG_FILE}.old"
            touch "$LOG_FILE"
            log_message "Rotated cleanup log file"
        fi
    fi
}

# Check disk usage
get_disk_usage() {
    df / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Docker cleanup function
perform_docker_cleanup() {
    log_message "Starting Docker cleanup process"
    
    # Get initial disk usage
    initial_usage=$(get_disk_usage)
    log_message "Initial disk usage: ${initial_usage}%"
    
    # Remove stopped containers
    log_message "Removing stopped containers..."
    docker container prune -f >> "$LOG_FILE" 2>&1
    
    # Remove unused images (not tagged and not referenced by any container)
    log_message "Removing unused images..."
    docker image prune -f >> "$LOG_FILE" 2>&1
    
    # Remove unused volumes (be careful - only removes truly unused volumes)
    log_message "Removing unused volumes..."
    docker volume prune -f >> "$LOG_FILE" 2>&1
    
    # Remove build cache
    log_message "Removing build cache..."
    docker builder prune -f >> "$LOG_FILE" 2>&1
    
    # Clean up networks
    log_message "Removing unused networks..."
    docker network prune -f >> "$LOG_FILE" 2>&1
    
    # Get final disk usage
    final_usage=$(get_disk_usage)
    log_message "Final disk usage: ${final_usage}%"
    
    # Calculate space freed
    space_freed=$((initial_usage - final_usage))
    log_message "Space freed: ${space_freed}% of disk"
    
    log_message "Docker cleanup completed successfully"
}

# System log cleanup
perform_log_cleanup() {
    log_message "Starting system log cleanup"
    
    # Clean systemd journal logs (keep last 7 days)
    if command -v journalctl &> /dev/null; then
        log_message "Cleaning systemd journal logs..."
        journalctl --vacuum-time=7d >> "$LOG_FILE" 2>&1
    fi
    
    # Clean Docker container logs older than 7 days
    log_message "Cleaning old Docker container logs..."
    if [ -d "/var/lib/docker/containers" ]; then
        find /var/lib/docker/containers -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
    fi
    
    # Clean rotated log files older than 14 days
    log_message "Cleaning old rotated log files..."
    find /var/log -name "*.log.*" -type f -mtime +14 -delete 2>/dev/null || true
    find /var/log -name "*.gz" -type f -mtime +14 -delete 2>/dev/null || true
    
    log_message "System log cleanup completed"
}

# PostgreSQL maintenance (specific for Immich database)
perform_postgres_maintenance() {
    log_message "Starting PostgreSQL maintenance for Immich database"
    
    # Check if Immich database container is running
    if docker ps --format "{{.Names}}" | grep -q "immich.*database\|database.*immich"; then
        container_name=$(docker ps --format "{{.Names}}" | grep "immich.*database\|database.*immich" | head -1)
        
        log_message "Found Immich database container: $container_name"
        
        # Run VACUUM ANALYZE to reclaim space and update statistics
        log_message "Running VACUUM ANALYZE on Immich database..."
        docker exec "$container_name" psql -U postgres -d immich -c "VACUUM ANALYZE;" >> "$LOG_FILE" 2>&1
        
        # Clean up old WAL files (PostgreSQL write-ahead logs)
        log_message "Cleaning up PostgreSQL WAL files..."
        docker exec "$container_name" psql -U postgres -d immich -c "CHECKPOINT;" >> "$LOG_FILE" 2>&1
        
        log_message "PostgreSQL maintenance completed"
    else
        log_message "Immich database container not found or not running"
    fi
}

# Main cleanup function
main() {
    # Rotate our log file if needed
    rotate_log_if_needed
    
    log_message "=== Starting automated cleanup process ==="
    
    # Check current disk usage
    current_usage=$(get_disk_usage)
    log_message "Current disk usage: ${current_usage}%"
    
    # Only run cleanup if usage exceeds threshold
    if [ "$current_usage" -ge "$CLEANUP_THRESHOLD" ]; then
        log_message "Disk usage (${current_usage}%) exceeds threshold (${CLEANUP_THRESHOLD}%). Running cleanup..."
        
        # Perform cleanups
        perform_docker_cleanup
        perform_log_cleanup
        
        # Run PostgreSQL maintenance weekly (check if it's Sunday)
        if [ "$(date +%u)" -eq 7 ]; then
            perform_postgres_maintenance
        fi
        
        # Final disk usage check
        final_usage=$(get_disk_usage)
        log_message "Cleanup completed. Final disk usage: ${final_usage}%"
        
        # Send alert if still high
        if [ "$final_usage" -ge 90 ]; then
            log_message "WARNING: Disk usage still critical (${final_usage}%) after cleanup!"
            # You could add notification logic here (email, webhook, etc.)
        fi
    else
        log_message "Disk usage (${current_usage}%) is below threshold (${CLEANUP_THRESHOLD}%). No cleanup needed."
    fi
    
    log_message "=== Cleanup process completed ==="
    echo ""  # Add blank line to log for readability
}

# Handle command line arguments
case "${1:-auto}" in
    "auto")
        main
        ;;
    "force")
        log_message "=== Forced cleanup initiated ==="
        perform_docker_cleanup
        perform_log_cleanup
        perform_postgres_maintenance
        log_message "=== Forced cleanup completed ==="
        ;;
    "docker")
        perform_docker_cleanup
        ;;
    "logs")
        perform_log_cleanup
        ;;
    "postgres")
        perform_postgres_maintenance
        ;;
    "status")
        current_usage=$(get_disk_usage)
        echo "Current disk usage: ${current_usage}%"
        echo "Cleanup threshold: ${CLEANUP_THRESHOLD}%"
        echo "Last cleanup log entries:"
        tail -10 "$LOG_FILE" 2>/dev/null || echo "No log file found"
        ;;
    *)
        echo "Usage: $0 [auto|force|docker|logs|postgres|status]"
        echo ""
        echo "Commands:"
        echo "  auto     - Run cleanup only if disk usage exceeds threshold (default)"
        echo "  force    - Force full cleanup regardless of disk usage"
        echo "  docker   - Clean only Docker resources"
        echo "  logs     - Clean only log files"
        echo "  postgres - Run PostgreSQL maintenance"
        echo "  status   - Show current status and recent log entries"
        exit 1
        ;;
esac
