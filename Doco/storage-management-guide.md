# Storage Management Guide for Docker Swarm Cluster

## Overview

This guide provides comprehensive storage management solutions for your Docker Swarm cluster, specifically addressing the 90% storage usage issue on metal2.

## Immediate Actions Required

### 1. Run Initial Assessment and Cleanup

```bash
# Make scripts executable
chmod +x scripts/storage-management.sh
chmod +x scripts/docker-cleanup-cron.sh
chmod +x scripts/storage-monitor.sh
chmod +x scripts/setup-storage-management.sh

# Run immediate assessment
./scripts/storage-management.sh check

# Run immediate cleanup (if needed)
./scripts/storage-management.sh clean
```

### 2. Quick Docker Cleanup (Emergency)

```bash
# Remove unused Docker resources
docker system prune -a --volumes

# Clean up specific resources
docker container prune -f
docker image prune -a -f
docker volume prune -f
docker builder prune -a -f
```

## Automated Solutions

### 1. Setup Complete Storage Management

```bash
# Run the comprehensive setup script
./scripts/setup-storage-management.sh
```

This script will:
- Configure Docker daemon log rotation
- Set up automated cleanup cron jobs
- Deploy storage monitoring services
- Configure system log rotation
- Create monitoring dashboards

### 2. Deploy Storage Management Stack

```bash
# Deploy the storage management services
docker stack deploy -c compose/storage-management.yml storage-management
```

## Storage Management Components

### 1. Automated Cleanup Services

- **Daily Docker Cleanup**: Runs at 2 AM daily
- **Log Rotation**: Limits Docker logs to 10MB per container, 3 files max
- **System Log Cleanup**: Removes old log files weekly
- **PostgreSQL Maintenance**: Weekly VACUUM and REINDEX for Immich database

### 2. Storage Monitoring

- **Real-time Monitoring**: Checks disk usage every 15 minutes
- **Alert Thresholds**: 
  - Warning at 85% usage
  - Critical at 90% usage
- **Notification Methods**: Webhook alerts, email notifications
- **Detailed Reporting**: Comprehensive storage usage reports

### 3. Database Maintenance

- **PostgreSQL VACUUM**: Reclaims space from deleted records
- **Index Rebuilding**: Optimises database performance
- **WAL File Cleanup**: Removes old write-ahead log files

## Configuration

### Environment Variables

Create `.env.storage` file:

```bash
# Storage Management Configuration
STORAGE_ALERT_WEBHOOK_URL=https://your-webhook-url
STORAGE_ALERT_EMAIL=admin@yourdomain.com
DB_PASSWORD=your_immich_db_password
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
```

### Webhook Integration

For Microsoft Teams/Power Automate integration:

1. Create a webhook in your Teams channel or Power Automate flow
2. Add the webhook URL to `STORAGE_ALERT_WEBHOOK_URL`
3. Test with: `./scripts/storage-monitor.sh test-alert`

## Manual Commands

### Storage Assessment

```bash
# Comprehensive storage check
./scripts/storage-management.sh check

# Generate detailed report
./scripts/storage-monitor.sh report

# Check Docker usage specifically
docker system df -v
```

### Manual Cleanup

```bash
# Full cleanup (Docker + logs)
./scripts/storage-management.sh clean

# Docker cleanup only
./scripts/docker-cleanup-cron.sh docker

# Log cleanup only
./scripts/docker-cleanup-cron.sh logs

# Force cleanup regardless of thresholds
./scripts/docker-cleanup-cron.sh force
```

### Service Management

```bash
# Check storage management services
docker service ls | grep storage-management

# View service logs
docker service logs storage-management_storage-cleanup
docker service logs storage-management_storage-monitor

# Force run cleanup job
docker service update --force storage-management_storage-cleanup
```

## Monitoring and Alerts

### Log Files

- **Cleanup logs**: `/var/log/storage-management/cron.log`
- **Monitoring logs**: `/var/log/storage-management/monitor.log`
- **Service logs**: `docker service logs <service-name>`

### Cron Jobs

```bash
# View configured cron jobs
crontab -l

# Check cron job execution
tail -f /var/log/storage-management/cron.log
```

### Alert Testing

```bash
# Test webhook alerts
./scripts/storage-monitor.sh test-alert

# Check alert configuration
./scripts/storage-monitor.sh help
```

## Troubleshooting

### High Storage Usage Persists

1. **Identify largest consumers**:
   ```bash
   du -sh /var/lib/docker/*
   du -sh /srv/appdata/*
   find / -size +1G -type f 2>/dev/null
   ```

2. **Check specific applications**:
   ```bash
   # Immich database size
   du -sh /srv/appdata/immich/postgres
   
   # Check for large log files
   find /srv/appdata -name "*.log" -size +100M
   ```

3. **Emergency cleanup**:
   ```bash
   # Aggressive Docker cleanup
   docker system prune -a --volumes --force
   
   # Clean old journal logs
   journalctl --vacuum-time=1d
   ```

### Services Not Running

1. **Check swarm status**:
   ```bash
   docker node ls
   docker service ls
   ```

2. **Redeploy services**:
   ```bash
   docker stack rm storage-management
   docker stack deploy -c compose/storage-management.yml storage-management
   ```

3. **Check service constraints**:
   ```bash
   docker service inspect storage-management_postgres-maintenance
   ```

## Best Practices

### 1. Regular Monitoring

- Check storage usage weekly
- Review cleanup logs monthly
- Monitor application data growth trends

### 2. Preventive Measures

- Set up proper log rotation for all applications
- Use NFS storage for large, non-critical data
- Implement backup strategies with automatic cleanup

### 3. Capacity Planning

- Monitor growth trends
- Plan storage expansion before reaching 80% usage
- Consider moving large datasets to external storage

## Integration with Existing Monitoring

### Grafana Dashboard

Add storage metrics to your existing Grafana setup:

```bash
# Storage usage metrics
node_filesystem_avail_bytes
node_filesystem_size_bytes

# Docker metrics
docker_container_size_root_fs_bytes
docker_container_size_rw_bytes
```

### Netdata Integration

Your existing Netdata setup will show:
- Disk usage trends
- Docker container resource usage
- System performance impact of cleanup operations

## Emergency Procedures

### Critical Storage (>95%)

1. **Immediate actions**:
   ```bash
   # Emergency cleanup
   docker system prune -a --volumes --force
   journalctl --vacuum-time=1d
   find /tmp -type f -mtime +1 -delete
   ```

2. **Identify and remove large files**:
   ```bash
   # Find largest files
   find / -size +500M -type f 2>/dev/null | head -20
   
   # Check Docker container logs
   find /var/lib/docker/containers -name "*.log" -size +100M
   ```

3. **Temporary measures**:
   ```bash
   # Stop non-critical services temporarily
   docker service scale jellyfin_jellyfin=0
   docker service scale sonarr_sonarr=0
   ```

### Recovery Procedures

1. **After cleanup, restart services**:
   ```bash
   docker service scale jellyfin_jellyfin=1
   docker service scale sonarr_sonarr=1
   ```

2. **Verify system health**:
   ```bash
   ./scripts/storage-management.sh check
   docker service ls
   ```

## Maintenance Schedule

### Daily (Automated)
- Docker resource cleanup (2 AM)
- Storage usage monitoring (every 15 minutes)

### Weekly (Automated)
- PostgreSQL maintenance (Sunday 3 AM)
- System log rotation

### Monthly (Manual)
- Review storage trends
- Update cleanup thresholds if needed
- Check for application-specific cleanup opportunities

### Quarterly (Manual)
- Capacity planning review
- Update storage management scripts
- Test disaster recovery procedures
