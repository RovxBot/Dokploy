#!/bin/bash

# Shepherd Deployment Script
# This script deploys Shepherd to monitor and auto-update your Docker Swarm services

set -e

STACK_NAME="shepherd"
COMPOSE_FILE="compose.yml"

echo "🐑 Deploying Shepherd Auto-Updater..."

# Check if we're in a Docker Swarm
if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
    echo "❌ Error: This node is not part of a Docker Swarm"
    echo "Please initialize or join a Docker Swarm first:"
    echo "  docker swarm init"
    exit 1
fi

# Check if we're on a manager node
if ! docker info --format '{{.Swarm.ControlAvailable}}' | grep -q "true"; then
    echo "❌ Error: This script must be run on a Docker Swarm manager node"
    exit 1
fi

# Ensure the dokploy-network exists
if ! docker network ls --format '{{.Name}}' | grep -q "^dokploy-network$"; then
    echo "📡 Creating dokploy-network..."
    docker network create --driver overlay --attachable dokploy-network
else
    echo "✅ dokploy-network already exists"
fi

# Deploy the stack
echo "🚀 Deploying Shepherd stack..."
docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"

echo ""
echo "✅ Shepherd has been deployed successfully!"
echo ""
echo "📋 Stack Information:"
docker stack services "$STACK_NAME"

echo ""
echo "🔍 To monitor Shepherd:"
echo "  docker service logs -f ${STACK_NAME}_scheduler"
echo "  docker service logs -f ${STACK_NAME}_app"
echo ""
echo "⏰ Shepherd is scheduled to run daily at 2:00 AM"
echo "🎯 It will automatically update all your Docker services when new versions are available"
echo ""
echo "🛠️  To manually trigger Shepherd (for testing):"
echo "  docker service update --force ${STACK_NAME}_app"
echo ""
echo "📊 To check which services will be monitored:"
echo "  docker service ls --format 'table {{.Name}}\t{{.Image}}\t{{.Replicas}}'"
