# Dokploy Infrastructure

Docker Swarm infrastructure managed through Dokploy with Infrastructure as Code principles.

## Repository Structure

```
├── compose/                 # New service compositions
│   └── netdata.yml         # Netdata monitoring
├── config/                 # Configuration templates
│   ├── webhooks.env.template
│   └── duplicacy.env.template
├── scripts/                # Automation scripts
│   ├── deploy.sh          # Deployment automation
│   ├── validate-compose.sh # Compose file validation
│   └── backup-before-deploy.sh # Pre-deployment backups
├── Doco/                   # Documentation
├── update-monitor/         # Update monitoring system
├── Duplicacy/             # Backup configurations
├── HomeAssistant/         # Home Assistant configs
├── Traefik/              # Reverse proxy configs
└── *.yaml                # Service compose files
```

## Quick Start

### 1. Configure Webhooks
```bash
cp config/webhooks.env.template config/webhooks.env
# Edit config/webhooks.env with your Dokploy webhook URLs
```

### 2. Configure Backups (Optional)
```bash
cp config/duplicacy.env.template config/duplicacy.env
# Edit config/duplicacy.env with your Backblaze B2 credentials
```

### 3. Deploy Services
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Deploy single service
./scripts/deploy.sh jellyfin

# Deploy all services
./scripts/deploy.sh all

# Validate compose files
./scripts/validate-compose.sh
```

## Services

### Media Stack
- **Jellyfin** - Media server (port 8096)
- **Immich** - Photo management
- **Jellyseerr** - Media requests

### Media Management
- **Sonarr** - TV show management
- **Radarr** - Movie management
- **Prowlarr** - Indexer management
- **SABnzbd** - Download client

### Infrastructure
- **Vaultwarden** - Password manager
- **Home Assistant** - Home automation
- **Traefik** - Reverse proxy
- **Cloudflared** - Tunnel service

### Monitoring & Backup
- **DIUN** - Update notifications
- **Duplicacy** - Backup system
- **Netdata** - System monitoring

## Automation Features

- **GitHub Actions CI/CD** - Automated deployments on push
- **Compose Validation** - Syntax and configuration checking
- **Health Checks** - Post-deployment service verification
- **Pre-deployment Backups** - Automatic snapshots before updates
- **Update Monitoring** - Weekly update notifications

## Manual Tasks Required

1. **Set up GitHub Secrets** for webhook URLs
2. **Configure Netdata Cloud** (optional) for centralized monitoring
3. **Set up Backblaze B2** credentials for backup functionality
4. **Configure notification webhooks** in Dokploy

## Development Workflow

1. Make changes to compose files
2. Validate locally: `./scripts/validate-compose.sh`
3. Commit and push to trigger automated deployment
4. Monitor deployment logs in GitHub Actions
