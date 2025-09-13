#!/bin/bash

# Install k3s worker nodes (metal1-metal6)
# Run this script on each worker node

set -e

# Configuration - UPDATE THESE VALUES
K3S_MASTER_IP="192.168.1.190"  # metal0 IP address
K3S_TOKEN=""  # Token from master node (get from /var/lib/rancher/k3s/server/node-token)

if [ -z "$K3S_TOKEN" ]; then
    echo "Error: Please set K3S_TOKEN variable with the token from master node"
    echo "Get token from master: sudo cat /var/lib/rancher/k3s/server/node-token"
    exit 1
fi

echo "=== Installing k3s Worker Node ==="
echo "Master IP: $K3S_MASTER_IP"
echo "Token: ${K3S_TOKEN:0:20}..."

# Install k3s worker
export K3S_URL="https://$K3S_MASTER_IP:6443"
export K3S_TOKEN="$K3S_TOKEN"

curl -sfL https://get.k3s.io | sh -

# Wait for k3s agent to be ready
echo "Waiting for k3s agent to be ready..."
sleep 20

# Check k3s agent status
sudo systemctl status k3s-agent --no-pager

echo "=== k3s Worker Node Installation Complete ==="
echo ""
echo "Check node status from master:"
echo "kubectl get nodes"
