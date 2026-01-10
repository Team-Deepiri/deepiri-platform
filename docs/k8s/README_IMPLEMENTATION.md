# K8s Env Auto-Loading Implementation

## Overview

This implementation automatically loads environment variables from Kubernetes ConfigMaps and Secrets into Docker containers at startup, with **zero host-side scripts required**.

## How It Works

### 1. Core Scripts

- **`load-k8s-env.sh`** - Parses YAML files and exports environment variables
- **`docker-entrypoint.sh`** - Universal entrypoint that loads K8s env then executes CMD

### 2. Dockerfile Integration

All services use the same pattern:

```dockerfile
# Copy K8s env loader scripts
COPY --chown=root:root ops/k8s/load-k8s-env.sh /usr/local/bin/load-k8s-env.sh
COPY --chown=root:root ops/k8s/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/load-k8s-env.sh /usr/local/bin/docker-entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# For services with dumb-init:
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]

# For services without dumb-init:
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 3. Docker Compose Configuration

Mount K8s directories as volumes:

```yaml
services:
  api-gateway:
    volumes:
      - ./ops/k8s/configmaps:/k8s-configmaps:ro
      - ./ops/k8s/secrets:/k8s-secrets:ro
    environment:
      K8S_SERVICE_NAME: api-gateway  # Optional: filter to only this service's configmap
```

## Usage

Just run:
```bash
docker-compose up
```

That's it! Env vars are automatically loaded from mounted YAML files.

## Service-Specific Filtering

Set `K8S_SERVICE_NAME` environment variable to only load that service's configmap:

```yaml
environment:
  K8S_SERVICE_NAME: api-gateway  # Only loads api-gateway-configmap.yaml
```

If not set, all configmaps are loaded (useful for shared services).

## Files

- `load-k8s-env.sh` - Core loader (sourced by entrypoint)
- `docker-entrypoint.sh` - Universal entrypoint
- `generate-env-files.sh` - Optional: Generate .env files for inspection

## Benefits

✅ **Zero host-side scripts** - just `docker-compose up`  
✅ **Single source of truth** - edit k8s YAML, restart container  
✅ **Preserves existing functionality** - dumb-init, user switching, etc.  
✅ **Works with standard Docker tooling**  
✅ **No Python dependencies on host**

