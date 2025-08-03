#!/bin/bash

echo "🚀 Deploying Updated Monitoring Stack for Individual Node Metrics"
echo "=================================================================="

# Check if we're in a Docker Swarm
if ! docker info | grep -q "Swarm: active"; then
    echo "❌ Error: Docker Swarm is not active. Please initialize or join a swarm first."
    exit 1
fi

# Check if nodes metal0, metal1, metal2 are reachable
echo "🔍 Checking node connectivity..."

for node in metal0 metal1 metal2; do
    echo -n "  Checking $node:9100... "
    if timeout 5 bash -c "</dev/tcp/$node/9100" 2>/dev/null; then
        echo "✅ Reachable"
    else
        echo "❌ Not reachable"
        echo "    Make sure node-exporter is running on $node:9100"
    fi
    
    echo -n "  Checking $node:8080... "
    if timeout 5 bash -c "</dev/tcp/$node/8080" 2>/dev/null; then
        echo "✅ Reachable"
    else
        echo "❌ Not reachable"
        echo "    Make sure cAdvisor is running on $node:8080"
    fi
done

echo ""
echo "📋 Current monitoring stack status:"
docker service ls | grep monitoring || echo "  No monitoring services found"

echo ""
echo "🔄 Updating monitoring stack..."

# Deploy the updated stack
docker stack deploy -c compose.yml monitoring

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

echo ""
echo "📊 Updated service status:"
docker service ls | grep monitoring

echo ""
echo "🎯 Checking Prometheus targets..."
echo "   You can verify targets at: http://localhost:9090/targets"
echo "   Expected targets:"
echo "   - metal0:9100 (node_exporter)"
echo "   - metal1:9100 (node_exporter)" 
echo "   - metal2:9100 (node_exporter)"
echo "   - metal0:8080 (cadvisor)"
echo "   - metal1:8080 (cadvisor)"
echo "   - metal2:8080 (cadvisor)"

echo ""
echo "📈 Access your updated dashboard:"
echo "   Grafana: http://cluster.cooked.beer (or http://localhost:3100)"
echo "   Dashboard: 'Cluster Overview Dashboard'"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔧 If you don't see individual node metrics:"
echo "   1. Verify all nodes are reachable on ports 9100 and 8080"
echo "   2. Check Prometheus targets: http://localhost:9090/targets"
echo "   3. Restart the monitoring stack if needed:"
echo "      docker stack rm monitoring"
echo "      sleep 10"
echo "      docker stack deploy -c compose.yml monitoring"
