#!/bin/bash
# Script to generate .env files from Kubernetes ConfigMaps and Secrets
# This allows docker-compose to use the same configuration as Kubernetes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_DIR="$PROJECT_ROOT/.env-k8s"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Syncing K8s ConfigMaps & Secrets → Docker Compose .env   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create .env-k8s directory if it doesn't exist
mkdir -p "$ENV_DIR"

# Function to extract data from ConfigMap YAML
extract_configmap() {
    local configmap_file="$1"
    local output_file="$2"
    
    if [ ! -f "$configmap_file" ]; then
        echo -e "${YELLOW}⚠️  ConfigMap file not found: $configmap_file${NC}"
        return 1
    fi
    
    # Extract data section and convert YAML key-value pairs to KEY=value format
    # This handles both quoted and unquoted values
    awk '/^data:/{flag=1; next} /^[^ ]/{flag=0} flag && /^  [A-Z_]+:/ {
        key = $1
        gsub(/^  /, "", key)
        gsub(/:/, "", key)
        value = substr($0, index($0, $2))
        gsub(/^["'\'']|["'\'']$/, "", value)
        print key "=" value
    }' "$configmap_file" > "$output_file"
}

# Function to extract ALL secrets from the shared secrets.yaml file
extract_shared_secrets() {
    local secret_file="$SCRIPT_DIR/secrets/secrets.yaml"
    local output_file="$1"
    
    if [ ! -f "$secret_file" ]; then
        echo -e "${YELLOW}⚠️  Shared secrets file not found: $secret_file${NC}"
        return 1
    fi
    
    # Extract stringData section and convert YAML key-value pairs to KEY=value format
    # This appends all secrets to every service (they can use what they need)
    awk '/^stringData:/{flag=1; next} /^[^ ]/{flag=0} flag && /^  [A-Z_]+:/ {
        key = $1
        gsub(/^  /, "", key)
        gsub(/:/, "", key)
        value = substr($0, index($0, $2))
        gsub(/^["'\'']|["'\'']$/, "", value)
        print key "=" value
    }' "$secret_file" >> "$output_file"
}

# List of services
SERVICES=(
    "api-gateway"
    "auth-service"
    "task-orchestrator"
    "engagement-service"
    "platform-analytics-service"
    "notification-service"
    "external-bridge-service"
    "challenge-service"
    "realtime-gateway"
    "cyrex"
    "frontend-dev"
)

# Generate .env files for each service
for service in "${SERVICES[@]}"; do
    configmap_file="$SCRIPT_DIR/configmaps/${service}-configmap.yaml"
    env_file="$ENV_DIR/${service}.env"
    
    echo -e "${GREEN}📦 $service${NC}"
    
    # Start with ConfigMap (public vars)
    if [ -f "$configmap_file" ]; then
        extract_configmap "$configmap_file" "$env_file"
        echo -e "   ✓ ConfigMap synced"
    else
        echo -e "   ${YELLOW}⚠️  No ConfigMap found${NC}"
        touch "$env_file"
    fi
    
    # Append shared secrets (all services get all secrets - they use what they need)
    extract_shared_secrets "$env_file"
    echo -e "   ✓ Secrets synced"
    
    # Count variables
    if [ -f "$env_file" ]; then
        var_count=$(grep -c "=" "$env_file" || echo "0")
        echo -e "   ${GREEN}→ $var_count variables${NC}"
    fi
    echo ""
done

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Sync Complete: $ENV_DIR                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}💡 Tip: Run this script whenever you update k8s configmaps/secrets${NC}"
echo -e "${YELLOW}💡 Tip: Add to git hooks for automatic sync${NC}"
echo ""

