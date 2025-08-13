# Power Automate Setup Guide

This guide will help you set up Microsoft Teams notifications using Power Automate for your Docker update monitor.

## 🎯 Why Power Automate?

Power Automate gives you more control over:
- **Custom message formatting** in Teams
- **Conditional logic** (e.g., only notify for critical services)
- **Integration** with other Microsoft 365 services
- **Advanced routing** (different channels for different services)
- **Rich adaptive cards** with interactive elements

## 📋 Your Workflow URL

You've provided this Power Automate workflow URL:
```
https://default345cd18b5bee4ac4b729a3f7059a28.f3.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/73ed7f9f4e484bca95f3f5842aa9938e/triggers/manual/paths/invoke/?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=6cPwoHdClYNnyVFS4ayQOo9BKnn7tb6JDJ2c67gF2M0
```

## 🔧 JSON Payload Structure

Your Power Automate workflow will receive this JSON structure for each update:

```json
{
  "title": "Docker Update Available",
  "service": "linuxserver/sonarr",
  "registry": "lscr.io",
  "currentVersion": "latest",
  "latestVersion": "4.0.0.748",
  "releaseDate": "2024-01-15 10:30:00",
  "dockerHubUrl": "https://hub.docker.com/r/linuxserver/sonarr",
  "fullImageName": "lscr.io/linuxserver/sonarr:4.0.0.748",
  "timestamp": "2024-01-21 09:00:00",
  "updateAvailable": true,
  "severity": "info"
}
```

## 🔧 Quick Setup

### 1. Configure Environment

```bash
cd update-monitor
cp .env.example .env
nano .env
```

Your `.env` should contain:
```bash
# Microsoft Teams Power Automate Workflow
WEBHOOK_URL=https://default345cd18b5bee4ac4b729a3f7059a28.f3.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/73ed7f9f4e484bca95f3f5842aa9938e/triggers/manual/paths/invoke/?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=6cPwoHdClYNnyVFS4ayQOo9BKnn7tb6JDJ2c67gF2M0

# Timezone
TZ=Australia/Adelaide
```

### 2. Add Monitoring Labels

```bash
chmod +x add-monitoring-labels.sh
./add-monitoring-labels.sh
```

### 3. Test the Workflow

```bash
chmod +x test-notifications.sh
./test-notifications.sh
```

### 4. Deploy Using Power Automate Compose

```bash
docker stack deploy -c compose-powerautomate.yml update-monitor
```

## 🎨 Power Automate Flow Suggestions

Here are some ideas for your Power Automate flow:

### Basic Teams Message
```
When HTTP request is received
↓
Post message in a chat or channel
- Team: Your Team
- Channel: Your Channel  
- Message: 
🔄 **Docker Update Available**
📦 Service: @{triggerBody()?['service']}
🏷️ Current: @{triggerBody()?['currentVersion']}
🆕 Latest: @{triggerBody()?['latestVersion']}
🕐 Released: @{triggerBody()?['releaseDate']}
```

### Advanced Adaptive Card
```json
{
  "type": "AdaptiveCard",
  "version": "1.3",
  "body": [
    {
      "type": "TextBlock",
      "text": "🔄 Docker Update Available",
      "weight": "Bolder",
      "size": "Medium"
    },
    {
      "type": "FactSet",
      "facts": [
        {
          "title": "📦 Service:",
          "value": "@{triggerBody()?['service']}"
        },
        {
          "title": "🏷️ Current:",
          "value": "@{triggerBody()?['currentVersion']}"
        },
        {
          "title": "🆕 Latest:",
          "value": "@{triggerBody()?['latestVersion']}"
        },
        {
          "title": "🕐 Released:",
          "value": "@{triggerBody()?['releaseDate']}"
        }
      ]
    }
  ],
  "actions": [
    {
      "type": "Action.OpenUrl",
      "title": "View on Docker Hub",
      "url": "@{triggerBody()?['dockerHubUrl']}"
    }
  ]
}
```

### Conditional Logic Examples

**Only notify for specific services:**
```
Condition: @{contains(triggerBody()?['service'], 'jellyfin')}
```

**Different channels for different services:**
```
Switch on: @{triggerBody()?['service']}
- Case 'jellyfin': Post to #media-updates
- Case 'sonarr': Post to #media-updates  
- Case 'homeassistant': Post to #home-automation
- Default: Post to #general-updates
```

**Priority-based notifications:**
```
Condition: @{or(contains(triggerBody()?['service'], 'security'), contains(triggerBody()?['service'], 'critical'))}
If true: Send urgent notification + email
If false: Send normal Teams message
```

## 🔧 Testing Your Workflow

### Manual Test from Power Automate
1. Go to your Power Automate flow
2. Click **"Test"** → **"Manually"**
3. Use this test payload:
```json
{
  "title": "Update Monitor Test",
  "service": "test-service",
  "registry": "docker.io",
  "currentVersion": "1.0.0",
  "latestVersion": "1.1.0",
  "releaseDate": "2024-01-21 10:30:00",
  "dockerHubUrl": "https://hub.docker.com/r/test/service",
  "fullImageName": "docker.io/test/service:1.1.0",
  "timestamp": "2024-01-21 10:30:00",
  "updateAvailable": true,
  "severity": "test"
}
```

### Test from Docker Monitor
```bash
./test-notifications.sh
```

## 🔧 Troubleshooting

### Workflow Not Triggering
1. **Check URL**: Ensure the complete URL is in `.env`
2. **Test manually**: Use Power Automate test feature
3. **Check logs**: `docker service logs update-monitor_diun`

### Invalid JSON Error
- Verify the JSON structure in your flow
- Check for special characters in service names
- Ensure proper escaping in the template

### Teams Message Not Appearing
- Check Teams channel permissions
- Verify the flow is enabled
- Look at Power Automate run history

## 🎯 Advanced Features

### Email Fallback
If Power Automate fails, configure email backup:
```bash
# Add to .env
EMAIL_FROM=updates@yourdomain.com
EMAIL_TO=admin@yourdomain.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

### Multiple Workflows
You can create different workflows for different service types:
```yaml
# In compose-powerautomate.yml, add conditions
DIUN_NOTIF_WEBHOOK_ENDPOINT: |
  {{if contains .Entry.Image.Path "media"}}
  ${MEDIA_WEBHOOK_URL}
  {{else}}
  ${GENERAL_WEBHOOK_URL}
  {{end}}
```

### Custom Scheduling
Change notification timing:
```yaml
DIUN_WATCH_SCHEDULE: "0 9 * * 0"  # Sunday 9 AM
# Or multiple times:
# "0 9,17 * * 1-5"  # Weekdays 9 AM and 5 PM
```

## 📊 Monitoring

### Check Service Status
```bash
docker service ls | grep update-monitor
docker service logs update-monitor_diun
```

### View Power Automate History
1. Go to Power Automate portal
2. Navigate to your flow
3. Check **"Run history"** for execution details

### Force Immediate Check
```bash
docker service update --force update-monitor_diun
```

## 🔒 Security Notes

- **Keep workflow URL private**: Don't share in public repositories
- **Monitor usage**: Power Automate has execution limits
- **Regenerate if needed**: Create new workflow if URL is compromised
- **Use managed identity**: Consider using managed identity for production

Your Power Automate workflow gives you much more flexibility than standard webhooks, allowing you to create rich, interactive notifications tailored to your specific needs!
