#!/bin/bash
# Wrapper script to run docker-compose with k8s configmaps and secrets
# Usage: ./docker-compose-k8s.sh [compose-file] [command]
# Example: ./docker-compose-k8s.sh docker-compose.backend-team.yml up -d

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/ops/k8s"

# Function to extract env vars from k8s YAML using Python (handles multi-line properly)
load_k8s_env_python() {
    local yaml_file="$1"
    
    if [ ! -f "$yaml_file" ]; then
        return
    fi
    
    # Use Python YAML parser if available (handles multi-line values correctly)
    if command -v python3 &> /dev/null; then
        python3 << EOF
import yaml
import os
import sys

try:
    with open('$yaml_file', 'r') as f:
        config = yaml.safe_load(f)
    
    if not config:
        sys.exit(0)
    
    # Extract from ConfigMap (data section)
    if 'data' in config and isinstance(config['data'], dict):
        for key, value in config['data'].items():
            if value is not None:
                # Handle multi-line strings (preserve newlines)
                if isinstance(value, str) and '\n' in value:
                    # Export with newlines preserved
                    os.system(f"export {key}=$(cat << 'ENVEOF'\n{value}\nENVEOF\n)")
                else:
                    os.environ[key] = str(value)
    
    # Extract from Secret (stringData section)
    if 'stringData' in config and isinstance(config['stringData'], dict):
        for key, value in config['stringData'].items():
            if value is not None:
                # Handle multi-line strings (preserve newlines)
                if isinstance(value, str) and '\n' in value:
                    # Export with newlines preserved
                    os.system(f"export {key}=$(cat << 'ENVEOF'\n{value}\nENVEOF\n)")
                else:
                    os.environ[key] = str(value)
except Exception as e:
    # Fall back to simple extraction if YAML parsing fails
    pass
EOF
    fi
}

# Function to extract env vars from k8s YAML using awk (fallback, simple values only)
load_k8s_env_simple() {
    local yaml_file="$1"
    
    if [ ! -f "$yaml_file" ]; then
        return
    fi
    
    # Simple extraction for single-line values only
    awk '/^(data|stringData):/{flag=1; next} /^[^ ]/{flag=0} flag && /^  [A-Z_]+:/ {
        key = $1
        gsub(/^  /, "", key)
        gsub(/:/, "", key)
        value = substr($0, index($0, $2))
        gsub(/^["'\'']|["'\'']$/, "", value)
        # Skip multi-line indicators
        if (value !~ /^[\|\>]/) {
            print "export " key "=\"" value "\""
        }
    }' "$yaml_file" | while IFS= read -r line; do
        eval "$line"
    done
}

# Load all configmaps
for configmap in "$K8S_DIR"/configmaps/*.yaml; do
    if [ -f "$configmap" ]; then
        load_k8s_env_python "$configmap" || load_k8s_env_simple "$configmap"
    fi
done

# Load all secrets
for secret in "$K8S_DIR"/secrets/*.yaml; do
    if [ -f "$secret" ]; then
        load_k8s_env_python "$secret" || load_k8s_env_simple "$secret"
    fi
done

# Run docker-compose with all arguments passed through
docker-compose "$@"

