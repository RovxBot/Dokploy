#!/bin/bash

# Install Kubero on k3s cluster
# Run this script on metal0 (master node)

set -e

echo "=== Installing Kubero ==="

# Set kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Check cluster is ready
echo "Checking cluster status..."
kubectl get nodes

# Install Kubero CLI
echo "Installing Kubero CLI..."
if ! command -v kubero &> /dev/null; then
    curl -L https://get.kubero.dev | bash
    
    # Add to PATH if needed
    if ! command -v kubero &> /dev/null; then
        export PATH=$PATH:/usr/local/bin
    fi
fi

# Verify kubero CLI
kubero version

# Install Kubero on cluster
echo "Installing Kubero on cluster..."
echo "This will install:"
echo "- Kubero UI"
echo "- Kubero Operator"
echo "- Required CRDs"
echo ""

# Run kubero install
kubero install

echo "=== Kubero Installation Started ==="
echo ""
echo "Monitor installation progress:"
echo "kubectl get pods -n kubero-system -w"
echo ""
echo "Once ready, access Kubero at:"
echo "kubectl get svc -n kubero-system"
echo ""
echo "Get admin password:"
echo "kubectl get secret kubero-admin -n kubero-system -o jsonpath='{.data.password}' | base64 -d"
