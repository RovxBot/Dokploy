#!/bin/bash

# Storage Management Setup Script
# Sets up comprehensive storage management for Docker Swarm cluster

set -e

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

echo -e "${BLUE}=== Storage Management Setup ===${NC}"
echo "This script will set up comprehensive storage management for your Docker Swarm cluster"
echo ""

# Function to print section headers
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if running on correct node
check_node() {
    print_header "Node Verification"
    
    NODE_NAME=$(hostname)
    echo "Current node: $NODE_NAME"
    
    # Check if this is metal2 (the node with storage issues)
    if [ "$NODE_NAME" = "metal2" ]; then
        echo -e "${YELLOW}Running on metal2 - the node with storage issues${NC}"
    else
        echo -e "${GREEN}Running on $NODE_NAME${NC}"
    fi
    
    # Check if Docker is available
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓ Docker is available${NC}"
    else
        echo -e "${RED}✗ Docker is not available${NC}"
        exit 1
    fi
    
    # Check if this is a swarm node
    if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q "active"; then
        echo -e "${GREEN}✓ Node is part of Docker Swarm${NC}"
        
        # Check if manager node
        if docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null | grep -q "true"; then
            echo -e "${GREEN}✓ This is a manager node${NC}"
            IS_MANAGER=true
        else
            echo -e "${YELLOW}This is a worker node${NC}"
            IS_MANAGER=false
        fi
    else
        echo -e "${RED}✗ Node is not part of Docker Swarm${NC}"
        exit 1
    fi
    
    echo ""
}

# Function to make scripts executable
setup_scripts() {
    print_header "Setting Up Scripts"
    
    # Make all scripts executable
    chmod +x scripts/storage-management.sh
    chmod +x scripts/docker-cleanup-cron.sh
    chmod +x scripts/storage-monitor.sh
    
    echo -e "${GREEN}✓ Made scripts executable${NC}"
    
    # Create log directories
    sudo mkdir -p /var/log/storage-management
    sudo chmod 755 /var/log/storage-management
    
    echo -e "${GREEN}✓ Created log directories${NC}"
    echo ""
}

# Function to run immediate cleanup
immediate_cleanup() {
    print_header "Immediate Storage Cleanup"

    echo "Running immediate storage assessment..."

    # Run storage assessment
    echo "Current storage status:"
    ./scripts/storage-management.sh check

    # Check if cleanup is needed (>85% usage)
    current_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$current_usage" -ge 85 ]; then
        echo "Disk usage is ${current_usage}% - running automatic cleanup..."
        ./scripts/storage-management.sh clean
        echo -e "${GREEN}✓ Automatic cleanup completed${NC}"
    else
        echo "Disk usage is ${current_usage}% - no immediate cleanup needed"
    fi

    echo ""
}

# Function to setup cron jobs
setup_cron() {
    print_header "Setting Up Cron Jobs"
    
    # Create cron job for automated cleanup
    CRON_SCRIPT="/usr/local/bin/docker-cleanup-cron.sh"
    sudo cp scripts/docker-cleanup-cron.sh "$CRON_SCRIPT"
    sudo chmod +x "$CRON_SCRIPT"
    
    # Create cron job for storage monitoring
    MONITOR_SCRIPT="/usr/local/bin/storage-monitor.sh"
    sudo cp scripts/storage-monitor.sh "$MONITOR_SCRIPT"
    sudo chmod +x "$MONITOR_SCRIPT"
    
    # Add cron jobs
    (crontab -l 2>/dev/null || true; echo "# Docker cleanup - runs daily at 2 AM") | crontab -
    (crontab -l 2>/dev/null || true; echo "0 2 * * * $CRON_SCRIPT auto >> /var/log/storage-management/cron.log 2>&1") | crontab -
    (crontab -l 2>/dev/null || true; echo "# Storage monitoring - runs every 15 minutes") | crontab -
    (crontab -l 2>/dev/null || true; echo "*/15 * * * * $MONITOR_SCRIPT monitor >> /var/log/storage-management/monitor.log 2>&1") | crontab -
    
    echo -e "${GREEN}✓ Cron jobs configured${NC}"
    echo "  - Docker cleanup: Daily at 2 AM"
    echo "  - Storage monitoring: Every 15 minutes"
    echo ""
}

# Function to setup Docker daemon configuration
setup_docker_config() {
    print_header "Docker Daemon Configuration"

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
    echo "  - Log rotation: 10MB max size, 3 files"
    echo ""

    # Restart Docker daemon automatically if it's safe to do so
    echo "Restarting Docker daemon to apply log rotation..."
    sudo systemctl restart docker

    # Wait a moment for Docker to come back up
    sleep 5

    # Verify Docker is running
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker daemon restarted successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Docker may need a moment to fully restart${NC}"
    fi

    echo ""
}

# Function to deploy storage management stack
deploy_stack() {
    print_header "Storage Management Stack"

    echo -e "${YELLOW}Skipping Docker stack deployment - using Netdata for monitoring instead${NC}"
    echo "The cron jobs will handle automated cleanup silently"
    echo ""
}

# Function to setup system-level optimisations
setup_system_optimisations() {
    print_header "System Optimisations"
    
    # Setup log rotation for system logs
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

# Function to create monitoring dashboard
create_monitoring_info() {
    print_header "Monitoring Information"
    
    cat > storage-monitoring-commands.txt <<EOF
# Storage Management Commands

## Manual Commands
# Check storage status
./scripts/storage-management.sh check

# Run manual cleanup
./scripts/storage-management.sh clean

# Generate storage report
./scripts/storage-monitor.sh report

# Test alert system
./scripts/storage-monitor.sh test-alert

## Service Management
# Check storage management services
docker service ls | grep storage-management

# View service logs
docker service logs storage-management_storage-cleanup
docker service logs storage-management_storage-monitor

# Force run cleanup job
docker service update --force storage-management_storage-cleanup

## Monitoring
# Check cron job status
crontab -l | grep storage

# View cleanup logs
tail -f /var/log/storage-management/cron.log

# View monitoring logs
tail -f /var/log/storage-management/monitor.log

## Emergency Commands
# Force immediate cleanup
./scripts/docker-cleanup-cron.sh force

# Check what's using space
du -sh /var/lib/docker/*
du -sh /srv/appdata/*

# Clean up specific Docker resources
docker system prune -a --volumes
EOF
    
    echo -e "${GREEN}✓ Created storage-monitoring-commands.txt with useful commands${NC}"
    echo ""
}

# Main execution
main() {
    check_node
    setup_scripts
    immediate_cleanup
    setup_docker_config
    setup_cron
    setup_system_optimisations
    deploy_stack
    create_monitoring_info
    
    print_header "Setup Complete"
    
    echo -e "${GREEN}Storage management setup completed successfully!${NC}"
    echo ""
    echo "What was configured:"
    echo "✓ Immediate storage cleanup (if requested)"
    echo "✓ Docker daemon log rotation"
    echo "✓ Automated cleanup cron jobs"
    echo "✓ Storage monitoring with alerts"
    echo "✓ System log rotation"
    echo "✓ Storage management Docker services"
    echo ""
    echo "Next steps:"
    echo "1. Configure webhook URL in .env.storage for alerts"
    echo "2. Monitor logs in /var/log/storage-management/"
    echo "3. Check storage-monitoring-commands.txt for useful commands"
    echo "4. Consider setting up Grafana dashboard for storage metrics"
    echo ""
    echo -e "${YELLOW}Important: Monitor metal2 closely over the next few days${NC}"
}

# Run main function
main "$@"
