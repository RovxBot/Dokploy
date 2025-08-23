# Duplicacy Backup Setup for Docker Swarm

This guide will help you set up Duplicacy command-line backup solution on your Docker Swarm cluster with full configuration through Docker Compose.

## 📋 Prerequisites

1. Docker Swarm cluster with NFS shared storage mounted at `/srv/appdata`
2. Traefik reverse proxy configured
3. Backup storage location (local NFS mount or cloud storage)

## 🚀 Quick Setup

### 1. Create Required Directories

On your NFS server or all swarm nodes:

```bash
sudo mkdir -p \
  /srv/appdata/duplicacy/config \
  /srv/appdata/duplicacy/cache \
  /srv/appdata/duplicacy/logs \
  /srv/backups/duplicacy
```

### 2. Configure Environment Variables

Copy the environment template and configure your settings:

```bash
cp duplicacy-backup.env .env
nano .env
```

**Minimum required configuration:**
- Set `ADMIN_PASSWORD` to a secure password
- Choose your `STORAGE_TYPE` (local, s3, gcs, azure, b2, sftp)
- Configure storage credentials if using cloud storage

### 3. Deploy to Docker Swarm

```bash
docker stack deploy -c duplicacy-backup.yaml duplicacy
```

### 4. Access the Web Interface

Visit `http://duplicacy.cooked.beer` to access the Duplicacy web interface.

## 🔧 Storage Configuration Options

### Local Storage (Default)
Uses NFS mounted storage at `/srv/backups/duplicacy`:
```env
STORAGE_TYPE=local
```

### AWS S3
```env
STORAGE_TYPE=s3
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1
```

### Google Cloud Storage
```env
STORAGE_TYPE=gcs
# Place service account key at /srv/appdata/duplicacy/credentials/gcs-key.json
```

### Backblaze B2
```env
STORAGE_TYPE=b2
B2_ACCOUNT_ID=your-account-id
B2_ACCOUNT_KEY=your-account-key
```

### SFTP
```env
STORAGE_TYPE=sftp
SFTP_HOST=your-server.com
SFTP_USER=username
SFTP_PASSWORD=password
SFTP_PORT=22
```

## 📁 What Gets Backed Up

By default, the following directories are mounted for backup:

- `/srv/appdata` → All application data (Vaultwarden, Immich, etc.)
- `/srv/media` → Media files (read-only)

You can add additional directories by modifying the volumes section in the compose file.

## ⚙️ Initial Configuration

1. **Access Web UI**: Go to `http://duplicacy.cooked.beer`
2. **Set Admin Password**: Use the password from your `.env` file
3. **Add Storage**: Configure your chosen storage backend
4. **Create Repositories**: 
   - `appdata-backup` for `/data/appdata`
   - `media-backup` for `/data/media` (if needed)
5. **Set Schedules**: Configure backup schedules for each repository

## 🕐 Recommended Backup Schedules

### Critical Data (AppData)
- **Frequency**: Daily at 2 AM
- **Retention**: 
  - Daily: 30 days
  - Weekly: 12 weeks  
  - Monthly: 12 months

### Media Files
- **Frequency**: Weekly (Sunday 3 AM)
- **Retention**:
  - Weekly: 8 weeks
  - Monthly: 6 months

## 🔧 Advanced Usage

### Using Duplicacy CLI

Scale up the CLI container when needed:

```bash
# Start CLI container
docker service scale duplicacy_duplicacy-cli=1

# Get container ID
docker ps | grep duplicacy-cli

# Execute commands
docker exec -it <container-id> duplicacy

# Scale back down when done
docker service scale duplicacy_duplicacy-cli=0
```

### Common CLI Commands

```bash
# List all snapshots
duplicacy list

# Check repository integrity
duplicacy check

# Restore specific files
duplicacy restore -r 1 -hash

# Prune old snapshots
duplicacy prune -keep 30:360 -keep 7:30 -keep 1:7
```

## 📊 Monitoring and Maintenance

### Health Checks

Monitor backup status through:
1. Web UI dashboard
2. Log files at `/srv/appdata/duplicacy/logs`
3. Email notifications (if configured)

### Storage Usage

Monitor storage usage:
```bash
# Local storage
du -sh /srv/backups/duplicacy

# Check backup statistics in web UI
```

### Troubleshooting

**Common issues:**
1. **Permission errors**: Ensure PUID/PGID match your system
2. **Storage full**: Monitor and clean old snapshots
3. **Network timeouts**: Adjust chunk size for slow connections

## 🔐 Security Considerations

1. **Encryption**: Duplicacy encrypts all data by default
2. **Access Control**: Secure the web interface with strong passwords
3. **Network Security**: Use HTTPS in production (configure Traefik TLS)
4. **Credential Storage**: Store cloud credentials securely

## 🔄 Backup Strategy

### 3-2-1 Rule Implementation

1. **3 Copies**: Original + Local backup + Cloud backup
2. **2 Different Media**: Local NFS + Cloud storage
3. **1 Offsite**: Cloud storage provider

### Example Multi-Storage Setup

Configure multiple storage backends:
1. Primary: Local NFS for fast recovery
2. Secondary: Cloud storage for offsite protection

## 📈 Performance Tuning

### For Large Datasets
```env
BACKUP_THREADS=8
CHUNK_SIZE=8192
COMPRESSION_LEVEL=1
```

### For Slow Networks
```env
BACKUP_THREADS=2
CHUNK_SIZE=1024
COMPRESSION_LEVEL=6
```

## 🆘 Recovery Procedures

### Full System Recovery
1. Restore Duplicacy configuration
2. Restore application data to `/srv/appdata`
3. Redeploy Docker services
4. Verify application functionality

### Selective Recovery
Use the web UI or CLI to restore specific files or directories as needed.

---

## 📞 Support

For issues:
1. Check logs in `/srv/appdata/duplicacy/logs`
2. Review Duplicacy documentation
3. Check Docker service status: `docker service ls`
