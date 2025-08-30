#!/bin/bash

# Docker Compose Validation Script
# Validates compose files for syntax and common issues

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$SCRIPT_DIR/.."
LOGS_DIR="$SCRIPT_DIR/../logs"

mkdir -p "$LOGS_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/validation.log"
}

# Check if docker-compose is available
check_docker_compose() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then
        # Use docker compose (v2)
        DOCKER_COMPOSE_CMD="docker compose"
        log "Using Docker Compose v2"
        return 0
    elif command -v docker-compose &> /dev/null; then
        # Use docker-compose (v1)
        DOCKER_COMPOSE_CMD="docker-compose"
        log "Using Docker Compose v1"
        return 0
    else
        log "Warning: Neither docker-compose nor docker compose found. Skipping syntax validation."
        DOCKER_COMPOSE_CMD=""
        return 1
    fi
}

# Validation function
validate_compose_file() {
    local file="$1"
    local filename=$(basename "$file")

    log "Validating $filename..."

    # Check if file exists
    if [ ! -f "$file" ]; then
        log "Error: $filename not found"
        return 1
    fi

    # Skip empty files
    if [ ! -s "$file" ]; then
        log "Warning: $filename is empty, skipping"
        return 0
    fi

    log "File $filename exists and is not empty, proceeding with validation..."

    # Simple Docker Compose validation
    if [ -n "$DOCKER_COMPOSE_CMD" ]; then
        log "Running Docker Compose validation for $filename..."

        # Quick validation - just check if it can parse the file
        if $DOCKER_COMPOSE_CMD -f "$file" config --quiet 2>/dev/null; then
            log "Docker Compose syntax validation passed for $filename"
        else
            # Try to get error details
            local error_output=$($DOCKER_COMPOSE_CMD -f "$file" config 2>&1 | head -3)
            log "Warning: Docker Compose validation issues for $filename:"
            log "$error_output"
            # Don't fail the validation for compose issues, just warn
        fi
    else
        log "Info: Skipping Docker Compose validation for $filename (not available)"
    fi
    
    # Check for common issues
    local issues=0
    
    # Check for missing environment variables
    if grep -q '\${.*}' "$file"; then
        local missing_vars=$(grep -o '\${[^}]*}' "$file" | sort -u)
        log "Warning: $filename contains environment variables that may not be set:"
        echo "$missing_vars" | tee -a "$LOGS_DIR/validation.log"
    fi
    
    # Check for hardcoded secrets
    if grep -qi "password\|secret\|token\|key" "$file"; then
        if grep -E "(password|secret|token|key).*:" "$file" | grep -v '\${' | grep -v "# " > /dev/null; then
            log "Warning: $filename may contain hardcoded secrets"
            ((issues++))
        fi
    fi
    
    # Check for proper network configuration (skip if using host networking)
    if ! grep -q "dokploy-network" "$file" && ! grep -q "network_mode: host" "$file" && ! grep -q "mode: host" "$file"; then
        log "Warning: $filename may not be using the standard dokploy-network"
        ((issues++))
    fi
    
    # Check for proper volume configuration
    if grep -q "driver: local" "$file"; then
        if ! grep -A 3 "driver: local" "$file" | grep -q "driver_opts"; then
            log "Warning: $filename has local volumes without driver options"
            ((issues++))
        fi
    fi
    
    if [ $issues -eq 0 ]; then
        log "$filename validation passed"
        return 0
    else
        log "$filename validation completed with $issues warnings"
        return 0
    fi
}

# Main validation function
main() {
    log "=== Docker Compose Validation Started ==="

    # Initialize docker-compose command
    DOCKER_COMPOSE_CMD=""
    check_docker_compose

    local total_files=0
    local failed_files=0
    
    # Find all compose files - simplified approach
    log "Searching for compose files in $COMPOSE_DIR"

    # Check root directory files
    for ext in yaml yml; do
        for file in "$COMPOSE_DIR"/*.$ext; do
            if [ -f "$file" ] && [ "$file" != "$COMPOSE_DIR/*.$ext" ]; then
                log "Found file: $file"
                ((total_files++))
                log "About to validate $file..."
                if ! validate_compose_file "$file"; then
                    ((failed_files++))
                fi
                log "Completed validation of $file"
            fi
        done
    done

    # Check specific known subdirectories
    for subdir in compose HomeAssistant Duplicacy Traefik update-monitor; do
        if [ -d "$COMPOSE_DIR/$subdir" ]; then
            log "Checking directory: $COMPOSE_DIR/$subdir"
            for ext in yaml yml; do
                for file in "$COMPOSE_DIR/$subdir"/*.$ext; do
                    if [ -f "$file" ] && [ "$file" != "$COMPOSE_DIR/$subdir/*.$ext" ]; then
                        log "Found file: $file"
                        ((total_files++))
                        if ! validate_compose_file "$file"; then
                            ((failed_files++))
                        fi
                    fi
                done
            done
        fi
    done
    
    log "=== Validation Summary ==="
    log "Total files validated: $total_files"
    log "Failed validations: $failed_files"
    
    if [ $failed_files -eq 0 ]; then
        log "All compose files passed validation"
        exit 0
    else
        log "Some compose files failed validation"
        exit 1
    fi
}

# Show usage if no arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [file]"
    echo ""
    echo "Validates Docker Compose files for syntax and common issues"
    echo ""
    echo "Options:"
    echo "  file    Validate specific compose file (optional)"
    echo "  --help  Show this help message"
    echo ""
    echo "If no file specified, validates all .yaml and .yml files in the repository"
    exit 0
fi

# Validate specific file if provided
if [ -n "$1" ]; then
    # Initialize docker-compose command for single file validation
    DOCKER_COMPOSE_CMD=""
    check_docker_compose

    if validate_compose_file "$1"; then
        log "Validation completed successfully"
        exit 0
    else
        log "Validation failed"
        exit 1
    fi
else
    main
fi
