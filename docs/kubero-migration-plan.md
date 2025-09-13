# Kubero Migration Plan

## Overview
Gradual migration from Dokploy (Docker Swarm) to Kubero (Kubernetes) on the same hardware cluster.

## Hardware Setup
- **metal0**: Swarm Manager + K8s Control Plane
- **metal1-metal6**: Swarm Workers + K8s Workers

## Phase 1: Install Kubernetes (k3s)

### Step 1: Install k3s Control Plane on metal0
```bash
# On metal0
chmod +x scripts/install-k3s-master.sh
sudo ./scripts/install-k3s-master.sh
```

### Step 2: Join Worker Nodes (metal1-metal6)
```bash
# Get token from metal0
sudo cat /var/lib/rancher/k3s/server/node-token

# On each worker node (metal1-metal6)
# Edit scripts/install-k3s-worker.sh with:
# - K3S_MASTER_IP="192.168.1.190"  # metal0 IP
# - K3S_TOKEN="<token_from_master>"

chmod +x scripts/install-k3s-worker.sh
sudo ./scripts/install-k3s-worker.sh
```

### Step 3: Verify Cluster
```bash
# On metal0
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
# Should show all 7 nodes
```

## Phase 2: Install Kubero

### Step 1: Install Kubero
```bash
# On metal0
chmod +x scripts/install-kubero.sh
sudo ./scripts/install-kubero.sh
```

### Step 2: Access Kubero
```bash
# Get service details
kubectl get svc -n kubero-system

# Get admin password
kubectl get secret kubero-admin -n kubero-system -o jsonpath='{.data.password}' | base64 -d
```

## Phase 3: Network Configuration

### Current (Docker Swarm)
- **Overlay networks**: 10.0.x.x/24
- **HTTP**: 80, **HTTPS**: 443
- **Domains**: *.cooked.beer

### New (Kubernetes)
- **Pod CIDR**: 172.16.0.0/16
- **Service CIDR**: 172.17.0.0/16
- **HTTP**: 8080, **HTTPS**: 8443 (initially)
- **Domains**: *.k8s.cooked.beer

## Phase 4: Resource Allocation

### Initial Split (per node)
- **Docker Swarm**: 50% CPU, 50% RAM
- **Kubernetes**: 50% CPU, 50% RAM

### Adjust as services migrate
- Gradually shift resources from Swarm to K8s
- Monitor usage with Netdata

## Phase 5: Service Migration Order

1. **Test Services** (new deployments on K8s)
2. **Monitoring** (Netdata equivalent)
3. **Non-critical** (DIUN, backup tools)
4. **Media Management** (Sonarr, Radarr, Prowlarr)
5. **Media Services** (Jellyfin, Immich)
6. **Infrastructure** (Vaultwarden, Home Assistant)

## Storage Strategy

### NFS Volumes
```bash
# Current Swarm volumes
/srv/nfs/swarm/

# New K8s volumes  
/srv/nfs/k8s/
```

### Backup Strategy
- Extend Duplicacy to backup K8s volumes
- Backup K8s cluster state
- Maintain separate backup schedules

## Monitoring

### Dual Platform Monitoring
- **Netdata**: Monitor both Swarm and K8s
- **Separate dashboards** for each platform
- **Resource usage tracking** per platform

## Rollback Plan

### If Issues Arise
1. **Stop K8s services** causing problems
2. **Redirect traffic** back to Swarm
3. **Investigate and fix** K8s issues
4. **Resume migration** when ready

### Complete Rollback
1. **Migrate services** back to Swarm
2. **Remove K8s cluster**
3. **Reclaim resources** for Swarm

## Success Criteria

### Phase 1 Complete
- [ ] All 7 nodes in K8s cluster
- [ ] kubectl working from metal0
- [ ] No conflicts with Docker Swarm

### Phase 2 Complete  
- [ ] Kubero UI accessible
- [ ] Can deploy test applications
- [ ] Networking isolated from Swarm

### Migration Complete
- [ ] All services running on K8s
- [ ] Swarm cluster decommissioned
- [ ] Resources fully allocated to K8s
- [ ] Monitoring and backups working

## Timeline Estimate

- **Phase 1** (K8s setup): 1-2 days
- **Phase 2** (Kubero install): 1 day  
- **Phase 3** (Network config): 1-2 days
- **Phase 4** (Service migration): 2-4 weeks
- **Total**: 3-5 weeks

## Next Steps

1. **Review this plan** and adjust as needed
2. **Start with Phase 1** - install k3s
3. **Test thoroughly** before proceeding
4. **Document any issues** and solutions
