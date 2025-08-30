# Docker Update Monitor

Automated weekly monitoring and notification system for Docker container updates in your Dokploy environment.

## Features

- 🔄 **Weekly Update Checks**: Runs every Sunday at 9 AM
- 📧 **Multiple Notification Channels**: Discord, Slack, Teams, Email
- 📊 **Detailed Reports**: Shows current vs available versions
- 🎯 **Selective Monitoring**: Only monitors labeled services
- 🔒 **Non-Destructive**: Only reports updates, doesn't auto-update
- ⚡ **Lightweight**: Minimal resource usage

## Quick Setup

### 1. Configure Notifications

Copy the environment template and configure your notification settings:

```bash
cd update-monitor
cp .env.example .env
nano .env
```

Configure at least one notification method:

**Discord Webhook:**
1. Go to your Discord server → Server Settings → Integrations → Webhooks
2. Create a new webhook and copy the URL
3. Set `WEBHOOK_URL` in your `.env` file

**Email Notifications:**
- Configure SMTP settings in `.env`
- For Gmail, use an App Password instead of your regular password

### 2. Add Monitoring Labels

Run the script to add monitoring labels to your existing services:

```bash
chmod +x add-monitoring-labels.sh
./add-monitoring-labels.sh
```

This adds `diun.enable=true` labels to all your services.

### 3. Deploy the Monitor

```bash
docker stack deploy -c compose.yml update-monitor
```

## How It Works

The system uses **DIUN** (Docker Image Update Notifier) which:

1. **Monitors** your Docker services for image updates
2. **Checks** registries weekly for newer versions
3. **Compares** current vs latest available versions
4. **Sends notifications** when updates are available

## Monitored Services

The system will monitor these services for updates:

- 📺 **Jellyfin** - Media server
- 🎬 **Sonarr** - TV show management
- 🎭 **Radarr** - Movie management  
- 🔍 **Prowlarr** - Indexer management
- 📥 **SABnzbd** - Download client
- 🎫 **Jellyseerr** - Media requests
- 🏠 **Home Assistant** - Home automation
- 🔧 **Node-RED** - Automation flows
- 📸 **Immich** - Photo management
- 🔐 **Vaultwarden** - Password manager
- ☁️ **Cloudflared** - Tunnel service

## Notification Examples

**Discord/Slack Message:**
```
🔄 **Update Available**
📦 **lscr.io/linuxserver/sonarr**
🏷️ Current: latest
🆕 Latest: 4.0.0.748
🕐 2024-01-15 10:30:00
```

**Email Subject:** `Docker Update Available: sonarr`

## Configuration Options

### Schedule Customization

To change the schedule, edit the `DIUN_WATCH_SCHEDULE` environment variable:

```yaml
DIUN_WATCH_SCHEDULE: "0 9 * * 0"  # Sunday 9 AM
# Format: minute hour day month weekday
# Examples:
# "0 6 * * 1"   # Monday 6 AM  
# "0 18 * * 5"  # Friday 6 PM
# "0 12 1 * *"  # 1st of month at noon
```

### Adding New Services

To monitor new services, add the label when deploying:

```yaml
deploy:
  labels:
    - "diun.enable=true"
    - "update-monitor=true"
```

Or add to existing services:

```bash
docker service update --label-add "diun.enable=true" SERVICE_NAME
```

### Excluding Services

To stop monitoring a service:

```bash
docker service update --label-rm "diun.enable" SERVICE_NAME
```

## Troubleshooting

### Check Monitor Status

```bash
# View monitor logs
docker service logs update-monitor_diun

# Check if services are being monitored
docker service ls --filter label=diun.enable=true
```

### Test Notifications

```bash
# Restart DIUN to trigger immediate check
docker service update --force update-monitor_diun
```

### Common Issues

1. **No notifications received:**
   - Check webhook URL is correct
   - Verify SMTP settings for email
   - Check service logs for errors

2. **Services not monitored:**
   - Ensure labels are added: `docker service inspect SERVICE_NAME`
   - Check DIUN logs for discovery issues

3. **False positives:**
   - Some images use `latest` tag which may show updates frequently
   - Consider pinning to specific versions for stable services

## Advanced Configuration

### Custom Notification Templates

Edit the `DIUN_NOTIF_WEBHOOK_TEMPLATEBODY` in `compose.yml` to customize notification format.

### Registry Authentication

For private registries, add authentication:

```yaml
environment:
  DIUN_PROVIDERS_SWARM_WATCHBYDEFAULT: "false"
  DIUN_REGOPTS_MYREGISTRY_USERNAME: "user"
  DIUN_REGOPTS_MYREGISTRY_PASSWORD: "pass"
```

## Security Notes

- Monitor runs with read-only Docker socket access
- No automatic updates are performed
- Webhook URLs should be kept secure
- Use app passwords for email authentication

## Resource Usage

- **CPU**: ~0.1 cores during checks, minimal at rest
- **Memory**: ~128MB
- **Network**: Minimal, only during registry checks
- **Storage**: <100MB for logs and cache
