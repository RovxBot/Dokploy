# Dokploy Infrastructure

Docker Swarm infrastructure managed through Dokploy with Infrastructure as Code principles.

## Repository Structure

```
├── compose/                 # New service compositions
│   └── netdata.yml         # Netdata monitoring
├── scripts/                # Automation scripts
│   └── validate-compose.sh # Compose file validation
├── Doco/                   # Documentation
├── update-monitor/         # Update monitoring system
├── Duplicacy/             # Backup configurations
├── HomeAssistant/         # Home Assistant configs
├── Traefik/              # Reverse proxy configs
└── *.yaml                # Service compose files
```

## Quick Start

### 1. Set up GitHub Secrets
Configure webhook URLs in your GitHub repository secrets:
- `JELLYFIN_WEBHOOK`, `IMMICH_WEBHOOK`, `VAULTWARDEN_WEBHOOK`, etc.
- `NETDATA_WEBHOOK` for monitoring deployment

### 2. Automated Deployments
- **Push to main branch** - Automatically deploys only changed services
- **Manual deployment** - Use GitHub Actions workflow dispatch to deploy specific services
- **Validation** - All compose files are validated before deployment

### 3. Validate Compose Files Locally
```bash
chmod +x scripts/validate-compose.sh
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

- **GitHub Actions CI/CD** - Automated deployments on push to main
- **Selective Deployment** - Only deploys services with changed files
- **Compose Validation** - Syntax and configuration checking before deployment
- **Manual Deployment** - Workflow dispatch for specific services
- **Update Monitoring** - Weekly update notifications via DIUN

## Development Workflow

1. Make changes to compose files
2. Validate locally (optional): `./scripts/validate-compose.sh`
3. Commit and push to main branch
4. GitHub Actions automatically deploys only changed services
5. Monitor deployment in GitHub Actions and Dokploy dashboard

## Manual Deployment

Use GitHub Actions workflow dispatch to deploy specific services:
1. Go to Actions tab in GitHub
2. Select "Deploy to Dokploy" workflow
3. Click "Run workflow"
4. Choose the service to deploy
