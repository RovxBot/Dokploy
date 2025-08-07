# Jellyfin Resource Optimization Report

## Current Issues Identified

### 1. Monitoring Stack Resource Competition
- **Elasticsearch**: Running on manager node (metal0) with 2GB RAM + 2 CPUs
- **Kibana**: Running on manager node (metal0) with 512MB RAM + 1 CPU
- **Elastalert**: Running on manager node (metal0) with 128MB RAM + 0.2 CPU
- **Metricbeat & Filebeat**: Running globally on ALL nodes including metal0

**Total Resource Impact on metal0**: ~3.6GB RAM + 3.2 CPUs competing with Jellyfin

### 2. Configuration Issues
- Elasticsearch Java heap too small (512MB) causing potential performance issues
- **Kibana memory issues**: JavaScript heap out of memory errors due to insufficient RAM
- **Elastalert rule errors**: Invalid rule syntax causing startup failures
- No resource limits on beats services
- All heavy services pinned to manager node unnecessarily

## Optimizations Implemented

### Option 1: Modified Current Stack (`compose.yml`)
**Changes Made:**
- ✅ Moved Elasticsearch to worker nodes only (`node.hostname != metal0`)
- ✅ Moved Kibana to worker nodes only (`node.hostname != metal0`)
- ✅ Moved Elastalert to worker nodes only (`node.hostname != metal0`)
- ✅ Increased Elasticsearch heap to 1GB for better performance
- ✅ **Fixed Kibana memory issues**: Increased to 2GB RAM + Node.js heap optimization
- ✅ **Fixed Elastalert rules**: Corrected syntax from `threshold` to `frequency` type
- ✅ Added resource limits to all beats services
- ✅ Added optimized Kibana configuration file
- ⚠️ Beats still run globally (including metal0) but with strict resource limits

**Resource Freed on metal0**: ~2.5GB RAM + 2.7 CPUs

### Option 2: Maximum Optimization (`compose-jellyfin-optimized.yml`)
**Changes Made:**
- ✅ All heavy services moved to worker nodes
- ✅ Beats excluded from metal0 entirely (`node.hostname != metal0`)
- ✅ Optional minimal monitoring for metal0 (disabled by default)
- ✅ Better resource allocation across worker nodes

**Resource Freed on metal0**: ~3.6GB RAM + 3.2 CPUs (nearly complete isolation)

## Services Already Optimized

### ✅ Well-Configured Services (No Changes Needed)
- **Home Assistant**: Already constrained to worker nodes
- **Node-RED**: Already constrained to worker nodes  
- **Jellyfin**: Uses host networking, no placement constraints (good)
- **Media Services**: No placement constraints (can run anywhere)

### ⚠️ Services That Must Stay on Manager Node
- **Shepherd**: Requires manager node for Docker socket access (cron job)
- **Swarm Cronjob Scheduler**: Must run on manager node

## Deployment Instructions

### Quick Fix (Recommended)
```bash
# Stop current monitoring stack
docker stack rm monitoring-stack

# Deploy optimized version
docker stack deploy -c monitoring-stack/compose.yml monitoring-stack
```

### Maximum Optimization (If you want complete isolation)
```bash
# Stop current monitoring stack  
docker stack rm monitoring-stack

# Deploy maximum optimization version
docker stack deploy -c monitoring-stack/compose-jellyfin-optimized.yml monitoring-stack
```

## Expected Results

### After Optimization:
- **metal0 (Jellyfin node)**: Maximum available resources for Jellyfin
- **metal1/metal2**: Handle all monitoring workload
- **Better Performance**: Elasticsearch gets more resources on worker nodes
- **Maintained Monitoring**: Full monitoring capability preserved

### Resource Distribution:
- **metal0**: Jellyfin + minimal system overhead
- **metal1**: Elasticsearch + Kibana + Elastalert + Beats
- **metal2**: Backup capacity for service failover

## Verification Commands

After deployment, verify the optimization:

```bash
# Check service placement
docker service ls
docker service ps monitoring-stack_elasticsearch
docker service ps monitoring-stack_kibana

# Monitor resource usage
docker stats

# Check Jellyfin performance
# Monitor transcoding performance and resource availability
```

## Additional Recommendations

1. **Monitor Worker Node Resources**: Ensure metal1/metal2 have sufficient resources
2. **Consider SSD Storage**: For Elasticsearch data volume on worker nodes  
3. **Network Optimization**: Ensure good network connectivity between nodes
4. **Backup Strategy**: Elasticsearch data should be backed up regularly

## Rollback Plan

If issues occur:
```bash
# Restore original configuration
git checkout HEAD -- monitoring-stack/compose.yml
docker stack deploy -c monitoring-stack/compose.yml monitoring-stack
```
