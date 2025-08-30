#!/bin/bash

# Dokploy Deployment Script
# Automates deployment of services using webhook URLs

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"
LOGS_DIR="$SCRIPT_DIR/../logs"

# Create directories if they don't exist
mkdir -p "$LOGS_DIR"

# Source webhook URLs
if [ -f "$CONFIG_DIR/webhooks.env" ]; then
    source "$CONFIG_DIR/webhooks.env"
else
    echo "Error: webhooks.env not found in $CONFIG_DIR"
    echo "Please create this file with your webhook URLs"
    exit 1
fi

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/deploy.log"
}

# Health check function
check_service_health() {
    local service_name="$1"
    local url="$2"
    local max_attempts=30
    local attempt=1
    
    log "Checking health of $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log "$service_name is healthy"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts: $service_name not ready yet..."
        sleep 10
        ((attempt++))
    done
    
    log "Warning: $service_name health check failed after $max_attempts attempts"
    return 1
}

# Deploy function
deploy_service() {
    local service_name="$1"
    local webhook_url="$2"
    local health_check_url="$3"
    
    log "Starting deployment of $service_name"
    
    # Trigger deployment via webhook
    if curl -s -X POST "$webhook_url" > /dev/null; then
        log "Deployment triggered successfully for $service_name"
        
        # Wait a moment for deployment to start
        sleep 5
        
        # Check health if URL provided
        if [ -n "$health_check_url" ]; then
            check_service_health "$service_name" "$health_check_url"
        fi
        
        log "Deployment completed for $service_name"
        return 0
    else
        log "Error: Failed to trigger deployment for $service_name"
        return 1
    fi
}

# Main deployment function
main() {
    local service="$1"
    
    log "=== Dokploy Deployment Started ==="
    
    case "$service" in
        "jellyfin")
            deploy_service "Jellyfin" "$JELLYFIN_WEBHOOK" "http://192.168.1.190:8096"
            ;;
        "immich")
            deploy_service "Immich" "$IMMICH_WEBHOOK" "https://immich.cooked.beer"
            ;;
        "vaultwarden")
            deploy_service "Vaultwarden" "$VAULTWARDEN_WEBHOOK" "https://vaultwarden.cooked.beer"
            ;;
        "sonarr")
            deploy_service "Sonarr" "$SONARR_WEBHOOK" "https://sonarr.cooked.beer"
            ;;
        "sabnzbd")
            deploy_service "SABnzbd" "$SABNZBD_WEBHOOK" "https://sabnzbd.cooked.beer"
            ;;
        "prowlarr")
            deploy_service "Prowlarr" "$PROWLARR_WEBHOOK" "https://prowlarr.cooked.beer"
            ;;
        "jellyseerr")
            deploy_service "Jellyseerr" "$JELLYSEERR_WEBHOOK" "https://jellyseerr.cooked.beer"
            ;;
        "radarr")
            deploy_service "Radarr" "$RADARR_WEBHOOK" "https://radarr.cooked.beer"
            ;;
        "cloudflared")
            deploy_service "Cloudflared" "$CLOUDFLARED_WEBHOOK"
            ;;
        "duplicacy")
            deploy_service "Duplicacy" "$DUPLICACY_WEBHOOK"
            ;;
        "diun")
            deploy_service "DIUN" "$DIUN_WEBHOOK"
            ;;
        "homeassistant")
            deploy_service "Home Assistant" "$HOMEASSISTANT_WEBHOOK" "http://192.168.1.190:8123"
            ;;
        "netdata")
            deploy_service "Netdata" "$NETDATA_WEBHOOK" "https://netdata.cooked.beer"
            ;;
        "all")
            log "Deploying all services..."
            deploy_service "Jellyfin" "$JELLYFIN_WEBHOOK" "http://192.168.1.190:8096"
            deploy_service "Immich" "$IMMICH_WEBHOOK" "https://immich.cooked.beer"
            deploy_service "Vaultwarden" "$VAULTWARDEN_WEBHOOK" "https://vaultwarden.cooked.beer"
            deploy_service "Sonarr" "$SONARR_WEBHOOK" "https://sonarr.cooked.beer"
            deploy_service "SABnzbd" "$SABNZBD_WEBHOOK" "https://sabnzbd.cooked.beer"
            deploy_service "Prowlarr" "$PROWLARR_WEBHOOK" "https://prowlarr.cooked.beer"
            deploy_service "Jellyseerr" "$JELLYSEERR_WEBHOOK" "https://jellyseerr.cooked.beer"
            deploy_service "Radarr" "$RADARR_WEBHOOK" "https://radarr.cooked.beer"
            deploy_service "Cloudflared" "$CLOUDFLARED_WEBHOOK"
            deploy_service "Duplicacy" "$DUPLICACY_WEBHOOK"
            deploy_service "DIUN" "$DIUN_WEBHOOK"
            deploy_service "Home Assistant" "$HOMEASSISTANT_WEBHOOK" "http://192.168.1.190:8123"
            deploy_service "Netdata" "$NETDATA_WEBHOOK" "https://netdata.cooked.beer"
            ;;
        *)
            echo "Usage: $0 {jellyfin|immich|vaultwarden|sonarr|sabnzbd|prowlarr|jellyseerr|radarr|cloudflared|duplicacy|diun|homeassistant|netdata|all}"
            echo ""
            echo "Available services:"
            echo "  jellyfin      - Deploy Jellyfin media server"
            echo "  immich        - Deploy Immich photo management"
            echo "  vaultwarden   - Deploy Vaultwarden password manager"
            echo "  sonarr        - Deploy Sonarr TV management"
            echo "  sabnzbd       - Deploy SABnzbd download client"
            echo "  prowlarr      - Deploy Prowlarr indexer management"
            echo "  jellyseerr    - Deploy Jellyseerr media requests"
            echo "  radarr        - Deploy Radarr movie management"
            echo "  cloudflared   - Deploy Cloudflared tunnel"
            echo "  duplicacy     - Deploy Duplicacy backup"
            echo "  diun          - Deploy DIUN update monitor"
            echo "  homeassistant - Deploy Home Assistant"
            echo "  netdata       - Deploy Netdata monitoring"
            echo "  all           - Deploy all services"
            exit 1
            ;;
    esac
    
    log "=== Deployment Process Completed ==="
}

# Run main function with all arguments
main "$@"
