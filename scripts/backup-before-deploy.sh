#!/bin/bash

# Pre-deployment backup script using Duplicacy
# Creates snapshots before deployments for rollback capability

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="$SCRIPT_DIR/../logs"
CONFIG_DIR="$SCRIPT_DIR/../config"

mkdir -p "$LOGS_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/backup.log"
}

# Check if Duplicacy is available
check_duplicacy() {
    if ! command -v duplicacy &> /dev/null; then
        log "Error: Duplicacy not found. Please install Duplicacy CLI"
        exit 1
    fi
}

# Create backup snapshot
create_snapshot() {
    local service_name="$1"
    local backup_path="$2"
    local snapshot_id="${service_name}-pre-deploy-$(date +%Y%m%d-%H%M%S)"
    
    log "Creating backup snapshot for $service_name"
    
    if [ ! -d "$backup_path" ]; then
        log "Warning: Backup path $backup_path does not exist, skipping backup for $service_name"
        return 0
    fi
    
    cd "$backup_path"
    
    # Initialize repository if not already done
    if [ ! -d ".duplicacy" ]; then
        log "Initializing Duplicacy repository for $service_name"
        if [ -f "$CONFIG_DIR/duplicacy.env" ]; then
            source "$CONFIG_DIR/duplicacy.env"
            duplicacy init "$service_name" "b2://${B2_BUCKET}/${service_name}"
        else
            log "Error: duplicacy.env not found. Cannot initialize repository"
            return 1
        fi
    fi
    
    # Create snapshot
    log "Creating snapshot: $snapshot_id"
    if duplicacy backup -stats -threads 2 -tag "pre-deploy"; then
        log "Backup snapshot created successfully for $service_name"
        return 0
    else
        log "Error: Failed to create backup snapshot for $service_name"
        return 1
    fi
}

# Backup service data
backup_service() {
    local service="$1"
    
    case "$service" in
        "jellyfin")
            create_snapshot "jellyfin" "/var/lib/jellyfin-db"
            ;;
        "immich")
            create_snapshot "immich" "/srv/appdata/immich"
            ;;
        "vaultwarden")
            # Vaultwarden data is in NFS, backup not needed for deployment
            log "Vaultwarden uses NFS storage, skipping local backup"
            ;;
        "sonarr")
            # Sonarr config is in NFS, backup not needed for deployment
            log "Sonarr uses NFS storage, skipping local backup"
            ;;
        "sabnzbd")
            # SABnzbd config is in NFS, backup not needed for deployment
            log "SABnzbd uses NFS storage, skipping local backup"
            ;;
        "prowlarr")
            # Prowlarr config is in NFS, backup not needed for deployment
            log "Prowlarr uses NFS storage, skipping local backup"
            ;;
        "jellyseerr")
            # Jellyseerr config is in NFS, backup not needed for deployment
            log "Jellyseerr uses NFS storage, skipping local backup"
            ;;
        "radarr")
            # Radarr config is in NFS, backup not needed for deployment
            log "Radarr uses NFS storage, skipping local backup"
            ;;
        "homeassistant")
            # Home Assistant config is in NFS, backup not needed for deployment
            log "Home Assistant uses NFS storage, skipping local backup"
            ;;
        *)
            log "No specific backup configuration for $service"
            ;;
    esac
}

# Main backup function
main() {
    local service="$1"
    
    if [ -z "$service" ]; then
        echo "Usage: $0 <service_name>"
        echo ""
        echo "Creates pre-deployment backup snapshots"
        echo ""
        echo "Available services:"
        echo "  jellyfin, immich, vaultwarden, sonarr, sabnzbd"
        echo "  prowlarr, jellyseerr, radarr, homeassistant"
        exit 1
    fi
    
    log "=== Pre-deployment Backup Started for $service ==="
    
    check_duplicacy
    backup_service "$service"
    
    log "=== Pre-deployment Backup Completed for $service ==="
}

# Run main function
main "$@"
