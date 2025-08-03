# Cluster Overview Dashboard

This dashboard provides a comprehensive view of your cluster with the following metrics:

## Dashboard Features

### 1. Active Alerts
- Shows all currently firing alerts from Prometheus
- Color-coded by severity (critical = red, warning = yellow)
- Displays alert name, instance, and severity

### 2. CPU Usage by Node
- Real-time CPU usage percentage for each node (metal0, metal1, metal2)
- Time series graph showing trends over time
- Threshold indicators (red at 80%+)

### 3. RAM Usage by Node
- Memory utilization percentage for each node
- Shows available vs used memory
- Time series visualization

### 4. Disk Usage by Node
- Root filesystem usage percentage for each node
- Monitors the "/" mountpoint
- Excludes temporary filesystems

### 5. Running Containers by Node
- Table view of all running containers
- Shows container name, image, and node location
- Color-coded by container state (green=running, red=exited, yellow=paused)

### 6. Network Activity by Node
- Network traffic in/out for each node
- Excludes loopback interface
- Shows bytes per second with negative values for outbound traffic

### 7. Cluster Uptime by Node
- Shows how long each node has been running since last boot
- Displayed in seconds (can be formatted to days/hours in Grafana)

## Setup Instructions

### Prerequisites
- Docker Swarm cluster with nodes named metal0, metal1, metal2
- Node-exporter running on each node (port 9100) - ✅ VERIFIED
- cAdvisor running on each node (port 8080) - ✅ VERIFIED

### Current Status
Your monitoring stack is deployed and working:
- Prometheus is successfully scraping metrics from both services
- cadvisor: 1/1 up at `cadvisor:8080`
- node_exporter: 1/1 up at `node-exporter:9100`

### 1. Update Prometheus Configuration
The prometheus.yml has been updated to scrape metrics from all three nodes:
```yaml
- job_name: 'node_exporter'
  static_configs:
    - targets:
        - 'metal0:9100'
        - 'metal1:9100'
        - 'metal2:9100'
```

### 2. Deploy the Updated Monitoring Stack

**IMPORTANT**: The configuration has been updated to scrape metrics from individual nodes (metal0, metal1, metal2) instead of the aggregated service endpoints.

```bash
# Navigate to the monitoring stack directory
cd monitoring-stack

# Deploy the updated monitoring stack
docker stack deploy -c compose.yml monitoring

# Verify services are running
docker service ls | grep monitoring

# Check that all nodes are reachable
# Test node-exporter on each node:
curl http://metal0:9100/metrics
curl http://metal1:9100/metrics
curl http://metal2:9100/metrics

# Test cAdvisor on each node:
curl http://metal0:8080/metrics
curl http://metal1:8080/metrics
curl http://metal2:8080/metrics
```

**Alternative**: Use the deployment script:
```bash
# On Linux/Mac:
./deploy-updated-monitoring.sh

# On Windows:
bash deploy-updated-monitoring.sh
```

### 3. Access Grafana
- URL: http://cluster.cooked.beer (or http://localhost:3100)
- Login with credentials from your environment variables
- The "Cluster Overview Dashboard" should be automatically provisioned

### 4. Verify Data Sources and Targets
- Prometheus should be automatically configured as the default data source
- **CRITICAL**: Check Prometheus targets at http://localhost:9090/targets
- You should now see **6 individual targets**:
  - metal0:9100, metal1:9100, metal2:9100 (node_exporter)
  - metal0:8080, metal1:8080, metal2:8080 (cadvisor)
- All targets should show as "UP" status

## Updated Configuration

The monitoring stack has been updated to scrape metrics directly from individual nodes instead of using Docker Swarm service discovery. This ensures you get per-node metrics for metal0, metal1, and metal2.

### Key Changes Made:
1. **Prometheus Configuration**: Now targets each node directly
2. **Port Configuration**: Services use host mode ports for direct access
3. **Dashboard Queries**: Updated to show individual node metrics
4. **New Panel Added**: Disk space used/free in bytes (in addition to percentage)

## Troubleshooting

### Context Deadline Exceeded Error (Specific Node Unreachable)

If you see errors like "Get 'http://metal0:9100/metrics': context deadline exceeded" for a specific node:

1. **Check if the node services are running**:
   ```bash
   # Check which nodes have the services running
   docker service ps monitoring_node-exporter --format "table {{.Node}}\t{{.CurrentState}}\t{{.Error}}"
   docker service ps monitoring_cadvisor --format "table {{.Node}}\t{{.CurrentState}}\t{{.Error}}"
   ```

2. **Test direct connectivity from Prometheus container**:
   ```bash
   # Get the Prometheus container ID
   docker ps | grep prometheus

   # Test connectivity from inside Prometheus container
   docker exec -it <prometheus-container-id> wget -O- --timeout=5 http://metal0:9100/metrics
   docker exec -it <prometheus-container-id> wget -O- --timeout=5 http://metal0:8080/metrics
   ```

3. **Check if services are bound to the correct interfaces on metal0**:
   ```bash
   # SSH to metal0 and check if services are listening
   ssh metal0 "netstat -tlnp | grep -E ':(9100|8080)'"
   # or
   ssh metal0 "ss -tlnp | grep -E ':(9100|8080)'"
   ```

4. **Verify Docker Swarm network connectivity**:
   ```bash
   # Check if metal0 is properly connected to the swarm
   docker node ls
   docker node inspect metal0 --format '{{.Status.State}}'
   ```

5. **Restart services on the problematic node**:
   ```bash
   # Force restart services on metal0
   docker service update --force monitoring_node-exporter
   docker service update --force monitoring_cadvisor

   # Wait a moment, then check
   docker service ps monitoring_node-exporter | grep metal0
   docker service ps monitoring_cadvisor | grep metal0
   ```

### Manager Node (metal0) Connectivity Issues

**IMPORTANT**: If metal0 is your Docker Swarm manager node, this explains the connectivity issues. Manager nodes sometimes have different service placement behavior.

Since metal1 and metal2 are working fine, the issue is specifically with metal0 being the manager. Try these steps in order:

1. **Immediate Fix - Restart services on metal0**:
   ```bash
   # Force update to restart services on all nodes (including metal0)
   docker service update --force monitoring_node-exporter
   docker service update --force monitoring_cadvisor
   ```

2. **Check if metal0 is accessible from the manager node**:
   ```bash
   # Test basic connectivity
   ping metal0
   telnet metal0 9100
   telnet metal0 8080
   ```

3. **If metal0 is completely unreachable, temporarily exclude it**:
   ```bash
   # Edit prometheus.yml to temporarily remove metal0 targets
   # Comment out or remove the metal0 lines:
   # - 'metal0:9100'  # <- comment this out
   # - 'metal0:8080'  # <- comment this out

   # Then redeploy
   docker stack deploy -c compose.yml monitoring
   ```

### Only Seeing Some Nodes' Data
If the dashboard shows data from some nodes but not others:

### No Data Showing
1. Verify node-exporter is running on all nodes:
   ```bash
   curl http://metal0:9100/metrics
   curl http://metal1:9100/metrics
   curl http://metal2:9100/metrics
   ```

2. Check cAdvisor is accessible:
   ```bash
   curl http://metal0:8080/metrics
   curl http://metal1:8080/metrics
   curl http://metal2:8080/metrics
   ```

3. Verify Prometheus targets:
   - Go to http://prometheus:9090/targets
   - All targets should show as "UP"

### Network Connectivity Issues
- Ensure all nodes can communicate on the required ports
- Check Docker Swarm overlay network configuration
- Verify firewall rules allow traffic on ports 9100 and 8080

### Dashboard Not Loading
- Check Grafana logs: `docker service logs monitoring_grafana`
- Verify dashboard provisioning: Check `/etc/grafana/provisioning/dashboards/`
- Restart Grafana service if needed: `docker service update --force monitoring_grafana`

## Customization

### Adding More Nodes
To add additional nodes, update the prometheus.yml file:
```yaml
- job_name: 'node_exporter'
  static_configs:
    - targets:
        - 'metal0:9100'
        - 'metal1:9100'
        - 'metal2:9100'
        - 'metal3:9100'  # Add new nodes here
```

### Modifying Thresholds
Edit the dashboard JSON file to adjust warning thresholds:
- CPU usage threshold: Currently set at 80%
- Memory usage threshold: Currently set at 80%
- Disk usage threshold: Currently set at 80%

### Adding Custom Metrics
You can extend the dashboard by adding new panels with additional Prometheus queries for:
- Network latency between nodes
- Docker service health
- Custom application metrics
- Storage I/O performance

## Dashboard Refresh
The dashboard automatically refreshes every 30 seconds. You can change this in the Grafana UI or by modifying the JSON configuration.
