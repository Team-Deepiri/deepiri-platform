#!/bin/bash
# Load K8s ConfigMaps and Secrets from mounted YAML files
# This script is sourced by service entrypoints to load environment variables
# Usage: source /usr/local/bin/load-k8s-env.sh

# Default paths (can be overridden via env vars)
K8S_CONFIGMAPS_DIR="${K8S_CONFIGMAPS_DIR:-/k8s-configmaps}"
K8S_SECRETS_DIR="${K8S_SECRETS_DIR:-/k8s-secrets}"

# Function to parse YAML and export env vars
load_k8s_yaml() {
    local yaml_file="$1"
    
    if [ ! -f "$yaml_file" ]; then
        return 0
    fi
    
    # Extract from data: section (ConfigMaps)
    if grep -q "^data:" "$yaml_file" 2>/dev/null; then
        awk '/^data:/{flag=1; next} /^[^ ]/{flag=0} flag && /^  [A-Z_][A-Z0-9_]*:/ {
            key = $1
            gsub(/^  /, "", key)
            gsub(/:/, "", key)
            value = substr($0, index($0, $2))
            gsub(/^["'\'']|["'\'']$/, "", value)
            # Handle multi-line values (for secrets with newlines)
            if (value ~ /^[|>]/) {
                getline
                value = ""
                while (getline > 0 && /^    /) {
                    value = value substr($0, 5) "\n"
                }
            }
            print "export " key "=\"" value "\""
        }' "$yaml_file" | while IFS= read -r line || [ -n "$line" ]; do
            [ -n "$line" ] && eval "$line" 2>/dev/null || true
        done
    fi
    
    # Extract from stringData: section (Secrets)
    if grep -q "^stringData:" "$yaml_file" 2>/dev/null; then
        awk '/^stringData:/{flag=1; next} /^[^ ]/{flag=0} flag && /^  [A-Z_][A-Z0-9_]*:/ {
            key = $1
            gsub(/^  /, "", key)
            gsub(/:/, "", key)
            value = substr($0, index($0, $2))
            gsub(/^["'\'']|["'\'']$/, "", value)
            # Handle multi-line values
            if (value ~ /^[|>]/) {
                getline
                value = ""
                while (getline > 0 && /^    /) {
                    value = value substr($0, 5) "\n"
                }
            }
            print "export " key "=\"" value "\""
        }' "$yaml_file" | while IFS= read -r line || [ -n "$line" ]; do
            [ -n "$line" ] && eval "$line" 2>/dev/null || true
        done
    fi
}

# Load all ConfigMaps
if [ -d "$K8S_CONFIGMAPS_DIR" ]; then
    # If K8S_SERVICE_NAME is set, only load matching configmap
    if [ -n "$K8S_SERVICE_NAME" ]; then
        configmap_file="$K8S_CONFIGMAPS_DIR/${K8S_SERVICE_NAME}-configmap.yaml"
        if [ -f "$configmap_file" ]; then
            load_k8s_yaml "$configmap_file"
        fi
    else
        # Load all configmaps
        for configmap in "$K8S_CONFIGMAPS_DIR"/*.yaml; do
            [ -f "$configmap" ] && load_k8s_yaml "$configmap"
        done
    fi
fi

# Load all Secrets
if [ -d "$K8S_SECRETS_DIR" ]; then
    for secret in "$K8S_SECRETS_DIR"/*.yaml; do
        [ -f "$secret" ] && load_k8s_yaml "$secret"
    done
fi

