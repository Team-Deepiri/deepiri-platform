#!/bin/bash
# Smart Docker Build Script
# Automatically detects dependency changes and prunes stale cache
# Usage: ./smart-build.sh [service-name] [--no-cache] [--force-prune]

set -e

SERVICE=""
NO_CACHE=""
FORCE_PRUNE=""
COMPOSE_FILE="docker-compose.dev.yml"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache|-n)
            NO_CACHE="--no-cache"
            shift
            ;;
        --force-prune|-f)
            FORCE_PRUNE="true"
            shift
            ;;
        --compose-file|-c)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        *)
            if [ -z "$SERVICE" ]; then
                SERVICE="$1"
            fi
            shift
            ;;
    esac
done

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPENDENCY_CACHE_FILE="$REPO_ROOT/.docker-dependency-cache.json"

echo "=========================================="
echo "Smart Docker Build - Dependency-Aware"
echo "=========================================="
echo ""

# Function to calculate file hash
get_file_hash() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "$file_path" | cut -d' ' -f1
        elif command -v shasum >/dev/null 2>&1; then
            shasum -a 256 "$file_path" | cut -d' ' -f1
        else
            echo "ERROR: No hash utility found (sha256sum or shasum)" >&2
            exit 1
        fi
    fi
}

# Function to get dependency files for a service
get_service_dependencies() {
    local service_name="$1"
    
    case "$service_name" in
        cyrex)
            echo "requirements.txt:$REPO_ROOT/diri-cyrex/requirements.txt"
            echo "requirements-core.txt:$REPO_ROOT/diri-cyrex/requirements-core.txt"
            echo "Dockerfile:$REPO_ROOT/diri-cyrex/Dockerfile"
            ;;
        jupyter)
            echo "requirements.txt:$REPO_ROOT/diri-cyrex/requirements.txt"
            echo "Dockerfile.jupyter:$REPO_ROOT/diri-cyrex/Dockerfile.jupyter"
            ;;
        frontend)
            echo "package.json:$REPO_ROOT/deepiri-web-frontend/package.json"
            echo "package-lock.json:$REPO_ROOT/deepiri-web-frontend/package-lock.json"
            echo "Dockerfile:$REPO_ROOT/deepiri-web-frontend/Dockerfile"
            ;;
        core-api)
            echo "package.json:$REPO_ROOT/deepiri-core-api/package.json"
            echo "package-lock.json:$REPO_ROOT/deepiri-core-api/package-lock.json"
            echo "Dockerfile:$REPO_ROOT/deepiri-core-api/Dockerfile"
            ;;
        *)
            # Check common dependency files
            for dep in requirements.txt package.json package-lock.json Dockerfile; do
                local dep_path="$REPO_ROOT/$service_name/$dep"
                if [ -f "$dep_path" ]; then
                    echo "$dep:$dep_path"
                fi
            done
            ;;
    esac
}

# Function to check if dependencies changed
test_dependencies_changed() {
    local service_name="$1"
    local has_changes=false
    
    # Load previous cache
    declare -A previous_cache
    if [ -f "$DEPENDENCY_CACHE_FILE" ]; then
        while IFS='=' read -r key value; do
            if [[ "$key" =~ ^[0-9a-zA-Z_]+$ ]]; then
                previous_cache["$key"]="$value"
            fi
        done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$DEPENDENCY_CACHE_FILE" 2>/dev/null || true)
    fi
    
    # Get current dependencies
    declare -A current_hashes
    while IFS=':' read -r dep_name dep_path; do
        if [ -n "$dep_path" ] && [ -f "$dep_path" ]; then
            local current_hash=$(get_file_hash "$dep_path")
            if [ -n "$current_hash" ]; then
                current_hashes["$dep_name"]="$current_hash"
                local cache_key="${service_name}.${dep_name}"
                
                if [ -n "${previous_cache[$cache_key]:-}" ]; then
                    if [ "${previous_cache[$cache_key]}" != "$current_hash" ]; then
                        echo "  [CHANGE] $dep_name has changed" >&2
                        has_changes=true
                    fi
                else
                    echo "  [NEW] $dep_name (first time tracking)" >&2
                    has_changes=true
                fi
            fi
        fi
    done < <(get_service_dependencies "$service_name")
    
    # Update cache (using jq if available, otherwise simple append)
    if command -v jq >/dev/null 2>&1; then
        # Update JSON cache
        local temp_cache=$(mktemp)
        if [ -f "$DEPENDENCY_CACHE_FILE" ]; then
            cp "$DEPENDENCY_CACHE_FILE" "$temp_cache"
        else
            echo "{}" > "$temp_cache"
        fi
        
        for dep_name in "${!current_hashes[@]}"; do
            local cache_key="${service_name}.${dep_name}"
            jq ". + {\"$cache_key\": \"${current_hashes[$dep_name]}\"}" "$temp_cache" > "${temp_cache}.new"
            mv "${temp_cache}.new" "$temp_cache"
        done
        mv "$temp_cache" "$DEPENDENCY_CACHE_FILE"
    else
        # Fallback: simple text cache
        for dep_name in "${!current_hashes[@]}"; do
            local cache_key="${service_name}.${dep_name}"
            echo "$cache_key=${current_hashes[$dep_name]}" >> "$DEPENDENCY_CACHE_FILE"
        done
    fi
    
    [ "$has_changes" = "true" ]
}

# Function to prune cache for a service
prune_service_cache() {
    local service_name="$1"
    echo "  Pruning build cache for $service_name..."
    docker builder prune -f --filter "type=exec.cachemount" >/dev/null 2>&1 || true
    echo "  [OK] Cache invalidated for $service_name"
}

# Detect services to build
if [ -n "$SERVICE" ]; then
    SERVICES_TO_BUILD=("$SERVICE")
else
    # Try to detect from compose file
    COMPOSE_PATH="$REPO_ROOT/$COMPOSE_FILE"
    if [ -f "$COMPOSE_PATH" ]; then
        # Extract service names (simplified - looks for service: pattern)
        SERVICES_TO_BUILD=($(grep -E '^\s+[a-zA-Z0-9_-]+:' "$COMPOSE_PATH" | \
            grep -v '^[[:space:]]*x-' | \
            sed 's/^[[:space:]]*\([^:]*\):.*/\1/' | \
            grep -v '^$' || true))
    fi
    
    # Fallback to common services
    if [ ${#SERVICES_TO_BUILD[@]} -eq 0 ]; then
        SERVICES_TO_BUILD=(cyrex frontend core-api jupyter)
    fi
fi

echo "Analyzing dependencies..."
echo ""

SERVICES_TO_PRUNE=()

# Check each service for dependency changes
for svc in "${SERVICES_TO_BUILD[@]}"; do
    echo "Checking $svc..."
    
    if [ -n "$FORCE_PRUNE" ] || [ -n "$NO_CACHE" ]; then
        echo "  [FORCE] Pruning cache (--force-prune or --no-cache specified)"
        SERVICES_TO_PRUNE+=("$svc")
    elif test_dependencies_changed "$svc"; then
        echo "  [CHANGED] Dependencies modified, cache will be pruned"
        SERVICES_TO_PRUNE+=("$svc")
    else
        echo "  [OK] No dependency changes detected, using cache"
    fi
    echo ""
done

# Prune cache for services with changes
if [ ${#SERVICES_TO_PRUNE[@]} -gt 0 ]; then
    echo "Pruning build cache for changed services..."
    for svc in "${SERVICES_TO_PRUNE[@]}"; do
        prune_service_cache "$svc"
    done
    echo ""
fi

# Build command
BUILD_CMD="docker compose -f \"$REPO_ROOT/$COMPOSE_FILE\" build"
if [ -n "$SERVICE" ]; then
    BUILD_CMD="$BUILD_CMD $SERVICE"
fi
if [ -n "$NO_CACHE" ]; then
    BUILD_CMD="$BUILD_CMD $NO_CACHE"
    echo "Building with --no-cache (full rebuild)..."
elif [ ${#SERVICES_TO_PRUNE[@]} -gt 0 ]; then
    echo "Building with cache invalidation for changed services..."
else
    echo "Building with cache (no changes detected)..."
fi

echo ""
echo "Executing: $BUILD_CMD"
echo ""

# Execute build
cd "$REPO_ROOT"
eval $BUILD_CMD

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Build completed successfully!"
    echo "=========================================="
    
    if [ ${#SERVICES_TO_PRUNE[@]} -gt 0 ] && [ -z "$NO_CACHE" ]; then
        echo ""
        echo "Summary:"
        echo "  Services with dependency changes: $(IFS=', '; echo "${SERVICES_TO_PRUNE[*]}")"
        echo "  Cache was automatically pruned for these services"
    fi
else
    echo "[ERROR] Build failed" >&2
    exit 1
fi

