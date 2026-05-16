#!/bin/bash
# Load K8s ConfigMaps and Secrets from mounted YAML files
# This script is sourced by service entrypoints to load environment variables
# Usage: source /usr/local/bin/load-k8s-env.sh

# Default paths (can be overridden via env vars)
K8S_CONFIGMAPS_DIR="${K8S_CONFIGMAPS_DIR:-/k8s-configmaps}"
K8S_SECRETS_DIR="${K8S_SECRETS_DIR:-/k8s-secrets}"

# Parse a YAML section (data: or stringData:) and export vars into the current shell.
# Uses eval on awk output directly — avoids the pipe-subshell trap where exports
# inside `cmd | while read` never propagate back to the caller.
_load_yaml_section() {
    local yaml_file="$1"
    local section="$2"  # "data" or "stringData"

    eval "$(awk -v section="${section}:" '
        $0 == section     { flag=1; next }
        /^[^ ]/           { flag=0 }
        flag && /^  [A-Z_][A-Z0-9_]*:/ {
            key = $1
            gsub(/:$/, "", key)
            value = substr($0, index($0, $2))
            gsub(/^["\047]|["\047]$/, "", value)
            if (value ~ /^[|>]/) {
                getline; value = ""
                while (getline > 0 && /^    /) { value = value substr($0,5) "\n" }
            }
            print "[ -z \"$" key "\" ] && export " key "=\"" value "\""
        }
    ' "$yaml_file" 2>/dev/null)"
}

load_k8s_yaml() {
    local yaml_file="$1"
    [ -f "$yaml_file" ] || return 0
    grep -q "^data:"       "$yaml_file" 2>/dev/null && _load_yaml_section "$yaml_file" "data"
    grep -q "^stringData:" "$yaml_file" 2>/dev/null && _load_yaml_section "$yaml_file" "stringData"
}

# Load all ConfigMaps
if [ -d "$K8S_CONFIGMAPS_DIR" ]; then
    if [ -n "$K8S_SERVICE_NAME" ]; then
        configmap_file="$K8S_CONFIGMAPS_DIR/${K8S_SERVICE_NAME}-configmap.yaml"
        [ -f "$configmap_file" ] && load_k8s_yaml "$configmap_file"
    else
        for configmap in "$K8S_CONFIGMAPS_DIR"/*.yaml; do
            [ -f "$configmap" ] && load_k8s_yaml "$configmap"
        done
    fi
fi

# Load all Secrets — always load all files so shared secrets (JWT, Redis) are available
if [ -d "$K8S_SECRETS_DIR" ]; then
    for secret in "$K8S_SECRETS_DIR"/*.yaml; do
        [ -f "$secret" ] && load_k8s_yaml "$secret"
    done
fi
