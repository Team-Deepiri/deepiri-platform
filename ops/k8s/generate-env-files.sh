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

echo -e "${GREEN}Generating .env files from Kubernetes ConfigMaps and Secrets...${NC}"

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

# Function to extract data from Secret YAML
extract_secret() {
    local secret_file="$1"
    local output_file="$2"
    
    if [ ! -f "$secret_file" ]; then
        echo -e "${YELLOW}⚠️  Secret file not found: $secret_file${NC}"
        return 1
    fi
    
    # Extract stringData section and convert YAML key-value pairs to KEY=value format
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
    secret_file="$SCRIPT_DIR/secrets/${service}-secret.yaml"
    env_file="$ENV_DIR/${service}.env"
    
    echo -e "Processing ${GREEN}$service${NC}..."
    
    # Start with ConfigMap (public vars)
    if [ -f "$configmap_file" ]; then
        extract_configmap "$configmap_file" "$env_file"
        echo -e "  ✓ Added ConfigMap values"
    else
        echo -e "  ${YELLOW}⚠️  No ConfigMap found${NC}"
        touch "$env_file"
    fi
    
    # Append Secret (confidential vars)
    if [ -f "$secret_file" ]; then
        extract_secret "$secret_file" "$env_file"
        echo -e "  ✓ Added Secret values"
    else
        echo -e "  ${YELLOW}⚠️  No Secret found${NC}"
    fi
    
    # Replace placeholders with actual values from environment or defaults
    # This allows overriding values via environment variables
    if [ -f "$env_file" ]; then
        # Replace MongoDB credentials if MONGO_ROOT_USER and MONGO_ROOT_PASSWORD are set
        if [ -n "$MONGO_ROOT_USER" ] && [ -n "$MONGO_ROOT_PASSWORD" ]; then
            sed -i.bak "s|mongodb://admin:password@|mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@|g" "$env_file"
            rm -f "${env_file}.bak"
        fi
        
        # Replace Redis password if REDIS_PASSWORD is set
        if [ -n "$REDIS_PASSWORD" ]; then
            sed -i.bak "s|REDIS_PASSWORD=redispassword|REDIS_PASSWORD=${REDIS_PASSWORD}|g" "$env_file"
            rm -f "${env_file}.bak"
        fi
        
        # Replace API Gateway port if API_GATEWAY_PORT is set
        if [ -n "$API_GATEWAY_PORT" ]; then
            sed -i.bak "s|VITE_API_URL=http://localhost:5100|VITE_API_URL=http://localhost:${API_GATEWAY_PORT}|g" "$env_file"
            rm -f "${env_file}.bak"
        fi
    fi
done

echo -e "\n${GREEN}✓ Generated .env files in: $ENV_DIR${NC}"
echo -e "${YELLOW}Note: Update the Secret YAML files with actual values before using in production!${NC}"

