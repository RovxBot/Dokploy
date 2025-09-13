#!/bin/bash

# Storage Management Script for Docker Swarm Cluster
# Specifically designed for metal2 node storage issues

set -e

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

# Configuration
DISK_WARNING_THRESHOLD=85
DISK_CRITICAL_THRESHOLD=90
LOG_RETENTION_DAYS=7
DOCKER_LOG_MAX_SIZE="10m"
DOCKER_LOG_MAX_FILE="3"

echo -e "${BLUE}=== Docker Swarm Storage Management Tool ===${NC}"
echo "Date: $(date)"
echo "Node: $(hostname)"
echo ""

# Function to print section headers
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check disk usage
check_disk_usage() {
    print_header "Current Disk Usage"
    
    # Overall disk usage
    df -h | grep -E '^/dev/' | while read line; do
        usage=$(echo $line | awk '{print $5}' | sed 's/%//')
        filesystem=$(echo $line | awk '{print $1}')
        mountpoint=$(echo $line | awk '{print $6}')
        
        if [ "$usage" -ge "$DISK_CRITICAL_THRESHOLD" ]; then
            echo -e "${RED}CRITICAL: $filesystem ($mountpoint) is ${usage}% full${NC}"
        elif [ "$usage" -ge "$DISK_WARNING_THRESHOLD" ]; then
            echo -e "${YELLOW}WARNING: $filesystem ($mountpoint) is ${usage}% full${NC}"
        else
            echo -e "${GREEN}OK: $filesystem ($mountpoint) is ${usage}% full${NC}"
        fi
    done
    
    echo ""
    echo "Detailed disk usage:"
    df -h
    echo ""
}

# Function to show largest directories
show_largest_dirs() {
    print_header "Largest Directories (Top 10)"
    
    echo "Scanning root filesystem..."
    du -h --max-depth=2 / 2>/dev/null | sort -hr | head -20 | grep -v "Permission denied" || true
    echo ""
    
    echo "Docker-specific directories:"
    if [ -d "/var/lib/docker" ]; then
        echo "Docker root: $(du -sh /var/lib/docker 2>/dev/null || echo 'Cannot access')"
    fi
    
    if [ -d "/srv/appdata" ]; then
        echo "App data: $(du -sh /srv/appdata 2>/dev/null || echo 'Cannot access')"
        echo ""
        echo "App data breakdown:"
        du -sh /srv/appdata/* 2>/dev/null | sort -hr || true
    fi
    echo ""
}

# Function to check Docker disk usage
check_docker_usage() {
    print_header "Docker Disk Usage"
    
    if command -v docker &> /dev/null; then
        echo "Docker system disk usage:"
        docker system df
        echo ""
        
        echo "Docker images:"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -10
        echo ""
        
        echo "Docker volumes:"
        docker volume ls -q | wc -l | xargs echo "Total volumes:"
        docker system df -v | grep -A 20 "Local Volumes space usage:" || true
        echo ""
    else
        echo "Docker not available on this node"
    fi
}

# Function to clean Docker system
clean_docker_system() {
    print_header "Docker System Cleanup"
    
    if command -v docker &> /dev/null; then
        echo "Cleaning up Docker system..."
        
        # Remove unused containers
        echo "Removing stopped containers..."
        docker container prune -f
        
        # Remove unused images
        echo "Removing unused images..."
        docker image prune -f
        
        # Remove unused volumes (be careful with this)
        echo "Removing unused volumes..."
        docker volume prune -f
        
        # Remove build cache
        echo "Removing build cache..."
        docker builder prune -f
        
        # Show space freed
        echo ""
        echo "Cleanup complete. Current Docker usage:"
        docker system df
    else
        echo "Docker not available for cleanup"
    fi
}

# Function to clean system logs
clean_system_logs() {
    print_header "System Log Cleanup"
    
    echo "Cleaning system logs older than $LOG_RETENTION_DAYS days..."
    
    # Clean journal logs
    if command -v journalctl &> /dev/null; then
        echo "Cleaning systemd journal logs..."
        journalctl --vacuum-time=${LOG_RETENTION_DAYS}d
    fi
    
    # Clean Docker container logs
    echo "Cleaning Docker container logs..."
    if [ -d "/var/lib/docker/containers" ]; then
        find /var/lib/docker/containers -name "*.log" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    fi
    
    # Clean general log files
    echo "Cleaning old log files in /var/log..."
    find /var/log -name "*.log.*" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    find /var/log -name "*.gz" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    
    echo "Log cleanup complete."
    echo ""
}

# Function to check specific application data
check_app_data() {
    print_header "Application Data Analysis"
    
    # Check Immich database size (specific to your setup)
    if [ -d "/srv/appdata/immich/postgres" ]; then
        echo "Immich PostgreSQL database size:"
        du -sh /srv/appdata/immich/postgres
        
        # Check for large log files
        if [ -d "/srv/appdata/immich/postgres/log" ]; then
            echo "PostgreSQL log files:"
            ls -lah /srv/appdata/immich/postgres/log/ 2>/dev/null || echo "No log directory found"
        fi
    fi
    
    # Check other app data
    echo ""
    echo "Application data sizes:"
    if [ -d "/srv/appdata" ]; then
        for app_dir in /srv/appdata/*/; do
            if [ -d "$app_dir" ]; then
                app_name=$(basename "$app_dir")
                size=$(du -sh "$app_dir" 2>/dev/null | cut -f1)
                echo "$app_name: $size"
            fi
        done
    fi
    echo ""
}

# Function to show recommendations
show_recommendations() {
    print_header "Storage Management Recommendations"
    
    echo "Based on the analysis, here are recommended actions:"
    echo ""
    echo "1. IMMEDIATE ACTIONS:"
    echo "   - Run 'docker system prune -a' to clean unused Docker resources"
    echo "   - Clean old log files with 'journalctl --vacuum-time=7d'"
    echo "   - Check for large files with 'find / -size +1G -type f 2>/dev/null'"
    echo ""
    echo "2. REGULAR MAINTENANCE:"
    echo "   - Set up log rotation for Docker containers"
    echo "   - Schedule weekly Docker cleanup"
    echo "   - Monitor database growth and implement regular VACUUM"
    echo ""
    echo "3. MONITORING:"
    echo "   - Set up disk usage alerts at 85% capacity"
    echo "   - Monitor Docker volume growth"
    echo "   - Track application data growth trends"
    echo ""
    echo "4. LONG-TERM SOLUTIONS:"
    echo "   - Consider moving large data to NFS storage"
    echo "   - Implement automated backup and cleanup policies"
    echo "   - Add additional storage capacity if needed"
    echo ""
}

# Main execution
main() {
    case "${1:-check}" in
        "check")
            check_disk_usage
            show_largest_dirs
            check_docker_usage
            check_app_data
            show_recommendations
            ;;
        "clean")
            check_disk_usage
            clean_docker_system
            clean_system_logs
            echo ""
            echo -e "${GREEN}Cleanup complete! Checking results...${NC}"
            check_disk_usage
            ;;
        "docker-clean")
            clean_docker_system
            ;;
        "log-clean")
            clean_system_logs
            ;;
        "help")
            echo "Usage: $0 [check|clean|docker-clean|log-clean|help]"
            echo ""
            echo "Commands:"
            echo "  check        - Analyse current storage usage (default)"
            echo "  clean        - Perform full cleanup (Docker + logs)"
            echo "  docker-clean - Clean only Docker resources"
            echo "  log-clean    - Clean only log files"
            echo "  help         - Show this help message"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
