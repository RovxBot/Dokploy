# Clean ELK Stack Deployment Guide

Based on the proven guide from https://blog.creekorful.org/2020/12/how-to-setup-easily-elk-docker-swarm/

## Step 1: Deploy the Stack

```bash
# Remove any existing monitoring stack
docker stack rm monitoring-stack

# Deploy the clean ELK stack
docker stack deploy -c monitoring-stack/compose-clean.yml elk-stack
```

## Step 2: Configure Logstash Pipeline

After the stack is deployed, you need to copy the logstash configuration:

```bash
# Find the logstash container
docker ps | grep logstash

# Copy the logstash configuration to the volume
docker cp monitoring-stack/logstash.conf <logstash-container-id>:/usr/share/logstash/pipeline/logstash.conf

# Restart logstash to pick up the configuration
docker service update --force elk-stack_logstash
```

## Step 3: Configure Metricbeat (Optional)

If you want system metrics:

```bash
# Find a metricbeat container
docker ps | grep metricbeat

# Copy the metricbeat configuration
docker cp monitoring-stack/metricbeat.yml <metricbeat-container-id>:/usr/share/metricbeat/metricbeat.yml

# Restart metricbeat
docker service update --force elk-stack_metricbeat
```

## Step 4: Configure Docker Logging (Optional)

### Option A: Global Configuration (All containers)
Edit `/etc/docker/daemon.json` on all nodes:

```json
{
  "log-driver": "gelf",
  "log-opts": {
    "gelf-address": "udp://localhost:12201"
  }
}
```

Then restart Docker daemon:
```bash
sudo systemctl restart docker
```

### Option B: Per-Service Configuration
Add to your application compose files:

```yaml
services:
  your-service:
    # ... other config
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
```

## Step 5: Access Kibana

- URL: `https://cluster.cooked.beer` (via Traefik)
- Or direct: `http://<worker-node-ip>:5601`

## Services Distribution

- **metal0 (Jellyfin node)**: Only logstash agent (minimal resource usage)
- **metal1/metal2**: Elasticsearch, Kibana, and optionally metricbeat

## Resource Usage

- **Elasticsearch**: 2GB RAM, 2 CPUs (on worker nodes)
- **Kibana**: 1GB RAM, 1 CPU (on worker nodes)  
- **Logstash**: 512MB RAM, 0.5 CPU (global - all nodes)
- **Metricbeat**: 128MB RAM, 0.2 CPU (worker nodes only)

**Total on metal0**: ~512MB RAM, 0.5 CPU (just logstash agent)

## Verification Commands

```bash
# Check stack status
docker stack services elk-stack

# Check service placement
docker service ps elk-stack_elasticsearch
docker service ps elk-stack_kibana

# Check Elasticsearch health
curl -X GET "localhost:9200/_cluster/health?pretty"

# View logs
docker service logs elk-stack_elasticsearch
docker service logs elk-stack_kibana
docker service logs elk-stack_logstash
```

## Troubleshooting

1. **Elasticsearch won't start**: Check memory limits and ensure it's on worker nodes
2. **Kibana can't connect**: Wait for Elasticsearch to be fully ready
3. **Logstash not receiving logs**: Verify the GELF endpoint is accessible on port 12201
4. **No metrics**: Check metricbeat configuration and Docker socket access

## Next Steps

1. Deploy the stack
2. Configure logstash pipeline
3. Optionally configure Docker logging
4. Access Kibana dashboard
5. Create visualizations and dashboards for your monitoring needs
