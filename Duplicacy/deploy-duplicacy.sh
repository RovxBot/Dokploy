#!/bin/bash

# Duplicacy Backup Deployment Script for Docker Swarm
# This script sets up Duplicacy backup solution with all required directories and permissions

set -e

echo "🚀 Duplicacy Backup Setup for Docker Swarm"
echo "=========================================="

# Configuration
APPDATA_BASE="/srv/appdata"
BACKUP_BASE="/srv/backups"
DUPLICACY_CONFIG_DIR="${APPDATA_BASE}/duplicacy"
DUPLICACY_BACKUP_DIR="${BACKUP_BASE}/duplicacy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script needs to be run with sudo privileges for directory creation"
        echo "Usage: sudo ./deploy-duplicacy.sh"
        exit 1
    fi
}

# Check if Docker Swarm is initialized
check_swarm() {
    print_status "Checking Docker Swarm status..."
    if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
        print_error "Docker Swarm is not initialized or this node is not part of a swarm"
        print_status "Initialize swarm with: docker swarm init"
        exit 1
    fi
    print_success "Docker Swarm is active"
}

# Create required directories
create_directories() {
    print_status "Creating required directories..."
    
    # Duplicacy directories
    mkdir -p "${DUPLICACY_CONFIG_DIR}/config"
    mkdir -p "${DUPLICACY_CONFIG_DIR}/cache"
    mkdir -p "${DUPLICACY_CONFIG_DIR}/logs"
    mkdir -p "${DUPLICACY_CONFIG_DIR}/credentials"
    
    # Backup storage directory
    mkdir -p "${DUPLICACY_BACKUP_DIR}"
    
    # Set permissions (1000:1000 is common for Docker containers)
    chown -R 1000:1000 "${DUPLICACY_CONFIG_DIR}"
    chown -R 1000:1000 "${DUPLICACY_BACKUP_DIR}"
    
    # Set appropriate permissions
    chmod -R 755 "${DUPLICACY_CONFIG_DIR}"
    chmod -R 755 "${DUPLICACY_BACKUP_DIR}"
    
    print_success "Directories created and permissions set"
}

# Check if .env file exists
check_env_file() {
    if [[ ! -f ".env" ]]; then
        print_warning ".env file not found"
        print_status "Copying template from duplicacy-backup.env..."
        
        if [[ -f "duplicacy-backup.env" ]]; then
            cp duplicacy-backup.env .env
            print_success "Template copied to .env"
            print_warning "Please edit .env file with your configuration before deploying"
            print_status "Minimum required: Set ADMIN_PASSWORD and configure storage settings"
            return 1
        else
            print_error "Template file duplicacy-backup.env not found"
            return 1
        fi
    fi
    print_success ".env file found"
    return 0
}

# Validate environment configuration
validate_config() {
    print_status "Validating configuration..."
    
    # Source the .env file
    set -a
    source .env
    set +a
    
    # Check for required variables
    if [[ -z "${ADMIN_PASSWORD}" ]] || [[ "${ADMIN_PASSWORD}" == "your-secure-password-here" ]]; then
        print_error "ADMIN_PASSWORD not set or using default value"
        print_status "Please set a secure password in .env file"
        return 1
    fi
    
    if [[ -z "${STORAGE_TYPE}" ]]; then
        print_warning "STORAGE_TYPE not set, defaulting to 'local'"
    fi
    
    print_success "Configuration validation passed"
    return 0
}

# Deploy the stack
deploy_stack() {
    print_status "Deploying Duplicacy stack to Docker Swarm..."
    
    if docker stack deploy -c duplicacy-backup.yaml duplicacy; then
        print_success "Duplicacy stack deployed successfully"
        return 0
    else
        print_error "Failed to deploy Duplicacy stack"
        return 1
    fi
}

# Wait for service to be ready
wait_for_service() {
    print_status "Waiting for Duplicacy service to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker service ls --filter name=duplicacy_duplicacy --format "{{.Replicas}}" | grep -q "1/1"; then
            print_success "Duplicacy service is ready"
            return 0
        fi
        
        print_status "Attempt $attempt/$max_attempts - Service not ready yet, waiting..."
        sleep 10
        ((attempt++))
    done
    
    print_error "Service did not become ready within expected time"
    print_status "Check service status with: docker service ls"
    print_status "Check service logs with: docker service logs duplicacy_duplicacy"
    return 1
}

# Show post-deployment information
show_info() {
    echo ""
    echo "🎉 Duplicacy Backup Setup Complete!"
    echo "=================================="
    echo ""
    echo "📍 Access Information:"
    echo "   Web Interface: http://duplicacy.cooked.beer"
    echo "   Admin Password: (as configured in .env file)"
    echo ""
    echo "📁 Directory Structure:"
    echo "   Config: ${DUPLICACY_CONFIG_DIR}"
    echo "   Backups: ${DUPLICACY_BACKUP_DIR}"
    echo ""
    echo "🔧 Management Commands:"
    echo "   View services: docker service ls"
    echo "   View logs: docker service logs duplicacy_duplicacy"
    echo "   Scale CLI: docker service scale duplicacy_duplicacy-cli=1"
    echo "   Remove stack: docker stack rm duplicacy"
    echo ""
    echo "📖 Next Steps:"
    echo "   1. Access the web interface"
    echo "   2. Configure your storage backend"
    echo "   3. Create backup repositories"
    echo "   4. Set up backup schedules"
    echo "   5. Test your first backup"
    echo ""
    echo "📚 Documentation: See DUPLICACY-SETUP.md for detailed configuration"
}

# Main execution
main() {
    check_permissions
    check_swarm
    create_directories
    
    if ! check_env_file; then
        print_warning "Please configure .env file and run the script again"
        exit 1
    fi
    
    if ! validate_config; then
        print_warning "Please fix configuration issues and run the script again"
        exit 1
    fi
    
    if deploy_stack && wait_for_service; then
        show_info
    else
        print_error "Deployment failed. Check the logs for more information."
        exit 1
    fi
}

# Run main function
main "$@"
