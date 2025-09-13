# Dokploy Infrastructure Lab

A comprehensive Docker Swarm infrastructure managed through Dokploy with Infrastructure as Code principles. This lab features automated deployments, comprehensive monitoring, storage management, and a full media stack.

## Infrastructure Overview

**7-Node Docker Swarm Cluster:**
- **metal0** - Manager node, Jellyfin host
- **metal1** - Worker node
- **metal2** - Worker node, Immich database host
- **metal3** - Manager node
- **metal4** - Worker node
- **metal5** - Manager node
- **metal6** - Worker node

## Repository Structure

```
├── compose/                    # Service compositions
│   ├── netdata.yml            # System monitoring (global)
│   └── storage-management.yml # Storage cleanup services
├── scripts/                   # Automation & management
│   ├── validate-compose.sh    # Compose validation
│   ├── storage-management.sh  # Storage analysis & cleanup
│   ├── docker-cleanup-cron.sh # Automated cleanup
│   ├── storage-monitor.sh     # Storage monitoring
│   └── setup-silent-cleanup.sh # Silent storage setup
├── Doco/                      # Documentation
│   ├── storage-management-guide.md
│   ├── docker-swarm-nfs-guide.md
│   └── jellyfin-smb-mount-guide.md
├── update-monitor/            # Update monitoring system
│   ├── compose.yml           # DIUN update notifications
│   └── scripts/              # Service labeling automation
├── Duplicacy/                 # Backup system
├── HomeAssistant/            # Home automation
├── Traefik/                  # Reverse proxy configs
└── *.yaml                    # Application compose files
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

## Services & Applications

### Media Stack
- **Jellyfin** - Media server with hardware transcoding (port 8096)
  - 8GB tmpfs for transcoding scratch space
  - Dual NAS media sources (Synology + Rockstor)
  - Pinned to metal0 for optimal performance
- **Immich** - AI-powered photo management with facial recognition
  - PostgreSQL database pinned to metal2
  - NFS storage for photos and model cache
  - Machine learning container for AI features
- **Jellyseerr** - Beautiful media request management

### Media Automation (*arr Stack)
- **Sonarr** - TV show collection management
- **Radarr** - Movie collection management
- **Prowlarr** - Unified indexer management
- **SABnzbd** - High-speed Usenet downloader (port 8080)
  - Integrated with *arr stack for automated downloads

### Infrastructure & Security
- **Vaultwarden** - Self-hosted Bitwarden password manager
- **Home Assistant** - Comprehensive home automation platform
- **Traefik** - Dynamic reverse proxy with automatic service discovery
- **Cloudflared** - Secure tunnel service for external access

### Monitoring, Backup & Management
- **Netdata** - Real-time system monitoring (global deployment)
  - Per-node dashboards with cluster overview
  - Resource usage, Docker metrics, network monitoring
- **DIUN** - Docker image update notifications
  - Weekly update reports via webhook
  - Automatic service discovery with labels
- **Duplicacy** - Encrypted cloud backup system
  - Automated Immich photo backups to Backblaze B2
  - Scheduled pruning and retention policies
- **Storage Management** - Automated cleanup and monitoring
  - Daily Docker resource cleanup
  - PostgreSQL maintenance and optimization
  - Proactive storage alerts via Netdata

## Automation & DevOps Features

### CI/CD Pipeline
- **GitHub Actions** - Fully automated deployments on push to main
- **Selective Deployment** - Intelligent detection of changed services
- **Compose Validation** - Pre-deployment syntax and configuration checking
- **Manual Deployment** - Workflow dispatch for specific service deployments
- **Rollback Capability** - Easy service rollback through GitHub Actions

### Monitoring & Alerting
- **Update Monitoring** - Weekly Docker image update notifications via DIUN
- **Storage Management** - Automated cleanup with proactive monitoring
  - Daily cleanup at 2 AM (only when disk usage > 80%)
  - Weekly PostgreSQL maintenance (VACUUM, REINDEX)
  - Real-time storage alerts via Netdata
- **Service Health Monitoring** - Health checks and restart policies
- **Resource Monitoring** - CPU, RAM, disk, and network monitoring per node

### Automated Maintenance
- **Docker Log Rotation** - 10MB max per container, 3 files retention
- **System Log Management** - Systemd journal limits and rotation
- **Database Maintenance** - Automated PostgreSQL optimization
- **Backup Automation** - Scheduled encrypted backups with retention policies
- **Container Cleanup** - Removal of unused images, volumes, and build cache

## Development Workflow

1. Make changes to compose files
2. Validate locally (optional): `./scripts/validate-compose.sh`
3. Commit and push to main branch
4. GitHub Actions automatically deploys only changed services
5. Monitor deployment in GitHub Actions and Dokploy dashboard

## Advanced Infrastructure Features

### Storage Architecture
- **NFS Integration** - Centralized storage with multiple NAS sources
  - Synology NAS (192.168.1.154) - Media storage
  - Rockstor NFS (192.168.1.184) - Application data and configs
- **Local Storage Optimization** - Strategic placement of performance-critical data
  - Immich database on metal2 local storage
  - Jellyfin database on metal0 local storage (SQLite lock optimization)
- **Automated Storage Management** - Proactive cleanup and monitoring
  - Threshold-based cleanup (80% usage trigger)
  - PostgreSQL space reclamation
  - Docker resource optimization

### Network & Security
- **Traefik Integration** - Dynamic service discovery and routing
  - Automatic SSL/TLS termination
  - Load balancing across swarm nodes
  - Service mesh networking
- **Cloudflared Tunnels** - Secure external access without port forwarding
- **Network Segmentation** - Isolated dokploy-network for all services
- **Health Checks** - Comprehensive service health monitoring

### Container Orchestration
- **Docker Swarm Mode** - Native container orchestration
  - Service placement constraints for optimal performance
  - Rolling updates with zero downtime
  - Automatic service recovery and scaling
- **Resource Management** - CPU and memory limits/reservations
- **Volume Management** - Persistent data with NFS and local bind mounts

## Quick Start Guide

### Prerequisites
- 3-node Docker Swarm cluster (metal0, metal1, metal2)
- NFS storage configured and mounted
- GitHub repository with secrets configured

### 1. Initial Setup
```bash
# Clone the repository
git clone https://github.com/RovxBot/Dokploy.git
cd Dokploy

# Set up storage management (run on metal2)
chmod +x scripts/setup-silent-cleanup.sh
./scripts/setup-silent-cleanup.sh

# Validate all compose files
chmod +x scripts/validate-compose.sh
./scripts/validate-compose.sh
```

### 2. Deploy Core Services
```bash
# Deploy monitoring first
docker stack deploy -c compose/netdata.yml netdata

# Deploy update monitoring
docker stack deploy -c update-monitor/compose.yml update-monitor

# Deploy applications (example)
docker stack deploy -c Immich.yml apps-immich-faefqq
docker stack deploy -c Jellyfin.yaml jellyfin
```

### 3. Configure GitHub Secrets
Set up webhook URLs in your GitHub repository secrets:
- `JELLYFIN_WEBHOOK`, `IMMICH_WEBHOOK`, `VAULTWARDEN_WEBHOOK`
- `NETDATA_WEBHOOK` for monitoring deployment notifications

## Manual Deployment

Use GitHub Actions workflow dispatch for targeted deployments:
1. Navigate to **Actions** tab in GitHub
2. Select **"Deploy to Dokploy"** workflow
3. Click **"Run workflow"**
4. Choose the specific service to deploy
5. Monitor deployment progress in real-time

## Monitoring & Management

### Storage Management
```bash
# Check storage status
./scripts/storage-management.sh check

# Manual cleanup
./scripts/storage-management.sh clean

# View cleanup logs
tail -f /var/log/storage-management/cleanup.log
```

### Service Management
```bash
# List all services
docker service ls

# Check service logs
docker service logs <service-name>

# Scale services
docker service scale <service-name>=<replicas>

# Update service
docker service update <service-name>
```

### Monitoring Dashboards
- **Netdata**: `http://<node-ip>:19999` (per-node monitoring)
- **Jellyfin**: `http://<cluster-ip>:8096`
- **Immich**: `http://immich.cooked.beer`
- **All services**: Available via Traefik routing

## 🛠️ Advanced Configuration

### Service Placement Strategy
- **Jellyfin** → metal0 (hardware transcoding, media access)
- **Immich Database** → metal2 (dedicated storage node)
- **Load-balanced services** → Any available node
- **Manager-only services** → Swarm managers only

### Storage Optimization
- **Jellyfin Transcoding** - 8GB tmpfs for ultra-fast transcoding
- **Database Optimization** - Local storage for performance-critical databases
- **NFS Caching** - Strategic use of NFS for shared data
- **Log Rotation** - Automated log management to prevent disk bloat

### Backup Strategy
- **Immich Photos** → Encrypted Backblaze B2 backup via Duplicacy
- **Configuration Data** → NFS storage with redundancy
- **Database Backups** → Automated PostgreSQL dumps
- **Retention Policies** → Automated cleanup of old backups

## 🚨 Troubleshooting

### Common Issues

**Storage Full (>90%)**
```bash
# Emergency cleanup
docker system prune -a --volumes --force
journalctl --vacuum-time=1d

# Check what's using space
du -sh /var/lib/docker/*
du -sh /srv/appdata/*
```

**Service Won't Start**
```bash
# Check service status
docker service ps <service-name>

# View service logs
docker service logs <service-name>

# Check node constraints
docker service inspect <service-name>
```

**Network Issues**
```bash
# Check swarm status
docker node ls
docker network ls

# Verify service connectivity
docker service ls
docker service inspect <service-name>
```

### Performance Optimization
- **Resource Limits** - Set appropriate CPU/memory limits
- **Placement Constraints** - Pin services to optimal nodes
- **Health Checks** - Implement proper health monitoring
- **Log Management** - Configure log rotation and retention

## 🎯 Key Features Highlights

### 🔥 What Makes This Lab Special

1. **Zero-Touch Automation** - Push to deploy, automated cleanup, self-healing
2. **Production-Ready** - Health checks, monitoring, backup, and recovery
3. **Scalable Architecture** - Docker Swarm with intelligent service placement
4. **Storage Intelligence** - Automated cleanup, monitoring, and optimization
5. **Security First** - Encrypted tunnels, secure networking, credential management
6. **Monitoring Everything** - Real-time metrics, update notifications, storage alerts
7. **Infrastructure as Code** - Everything version-controlled and reproducible

### 📈 Metrics & Monitoring
- **Real-time Performance** - CPU, RAM, disk, network per node
- **Container Metrics** - Resource usage, health status, restart counts
- **Storage Trends** - Usage patterns, growth prediction, cleanup effectiveness
- **Update Tracking** - Available updates, deployment history, rollback capability
- **Backup Verification** - Backup success rates, retention compliance

### 🔄 Automation Workflows
- **Daily**: Storage cleanup (if needed), log rotation, health checks
- **Weekly**: PostgreSQL maintenance, update notifications, backup verification
- **Monthly**: Security updates, capacity planning, performance review
- **On-Demand**: Service deployment, scaling, rollback, emergency cleanup

---

## 📚 Documentation

- **[Storage Management Guide](Doco/storage-management-guide.md)** - Comprehensive storage automation
- **[Docker Swarm NFS Guide](Doco/docker-swarm-nfs-guide.md)** - NFS integration setup
- **[Jellyfin SMB Guide](Doco/jellyfin-smb-mount-guide.md)** - Media storage configuration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes locally with `./scripts/validate-compose.sh`
4. Submit a pull request
5. Automated deployment will handle the rest!

---

**Built with ❤️ for the homelab community**
