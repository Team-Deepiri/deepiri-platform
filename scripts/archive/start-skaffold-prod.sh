#!/bin/bash
# Start Deepiri production deployment with Skaffold
# This script deploys to cloud/production Kubernetes clusters

set -e

echo "🚀 Starting Deepiri Production Deployment with Skaffold..."

# Parse command line arguments
PROFILE="prod"
NAMESPACE="default"
PORT_FORWARD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --port-forward)
            PORT_FORWARD=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --profile PROFILE     Skaffold profile to use (prod, staging, gpu) [default: prod]"
            echo "  --namespace NAMESPACE Kubernetes namespace [default: default]"
            echo "  --port-forward        Enable port forwarding"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Deploy to production"
            echo "  $0 --profile staging                  # Deploy to staging"
            echo "  $0 --profile prod --port-forward       # Deploy with port forwarding"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if skaffold is installed
if ! command -v skaffold &> /dev/null; then
    echo "❌ Skaffold is not installed. Please install it first."
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "skaffold-cloud.yaml" ] && [ ! -f "skaffold.yaml" ]; then
    echo "❌ skaffold-cloud.yaml or skaffold.yaml not found. Please run this script from the project root."
    exit 1
fi

# Check if k8s manifests exist
if [ ! -d "ops/k8s" ]; then
    echo "❌ Kubernetes manifests not found in ops/k8s/"
    exit 1
fi

# Check kubectl connection
echo "🔧 Checking Kubernetes connection..."
if command -v kubectl &> /dev/null; then
    # Check if KUBECONFIG is set (for CI/CD) or if we're in-cluster
    if [ -n "$KUBECONFIG" ]; then
        echo "✅ Using kubeconfig: $KUBECONFIG"
        if [ ! -f "$KUBECONFIG" ]; then
            echo "⚠️  Warning: KUBECONFIG file not found at $KUBECONFIG"
        fi
    else
        echo "ℹ️  KUBECONFIG not set - will try in-cluster config (if running in a pod)"
        echo "   For local/CI deployments, set KUBECONFIG environment variable"
    fi
    
    # Try to get cluster info
    if kubectl cluster-info &> /dev/null; then
        CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "in-cluster")
        echo "✅ Connected to Kubernetes cluster: $CURRENT_CONTEXT"
    else
        echo "⚠️  Warning: Cannot connect to Kubernetes cluster"
        echo "   Make sure KUBECONFIG is set or you're running in a Kubernetes pod"
    fi
else
    echo "⚠️  Warning: kubectl is not installed. Skaffold may have issues connecting to Kubernetes."
fi

# Use skaffold-cloud.yaml for production deployments
CONFIG_FILE="skaffold-cloud.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  Warning: $CONFIG_FILE not found, falling back to skaffold.yaml"
    CONFIG_FILE="skaffold.yaml"
fi

echo ""
echo "✅ Environment ready. Starting Skaffold (PRODUCTION mode)..."
echo ""
echo "📋 Deployment Configuration:"
echo "   - Config file: $CONFIG_FILE"
echo "   - Profile: $PROFILE"
echo "   - Namespace: $NAMESPACE"
echo "   - Port forwarding: $PORT_FORWARD"
echo ""
echo "📋 Skaffold will:"
echo "   - Build Docker images"
echo "   - Push images to container registry"
echo "   - Deploy to Kubernetes cluster"
if [ "$PORT_FORWARD" = true ]; then
    echo "   - Port-forward services"
fi
echo ""

# Confirm before proceeding (unless in CI/CD)
if [ -z "$CI" ] && [ -z "$SKIP_CONFIRM" ]; then
    read -p "Continue with production deployment? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled"
        exit 0
    fi
fi

# Build Skaffold command
SKAFFOLD_CMD="skaffold run -f $CONFIG_FILE --profile=$PROFILE"

if [ "$PORT_FORWARD" = true ]; then
    SKAFFOLD_CMD="$SKAFFOLD_CMD --port-forward"
fi

# Execute Skaffold
echo "🚀 Starting deployment..."
eval $SKAFFOLD_CMD

echo ""
echo "✅ Deployment complete!"
echo ""
echo "💡 Useful commands:"
echo "   - View pods: kubectl get pods -n $NAMESPACE"
echo "   - View services: kubectl get services -n $NAMESPACE"
echo "   - View logs: kubectl logs -f deployment/<deployment-name> -n $NAMESPACE"
echo "   - Delete deployment: skaffold delete -f $CONFIG_FILE --profile=$PROFILE"
echo ""

