#!/bin/bash
# Stop Skaffold and cleanup Kubernetes resources
# This script stops Skaffold dev mode and cleans up resources

set -e

echo "🛑 Stopping Skaffold and cleaning up..."

# Check if skaffold is running
if pgrep -f "skaffold dev" > /dev/null; then
    echo "⚠️  Skaffold dev is running. Press Ctrl+C in the Skaffold terminal to stop it first."
    echo "   Or run: pkill -f 'skaffold dev'"
    read -p "Continue with cleanup anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Delete resources using Skaffold
if command -v skaffold &> /dev/null; then
    echo "🗑️  Deleting resources with Skaffold..."
    skaffold delete || echo "⚠️  Skaffold delete failed (may already be cleaned up)"
else
    echo "⚠️  Skaffold not found, using kubectl directly..."
fi

# Cleanup using kubectl
if command -v kubectl &> /dev/null; then
    echo "🧹 Cleaning up Kubernetes resources..."
    
    # Delete deployments
    kubectl delete deployment deepiri-core-api deepiri-cyrex redis localai 2>/dev/null || true
    
    # Delete services
    kubectl delete service backend-service cyrex-service redis-service localai-service 2>/dev/null || true
    
    # Delete PVCs (optional - uncomment if you want to delete data)
    # kubectl delete pvc redis-pvc 2>/dev/null || true
    
    # Delete ConfigMaps and Secrets
    kubectl delete configmap deepiri-config 2>/dev/null || true
    kubectl delete secret deepiri-secrets 2>/dev/null || true
    
    echo "✅ Kubernetes resources cleaned up"
else
    echo "⚠️  kubectl not found. Skipping Kubernetes cleanup."
fi

# Optionally stop Minikube
read -p "Stop Minikube cluster? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v minikube &> /dev/null; then
        echo "🛑 Stopping Minikube..."
        minikube stop
    else
        echo "⚠️  Minikube not found"
    fi
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "💡 To completely remove Minikube cluster:"
echo "   minikube delete"
