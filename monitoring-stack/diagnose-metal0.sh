#!/bin/bash

echo "🔍 Diagnosing metal0 connectivity issues"
echo "========================================"

# Check basic connectivity
echo "1. Testing basic connectivity to metal0..."
if ping -c 3 metal0 >/dev/null 2>&1; then
    echo "   ✅ metal0 is reachable via ping"
else
    echo "   ❌ metal0 is NOT reachable via ping"
    echo "   🔧 Check network connectivity and DNS resolution"
    exit 1
fi

# Check specific ports
echo ""
echo "2. Testing port connectivity..."

echo -n "   Testing metal0:9100 (node-exporter)... "
if timeout 5 bash -c "</dev/tcp/metal0/9100" 2>/dev/null; then
    echo "✅ Port open"
else
    echo "❌ Port not accessible"
fi

echo -n "   Testing metal0:8080 (cadvisor)... "
if timeout 5 bash -c "</dev/tcp/metal0/8080" 2>/dev/null; then
    echo "✅ Port open"
else
    echo "❌ Port not accessible"
fi

# Check Docker Swarm status
echo ""
echo "3. Checking Docker Swarm status..."
echo "   Node status:"
docker node ls | grep -E "(ID|metal0)" || echo "   ❌ metal0 not found in swarm nodes"

echo ""
echo "   Service placement on metal0:"
echo "   node-exporter tasks:"
docker service ps monitoring_node-exporter --format "table {{.Node}}\t{{.CurrentState}}\t{{.Error}}" | grep -E "(NODE|metal0)" || echo "   ❌ No node-exporter task on metal0"

echo "   cadvisor tasks:"
docker service ps monitoring_cadvisor --format "table {{.Node}}\t{{.CurrentState}}\t{{.Error}}" | grep -E "(NODE|metal0)" || echo "   ❌ No cadvisor task on metal0"

# Test from Prometheus container
echo ""
echo "4. Testing from Prometheus container..."
PROM_CONTAINER=$(docker ps --format "table {{.Names}}" | grep prometheus | head -1)

if [ -n "$PROM_CONTAINER" ]; then
    echo "   Found Prometheus container: $PROM_CONTAINER"
    
    echo -n "   Testing metal0:9100 from Prometheus... "
    if docker exec "$PROM_CONTAINER" wget -q --timeout=5 -O /dev/null http://metal0:9100/metrics 2>/dev/null; then
        echo "✅ Success"
    else
        echo "❌ Failed"
    fi
    
    echo -n "   Testing metal0:8080 from Prometheus... "
    if docker exec "$PROM_CONTAINER" wget -q --timeout=5 -O /dev/null http://metal0:8080/metrics 2>/dev/null; then
        echo "✅ Success"
    else
        echo "❌ Failed"
    fi
else
    echo "   ❌ Prometheus container not found"
fi

# Suggested fixes
echo ""
echo "🔧 Suggested fixes:"
echo "=================="

echo "1. Restart services on metal0:"
echo "   docker service update --force monitoring_node-exporter"
echo "   docker service update --force monitoring_cadvisor"
echo ""

echo "2. If metal0 is completely unreachable, temporarily exclude it:"
echo "   Edit prometheus.yml and comment out metal0 targets:"
echo "   # - 'metal0:9100'"
echo "   # - 'metal0:8080'"
echo "   Then: docker stack deploy -c compose.yml monitoring"
echo ""

echo "3. Check if services are running on metal0:"
echo "   ssh metal0 'docker ps | grep -E \"(node-exporter|cadvisor)\"'"
echo ""

echo "4. Check firewall/network rules on metal0:"
echo "   ssh metal0 'netstat -tlnp | grep -E \":(9100|8080)\"'"
