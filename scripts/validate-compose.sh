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
    
    # Validate YAML syntax
    if ! docker-compose -f "$file" config > /dev/null 2>&1; then
        log "Error: $filename has invalid YAML syntax"
        docker-compose -f "$file" config 2>&1 | tee -a "$LOGS_DIR/validation.log"
        return 1
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
    
    # Check for proper network configuration
    if ! grep -q "dokploy-network" "$file"; then
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
    
    local total_files=0
    local failed_files=0
    
    # Find all compose files
    for file in "$COMPOSE_DIR"/*.yaml "$COMPOSE_DIR"/*.yml; do
        if [ -f "$file" ]; then
            ((total_files++))
            if ! validate_compose_file "$file"; then
                ((failed_files++))
            fi
        fi
    done
    
    # Check subdirectories
    for dir in "$COMPOSE_DIR"/*/; do
        if [ -d "$dir" ]; then
            for file in "$dir"*.yaml "$dir"*.yml; do
                if [ -f "$file" ]; then
                    ((total_files++))
                    if ! validate_compose_file "$file"; then
                        ((failed_files++))
                    fi
                fi
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
    validate_compose_file "$1"
else
    main
fi
