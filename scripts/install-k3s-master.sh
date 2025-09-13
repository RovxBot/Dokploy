#!/bin/bash

# Install k3s on metal0 (control plane)
# This script sets up k3s with configuration suitable for running alongside Docker Swarm

set -e

echo "=== Installing k3s Control Plane on metal0 ==="

# Configuration for k3s to avoid conflicts with Docker Swarm
export INSTALL_K3S_EXEC="--cluster-cidr=172.16.0.0/16 --service-cidr=172.17.0.0/16 --cluster-dns=172.17.0.10 --disable=traefik --write-kubeconfig-mode=644"

# Install k3s
curl -sfL https://get.k3s.io | sh -

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
sleep 30

# Check k3s status
sudo systemctl status k3s --no-pager

# Get node token for worker nodes
echo "=== k3s Node Token ==="
echo "Save this token for joining worker nodes:"
sudo cat /var/lib/rancher/k3s/server/node-token

# Get kubeconfig
echo "=== Kubeconfig ==="
echo "Kubeconfig location: /etc/rancher/k3s/k3s.yaml"
echo "To use kubectl:"
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"

# Test kubectl
echo "=== Testing kubectl ==="
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
kubectl get pods -A

echo "=== k3s Control Plane Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Join worker nodes using the token above"
echo "2. Install Kubero CLI"
echo "3. Install Kubero on the cluster"
