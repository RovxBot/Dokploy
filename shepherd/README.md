# Shepherd Auto-Updater for Docker Swarm

Shepherd automatically monitors and updates your Docker Swarm services when new image versions are available.

## 🚀 Quick Deployment

```bash
cd shepherd
chmod +x deploy.sh
./deploy.sh
```

## 📋 What Shepherd Does

- **Monitors all your Docker services** for new image versions
- **Automatically updates services** when newer images are available
- **Runs as a scheduled cron job** (daily at 2:00 AM)
- **Preserves service configuration** during updates
- **Logs all update activities** for monitoring

## ⚙️ Configuration

### Current Settings

- **Schedule**: Daily at 2:00 AM (`0 0 2 * * *`)
- **Timezone**: Australia/Adelaide
- **Excluded Services**: `shepherd_scheduler`, `shepherd_app` (prevents self-updates)
- **Registry Auth**: Enabled for private registries
- **Sleep Time**: 5 minutes between service checks

### Environment Variables

You can customize Shepherd by modifying the environment variables in `compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Australia/Adelaide` | Timezone for scheduling |
| `FILTER_SERVICES` | `''` | Only update services matching this label |
| `IGNORELIST_SERVICES` | `shepherd_scheduler,shepherd_app` | Services to never update |
| `BLACKLIST_SERVICES` | `shepherd_scheduler,shepherd_app` | Alternative to IGNORELIST |
| `SLEEP_TIME` | `5m` | Time to wait between service updates |
| `WITH_REGISTRY_AUTH` | `true` | Use registry authentication |
| `RUN_ONCE_AND_EXIT` | `true` | Exit after one update cycle (for cron mode) |

### Scheduling

To change the update schedule, modify the cron expression in the deploy labels:

```yaml
- swarm.cronjob.schedule=0 0 2 * * *  # Daily at 2 AM
```

Common schedules:
- `0 0 2 * * *` - Daily at 2 AM
- `0 0 2 * * 0` - Weekly on Sunday at 2 AM  
- `0 0 2 1 * *` - Monthly on the 1st at 2 AM

## 🔍 Monitoring

### Check Shepherd Status
```bash
docker stack services shepherd
```

### View Logs
```bash
# Scheduler logs
docker service logs -f shepherd_scheduler

# Update logs  
docker service logs -f shepherd_app
```

### Manual Update Trigger
```bash
# Force Shepherd to run immediately
docker service update --force shepherd_app
```

## 🛡️ Security Considerations

1. **Docker Socket Access**: Shepherd requires access to the Docker socket to manage services
2. **Manager Node Only**: Runs only on manager nodes for security
3. **Self-Protection**: Excludes itself from updates to prevent disruption
4. **Registry Auth**: Supports private registry authentication

## 🔧 Troubleshooting

### Shepherd Not Running
```bash
# Check if the stack is deployed
docker stack ls

# Check service status
docker stack services shepherd

# Check for errors
docker service logs shepherd_scheduler
```

### Services Not Updating
1. **Check service labels**: Ensure services don't have update exclusion labels
2. **Verify image tags**: Shepherd only updates services using specific tags (not `latest`)
3. **Registry access**: Ensure Shepherd can access your image registries
4. **Check logs**: Look for error messages in Shepherd logs

### Common Issues

**Issue**: Shepherd updates itself and stops working
**Solution**: The configuration excludes Shepherd services from updates

**Issue**: Updates happen too frequently
**Solution**: Adjust the `SLEEP_TIME` environment variable

**Issue**: Some services aren't being updated
**Solution**: Check if they're in the `IGNORELIST_SERVICES` or have exclusion labels

## 📊 Monitoring Your Services

To see which services Shepherd will monitor:

```bash
# List all services with their images
docker service ls --format 'table {{.Name}}\t{{.Image}}\t{{.Replicas}}'

# Check specific service details
docker service inspect <service-name>
```

## 🔄 Updating Shepherd Configuration

1. Edit `compose.yml` with your changes
2. Redeploy: `./deploy.sh`
3. Verify: `docker stack services shepherd`

## 📝 Notes

- Shepherd respects Docker Swarm's rolling update settings
- Updates preserve all service configurations and constraints
- Failed updates will be logged but won't affect other services
- Shepherd works with both public and private Docker registries
