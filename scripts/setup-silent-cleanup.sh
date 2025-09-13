#!/bin/bash

# Silent Storage Management Setup Script
# Sets up automated cleanup without monitoring (using Netdata instead)

set -e

# Colours for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

echo -e "${BLUE}=== Silent Storage Management Setup ===${NC}"
echo "Setting up automated cleanup for metal2..."
echo ""

# Function to print section headers
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to make scripts executable
setup_scripts() {
    print_header "Setting Up Scripts"
    
    # Make scripts executable
    chmod +x scripts/storage-management.sh
    chmod +x scripts/docker-cleanup-cron.sh
    
    echo -e "${GREEN}✓ Made scripts executable${NC}"
    
    # Create log directories
    sudo mkdir -p /var/log/storage-management
    sudo chmod 755 /var/log/storage-management
    
    echo -e "${GREEN}✓ Created log directories${NC}"
    echo ""
}

# Function to check and cleanup if needed
check_and_cleanup() {
    print_header "Storage Assessment"
    
    echo "Checking current storage usage..."
    
    # Get current usage
    current_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "Current disk usage: ${current_usage}%"
    
    # Auto-cleanup if over 85%
    if [ "$current_usage" -ge 85 ]; then
        echo "Disk usage is high (${current_usage}%) - running cleanup..."
        ./scripts/storage-management.sh clean
        
        # Check usage after cleanup
        new_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
        echo "Usage after cleanup: ${new_usage}%"
        echo -e "${GREEN}✓ Cleanup completed${NC}"
    else
        echo "Disk usage is acceptable (${current_usage}%) - no immediate cleanup needed"
    fi
    
    echo ""
}

# Function to setup Docker daemon configuration
setup_docker_config() {
    print_header "Docker Log Rotation"
    
    # Create or update Docker daemon configuration for log rotation
    DOCKER_CONFIG="/etc/docker/daemon.json"
    
    if [ -f "$DOCKER_CONFIG" ]; then
        echo "Backing up existing Docker daemon configuration..."
        sudo cp "$DOCKER_CONFIG" "${DOCKER_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create new configuration with log rotation
    sudo tee "$DOCKER_CONFIG" > /dev/null <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF
    
    echo -e "${GREEN}✓ Docker daemon configuration updated${NC}"
    echo "  - Log rotation: 10MB max size, 3 files per container"
    
    # Restart Docker daemon
    echo "Restarting Docker daemon..."
    sudo systemctl restart docker
    
    # Wait for Docker to come back up
    sleep 5
    
    # Verify Docker is running
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker daemon restarted successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Docker may need a moment to fully restart${NC}"
    fi
    
    echo ""
}

# Function to setup cron jobs
setup_cron() {
    print_header "Automated Cleanup Cron Jobs"

    # Create cron script in system location
    CRON_SCRIPT="/usr/local/bin/docker-cleanup-cron.sh"
    sudo cp scripts/docker-cleanup-cron.sh "$CRON_SCRIPT"
    sudo chmod +x "$CRON_SCRIPT"

    # Check what cron system is available
    if command -v crontab >/dev/null 2>&1; then
        # Standard crontab
        echo "Using crontab for scheduling..."

        # Remove any existing storage management cron jobs
        crontab -l 2>/dev/null | grep -v "docker-cleanup-cron\|storage-management" | crontab - 2>/dev/null || true

        # Add new cron jobs
        (crontab -l 2>/dev/null || true; echo "# Docker cleanup - runs daily at 2 AM") | crontab -
        (crontab -l 2>/dev/null || true; echo "0 2 * * * $CRON_SCRIPT auto >> /var/log/storage-management/cleanup.log 2>&1") | crontab -

    elif [ -d "/etc/cron.d" ]; then
        # System cron directory
        echo "Using /etc/cron.d for scheduling..."

        sudo tee /etc/cron.d/docker-cleanup > /dev/null <<EOF
# Docker cleanup - runs daily at 2 AM
0 2 * * * root $CRON_SCRIPT auto >> /var/log/storage-management/cleanup.log 2>&1
EOF

    else
        # Fallback: create systemd timer
        echo "Creating systemd timer for scheduling..."

        # Create systemd service
        sudo tee /etc/systemd/system/docker-cleanup.service > /dev/null <<EOF
[Unit]
Description=Docker Storage Cleanup
After=docker.service

[Service]
Type=oneshot
ExecStart=$CRON_SCRIPT auto
StandardOutput=append:/var/log/storage-management/cleanup.log
StandardError=append:/var/log/storage-management/cleanup.log
EOF

        # Create systemd timer
        sudo tee /etc/systemd/system/docker-cleanup.timer > /dev/null <<EOF
[Unit]
Description=Run Docker Storage Cleanup Daily
Requires=docker-cleanup.service

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

        # Enable and start the timer
        sudo systemctl daemon-reload
        sudo systemctl enable docker-cleanup.timer
        sudo systemctl start docker-cleanup.timer
    fi

    echo -e "${GREEN}✓ Cron job configured${NC}"
    echo "  - Daily cleanup at 2 AM (only runs if disk usage > 80%)"
    echo "  - Logs to: /var/log/storage-management/cleanup.log"
    echo ""
}

# Function to setup system-level optimisations
setup_system_optimisations() {
    print_header "System Log Rotation"
    
    # Setup log rotation for Docker containers
    sudo tee /etc/logrotate.d/docker-containers > /dev/null <<EOF
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
    
    echo -e "${GREEN}✓ Docker container log rotation configured${NC}"
    
    # Setup systemd journal limits
    sudo mkdir -p /etc/systemd/journald.conf.d
    sudo tee /etc/systemd/journald.conf.d/storage.conf > /dev/null <<EOF
[Journal]
SystemMaxUse=500M
SystemMaxFileSize=50M
SystemMaxFiles=10
MaxRetentionSec=7day
EOF
    
    echo -e "${GREEN}✓ Systemd journal limits configured${NC}"
    
    # Restart journald to apply changes
    sudo systemctl restart systemd-journald
    
    echo -e "${GREEN}✓ Journal service restarted${NC}"
    echo ""
}

# Function to setup PostgreSQL maintenance
setup_postgres_maintenance() {
    print_header "PostgreSQL Maintenance"
    
    # Create PostgreSQL maintenance script
    POSTGRES_SCRIPT="/usr/local/bin/postgres-maintenance.sh"
    
    sudo tee "$POSTGRES_SCRIPT" > /dev/null <<'EOF'
#!/bin/bash

# PostgreSQL maintenance script for Immich database
LOG_FILE="/var/log/storage-management/postgres-maintenance.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Find Immich database container
DB_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "immich.*database|database.*immich" | head -1)

if [ -n "$DB_CONTAINER" ]; then
    log_message "Starting PostgreSQL maintenance on container: $DB_CONTAINER"
    
    # Run VACUUM ANALYZE to reclaim space and update statistics
    log_message "Running VACUUM ANALYZE..."
    docker exec "$DB_CONTAINER" psql -U postgres -d immich -c "VACUUM ANALYZE;" >> "$LOG_FILE" 2>&1
    
    # Run CHECKPOINT to clean up WAL files
    log_message "Running CHECKPOINT..."
    docker exec "$DB_CONTAINER" psql -U postgres -d immich -c "CHECKPOINT;" >> "$LOG_FILE" 2>&1
    
    log_message "PostgreSQL maintenance completed successfully"
else
    log_message "ERROR: Immich database container not found"
fi
EOF
    
    sudo chmod +x "$POSTGRES_SCRIPT"
    
    # Add PostgreSQL maintenance to cron (weekly on Sunday at 3 AM)
    if command -v crontab >/dev/null 2>&1; then
        # Standard crontab
        (crontab -l 2>/dev/null || true; echo "# PostgreSQL maintenance - weekly on Sunday at 3 AM") | crontab -
        (crontab -l 2>/dev/null || true; echo "0 3 * * 0 $POSTGRES_SCRIPT >> /var/log/storage-management/postgres-maintenance.log 2>&1") | crontab -
    elif [ -d "/etc/cron.d" ]; then
        # System cron directory
        sudo tee -a /etc/cron.d/docker-cleanup > /dev/null <<EOF
# PostgreSQL maintenance - weekly on Sunday at 3 AM
0 3 * * 0 root $POSTGRES_SCRIPT >> /var/log/storage-management/postgres-maintenance.log 2>&1
EOF
    else
        # Create additional systemd timer for PostgreSQL maintenance
        sudo tee /etc/systemd/system/postgres-maintenance.service > /dev/null <<EOF
[Unit]
Description=PostgreSQL Maintenance for Immich
After=docker.service

[Service]
Type=oneshot
ExecStart=$POSTGRES_SCRIPT
StandardOutput=append:/var/log/storage-management/postgres-maintenance.log
StandardError=append:/var/log/storage-management/postgres-maintenance.log
EOF

        sudo tee /etc/systemd/system/postgres-maintenance.timer > /dev/null <<EOF
[Unit]
Description=Run PostgreSQL Maintenance Weekly
Requires=postgres-maintenance.service

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable postgres-maintenance.timer
        sudo systemctl start postgres-maintenance.timer
    fi
    
    echo -e "${GREEN}✓ PostgreSQL maintenance configured${NC}"
    echo "  - Weekly VACUUM and CHECKPOINT on Sunday at 3 AM"
    echo "  - Logs to: /var/log/storage-management/postgres-maintenance.log"
    echo ""
}

# Function to create monitoring commands reference
create_monitoring_info() {
    print_header "Monitoring Commands"
    
    # Create the file in the current directory or home directory
    if [ -d "$HOME" ] && [ -w "$HOME" ]; then
        COMMANDS_FILE="$HOME/storage-commands.txt"
    else
        COMMANDS_FILE="./storage-commands.txt"
    fi

    cat > "$COMMANDS_FILE" <<EOF
# Storage Management Commands for Metal2

## Check Status
df -h                                    # Check disk usage
./scripts/storage-management.sh check    # Detailed storage analysis
docker system df                         # Docker resource usage

## Manual Cleanup
./scripts/storage-management.sh clean    # Full cleanup
docker system prune -a --volumes        # Emergency Docker cleanup

## View Logs
tail -f /var/log/storage-management/cleanup.log              # Cleanup logs
tail -f /var/log/storage-management/postgres-maintenance.log # DB maintenance logs

## Cron Jobs
crontab -l                              # View scheduled jobs
sudo systemctl status cron             # Check cron service

## Emergency Commands (if disk > 95%)
docker system prune -a --volumes --force
journalctl --vacuum-time=1d
find /tmp -type f -mtime +1 -delete
EOF
    
    echo -e "${GREEN}✓ Created $COMMANDS_FILE with useful commands${NC}"
    echo ""
}

# Main execution
main() {
    setup_scripts
    check_and_cleanup
    setup_docker_config
    setup_cron
    setup_system_optimisations
    setup_postgres_maintenance
    create_monitoring_info
    
    print_header "Setup Complete"
    
    echo -e "${GREEN}Silent storage management setup completed!${NC}"
    echo ""
    echo "What was configured:"
    echo "✓ Docker log rotation (10MB max per container)"
    echo "✓ Daily automated cleanup at 2 AM (if disk > 80%)"
    echo "✓ Weekly PostgreSQL maintenance on Sunday at 3 AM"
    echo "✓ System log rotation and limits"
    echo "✓ All operations run silently in background"
    echo ""
    echo "Monitoring:"
    echo "• Use your existing Netdata for storage alerts"
    echo "• Check logs in /var/log/storage-management/"
    echo "• Reference commands in $COMMANDS_FILE"
    echo ""
    echo -e "${YELLOW}The cleanup will run automatically - no manual intervention needed${NC}"
}

# Run main function
main "$@"
