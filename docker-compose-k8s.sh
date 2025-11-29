#!/bin/bash
# Wrapper script to run docker-compose with k8s configmaps and secrets
# Usage: ./docker-compose-k8s.sh [compose-file] [command]
# Example: ./docker-compose-k8s.sh docker-compose.backend-team.yml up -d

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/ops/k8s"

# Function to extract env vars from k8s YAML and export them
load_k8s_env() {
    local yaml_file="$1"
    
    if [ ! -f "$yaml_file" ]; then
        return
    fi
    
    # Extract data: or stringData: sections and export as env vars
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]{2}([A-Z_]+):[[:space:]]*\"?(.+?)\"?[[:space:]]*$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            value="${value%\"}"
            value="${value#\"}"
            export "$key=$value"
        fi
    done < <(awk '/^(data|stringData):/{flag=1; next} /^[^ ]/{flag=0} flag' "$yaml_file")
}

# Load all configmaps
for configmap in "$K8S_DIR"/configmaps/*.yaml; do
    [ -f "$configmap" ] && load_k8s_env "$configmap"
done

# Load all secrets
for secret in "$K8S_DIR"/secrets/*.yaml; do
    [ -f "$secret" ] && load_k8s_env "$secret"
done

# Run docker-compose with all arguments passed through
docker-compose "$@"

