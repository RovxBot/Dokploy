# Fix Jellyfin inotify Watch Limit Issue

## Problem
Jellyfin is hitting the system's inotify watch limit (currently 60284), causing directory monitoring to fail for large media libraries.

## Solution: Increase inotify Limits

### 1. Temporary Fix (Immediate)
Run on each Docker Swarm host where Jellyfin might run:

```bash
# Check current limits
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances

# Increase limits temporarily (until reboot)
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512
```

### 2. Permanent Fix
Create/edit `/etc/sysctl.conf` or create `/etc/sysctl.d/99-jellyfin.conf`:

```bash
# Create permanent configuration
sudo tee /etc/sysctl.d/99-jellyfin.conf << EOF
# Increase inotify limits for Jellyfin media monitoring
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
EOF

# Apply the changes
sudo sysctl -p /etc/sysctl.d/99-jellyfin.conf
```

### 3. Verify the Fix
```bash
# Check new limits
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances

# Restart Jellyfin container to pick up new limits
docker service update --force jellyfin_jellyfin
```

## Alternative Solutions

### Option 1: Reduce Monitoring Scope
In Jellyfin settings, you can:
- Disable real-time monitoring for some libraries
- Use scheduled library scans instead of real-time monitoring
- Exclude certain subdirectories from monitoring

### Option 2: Optimize Library Structure
- Reduce deep nested folder structures
- Consolidate smaller collections
- Use symbolic links to reduce duplicate monitoring

## Recommended Values
- **max_user_watches**: 524288 (8x increase from your current 60284)
- **max_user_instances**: 512 (sufficient for multiple applications)

These values should handle very large media libraries while not consuming excessive system resources.
