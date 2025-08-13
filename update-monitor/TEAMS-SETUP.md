# Microsoft Teams Setup Guide

This guide will help you set up Microsoft Teams notifications for your Docker update monitor.

## 📋 Prerequisites

- Microsoft Teams access
- Admin permissions for the Teams channel where you want notifications
- Access to your Docker Swarm manager node

## 🔧 Step 1: Create Teams Incoming Webhook

### Option A: Using Teams Desktop/Web App

1. **Open Microsoft Teams** and navigate to the channel where you want notifications
2. **Click the three dots (...)** next to the channel name
3. **Select "Connectors"** from the dropdown menu
4. **Search for "Incoming Webhook"** and click **"Add"**
5. **Click "Add"** again to configure the webhook
6. **Configure the webhook:**
   - **Name**: `Docker Update Monitor`
   - **Upload Image**: (Optional) Upload a Docker logo
   - **Description**: `Automated notifications for Docker container updates`
7. **Click "Create"**
8. **Copy the webhook URL** - it will look like:
   ```
   https://outlook.office.com/webhook/12345678-1234-1234-1234-123456789012@12345678-1234-1234-1234-123456789012/IncomingWebhook/abcdef1234567890/12345678-1234-1234-1234-123456789012
   ```
9. **Click "Done"**

### Option B: Using Teams Admin Center (for admins)

1. Go to **Teams Admin Center** → **Teams apps** → **Manage apps**
2. Search for **"Incoming Webhook"** and ensure it's allowed
3. Follow Option A steps in your Teams client

## 🔧 Step 2: Configure Update Monitor

1. **Navigate to the update-monitor directory:**
   ```bash
   cd update-monitor
   ```

2. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

3. **Edit the .env file:**
   ```bash
   nano .env
   ```

4. **Add your Teams webhook URL:**
   ```bash
   # Microsoft Teams Webhook Notifications
   WEBHOOK_URL=https://outlook.office.com/webhook/YOUR_ACTUAL_WEBHOOK_URL_HERE
   
   # Timezone
   TZ=Australia/Adelaide
   ```

5. **Save and exit** (Ctrl+X, then Y, then Enter)

## 🔧 Step 3: Add Monitoring Labels

Run the script to add monitoring labels to your existing services:

```bash
chmod +x add-monitoring-labels.sh
./add-monitoring-labels.sh
```

## 🔧 Step 4: Test the Configuration

Test your Teams webhook before deploying:

```bash
chmod +x test-notifications.sh
./test-notifications.sh
```

You should see a test message in your Teams channel that looks like:

```
🧪 Update Monitor Test
Configuration Test Message

📦 Status: Configuration Test
✅ Result: If you see this, your webhook is working!
🕐 Test Time: [current date/time]
```

## 🔧 Step 5: Deploy the Monitor

If the test was successful, deploy the update monitor:

```bash
docker stack deploy -c compose.yml update-monitor
```

## 📱 What Your Teams Notifications Will Look Like

When updates are available, you'll receive rich Teams notifications with:

- **🔄 Docker Update Available** (title)
- **Service name** (subtitle)
- **Docker logo** (activity image)
- **Structured information:**
  - 📦 Service name
  - 🏷️ Current version
  - 🆕 Latest version  
  - 🕐 Release date
- **Action button** to view on Docker Hub

## 🔧 Customization Options

### Change Notification Color

Edit `compose.yml` and modify the `themeColor` value:

```yaml
"themeColor": "0076D7"  # Blue (default)
# "themeColor": "FF6B35"  # Orange
# "themeColor": "28A745"  # Green  
# "themeColor": "DC3545"  # Red
```

### Modify Schedule

Change when notifications are sent by editing the schedule:

```yaml
DIUN_WATCH_SCHEDULE: "0 9 * * 0"  # Sunday 9 AM
# Examples:
# "0 8 * * 1"   # Monday 8 AM
# "0 17 * * 5"  # Friday 5 PM  
# "0 12 1 * *"  # 1st of month at noon
```

### Add More Information

You can add more facts to the Teams message by editing the `DIUN_NOTIF_WEBHOOK_TEMPLATEBODY` section in `compose.yml`.

## 🔧 Troubleshooting

### Test Failed - HTTP 400

- **Check webhook URL**: Ensure you copied the complete URL
- **Verify permissions**: Make sure the webhook is still active in Teams
- **Check JSON format**: Ensure no syntax errors in the payload

### Test Failed - HTTP 404

- **Webhook deleted**: The webhook may have been removed from Teams
- **Wrong URL**: Double-check the webhook URL is correct

### No Notifications Received

1. **Check service logs:**
   ```bash
   docker service logs update-monitor_diun
   ```

2. **Verify services are labeled:**
   ```bash
   docker service ls --filter label=diun.enable=true
   ```

3. **Force immediate check:**
   ```bash
   docker service update --force update-monitor_diun
   ```

### Teams Webhook Stopped Working

- **Regenerate webhook**: Delete and recreate the webhook in Teams
- **Update .env file**: Add the new webhook URL
- **Redeploy stack**: `docker stack deploy -c compose.yml update-monitor`

## 🔒 Security Notes

- **Keep webhook URL private**: Don't share it publicly
- **Regenerate if compromised**: Delete and recreate the webhook if exposed
- **Monitor usage**: Teams webhooks have rate limits (avoid excessive notifications)

## 📊 Monitoring Schedule

The update monitor runs:
- **Every Sunday at 9:00 AM** (Australia/Adelaide timezone)
- **Checks all labeled services** for available updates
- **Sends individual notifications** for each service with updates
- **No notifications** if all services are up to date

## 🎯 Next Steps

1. **Monitor the first run**: Wait for Sunday 9 AM or force a check
2. **Adjust schedule**: Modify timing if needed
3. **Add new services**: Label future deployments with `diun.enable=true`
4. **Set up email backup**: Configure email notifications as a backup method
