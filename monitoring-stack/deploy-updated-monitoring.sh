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

# Check IP connectivity (what you can access from browser)
for ip in 192.168.1.190 192.168.1.191 192.168.1.192; do
    echo -n "  Checking $ip:9100... "
    if timeout 5 bash -c "</dev/tcp/$ip/9100" 2>/dev/null; then
        echo "✅ Reachable"
    else
        echo "❌ Not reachable"
    fi

    echo -n "  Checking $ip:8085... "
    if timeout 5 bash -c "</dev/tcp/$ip/8085" 2>/dev/null; then
        echo "✅ Reachable"
    else
        echo "❌ Not reachable"
    fi
done

echo ""
echo "🔍 Testing hostname resolution (for Prometheus container)..."
for node in metal0 metal1 metal2; do
    echo -n "  Resolving $node... "
    if nslookup $node >/dev/null 2>&1 || getent hosts $node >/dev/null 2>&1; then
        echo "✅ Resolves"
    else
        echo "❌ Does not resolve (will use extra_hosts)"
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
echo "   - metal0:8085 (cadvisor) - Updated to avoid Sabnzbd conflict"
echo "   - metal1:8085 (cadvisor)"
echo "   - metal2:8085 (cadvisor)"
echo ""
echo "🔧 Network Fix Applied:"
echo "   - Added extra_hosts to Prometheus container for hostname resolution"
echo "   - This allows Prometheus to reach metal0, metal1, metal2 by hostname"

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
