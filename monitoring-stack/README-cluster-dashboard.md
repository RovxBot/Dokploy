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

### 2. Deploy the Monitoring Stack
```bash
# Deploy the monitoring stack
docker stack deploy -c monitoring-stack/compose.yml monitoring

# Verify services are running
docker service ls
```

### 3. Access Grafana
- URL: http://cluster.cooked.beer (or http://localhost:3100)
- Login with credentials from your environment variables
- The "Cluster Overview Dashboard" should be automatically provisioned

### 4. Verify Data Sources
- Prometheus should be automatically configured as the default data source
- Check that metrics are being collected from all three nodes

## Important Notes for Docker Swarm

Your current setup uses Docker Swarm with `deploy: mode: global` for both node-exporter and cAdvisor. This means:

1. **Service Discovery**: Prometheus sees the services through Docker's internal load balancer
2. **Node Identification**: Individual node metrics are identified through labels in the metrics themselves
3. **Single Endpoint**: Each service appears as one endpoint in Prometheus targets, but contains data from all nodes

### Expected Behavior
- The dashboard should show metrics from all three nodes (metal0, metal1, metal2)
- Each metric will be labeled with the source node information
- If you only see one node's data, the global deployment may need adjustment

## Troubleshooting

### Only Seeing One Node's Data
If the dashboard only shows data from one node instead of all three:

1. **Check global deployment**:
   ```bash
   docker service ps monitoring_node-exporter
   docker service ps monitoring_cadvisor
   ```
   You should see one task per node.

2. **Verify all nodes are active**:
   ```bash
   docker node ls
   ```
   All nodes should show as "Ready" and "Active".

3. **Check service constraints**:
   The services should be running on all nodes without placement constraints.

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
