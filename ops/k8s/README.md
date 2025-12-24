# Kubernetes ConfigMaps and Secrets for Docker Compose

This directory contains Kubernetes ConfigMaps and Secrets that are used to generate environment variable files for Docker Compose deployments. This ensures consistency between Kubernetes and Docker Compose environments.

## Structure

```
ops/k8s/
├── configmaps/          # Public configuration (non-sensitive)
│   ├── api-gateway-configmap.yaml
│   ├── auth-service-configmap.yaml
│   ├── task-orchestrator-configmap.yaml
│   ├── engagement-service-configmap.yaml
│   ├── platform-analytics-service-configmap.yaml
│   ├── notification-service-configmap.yaml
│   ├── external-bridge-service-configmap.yaml
│   ├── challenge-service-configmap.yaml
│   ├── realtime-gateway-configmap.yaml
│   ├── cyrex-configmap.yaml
│   └── frontend-dev-configmap.yaml
├── secrets/    
## Quick Start

### 1. Update Secret Values

**⚠️ IMPORTANT:** Before using in production, update all Secret YAML files with actual values:

```bash
# Edit secret files with your actual values
vim ops/k8s/secrets/auth-service-secret.yaml
vim ops/k8s/secrets/cyrex-secret.yaml
# ... etc for all services
```

### 2. Generate .env Files

Run the script to generate `.env` files from ConfigMaps and Secrets:

```bash
cd /path/to/deepiri-platform
./ops/k8s/generate-env-files.sh
```

This creates `.env-k8s/` directory with individual `.env` files for each service:
- `.env-k8s/api-gateway.env`
- `.env-k8s/auth-service.env`
- `.env-k8s/cyrex.env`
- ... etc

### 3. Use with Docker Compose

All `docker-compose.*.yml` files are configured to use these `.env` files via `env_file`:

```yaml
services:
  api-gateway:
    env_file:
      - .env-k8s/api-gateway.env
    environment:
      # Docker-specific overrides can be added here
      PORT: 5000
```

## How It Works

### ConfigMaps (Public Configuration)

ConfigMaps contain non-sensitive configuration:
- Server ports
- Service URLs (internal Docker/K8s service names)
- Feature flags
- Public API endpoints

Example:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-gateway-config
data:
  NODE_ENV: "development"
  PORT: "5000"
  AUTH_SERVICE_URL: "http://auth-service:5001"
```

### Secrets (Confidential Configuration)

Secrets contain sensitive data:
- API keys
- Database passwords
- JWT secrets
- OAuth client secrets

Example:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: auth-service-secret
type: Opaque
stringData:
  JWT_SECRET: "your-jwt-secret-key-minimum-32-characters"
  OAUTH_CLIENT_SECRET: "your-oauth-client-secret"
```

### Environment File Generation

The `generate-env-files.sh` script:
1. Extracts `data` section from ConfigMaps
2. Extracts `stringData` section from Secrets
3. Combines them into `.env` files
4. Replaces placeholders with environment variables (if set)

## Service-Specific Configuration

### API Gateway
- **ConfigMap**: Service URLs for all microservices
- **Secret**: (Optional) API keys, JWT secrets

### Auth Service
- **ConfigMap**: MongoDB URI, InfluxDB URL
- **Secret**: JWT_SECRET, OAUTH_CLIENT_SECRET, INFLUXDB_TOKEN

### Task Orchestrator
- **ConfigMap**: MongoDB URI
- **Secret**: (Optional) API keys

### Engagement Service
- **ConfigMap**: PostgreSQL DATABASE_URL, Redis host/port
- **Secret**: REDIS_PASSWORD

### Platform Analytics Service
- **ConfigMap**: MongoDB URI, InfluxDB URL
- **Secret**: INFLUXDB_TOKEN

### Notification Service
- **ConfigMap**: MongoDB URI
- **Secret**: FCM_SERVER_KEY, APNS_KEY_ID, APNS_TEAM_ID

### External Bridge Service
- **ConfigMap**: MongoDB URI
- **Secret**: GITHUB_CLIENT_SECRET, NOTION_CLIENT_SECRET, TRELLO_API_SECRET, webhook secrets

### Challenge Service
- **ConfigMap**: PostgreSQL DATABASE_URL, CYREX_URL
- **Secret**: (Optional) API keys

### Realtime Gateway
- **ConfigMap**: PORT
- **Secret**: (Optional) WebSocket secrets

### Cyrex (Python Agent)
- **ConfigMap**: AI model config, MLflow URI, vector store config
- **Secret**: OPENAI_API_KEY, WANDB_API_KEY, PINECONE_API_KEY, INFLUXDB_TOKEN

### Frontend Dev
- **ConfigMap**: VITE_API_URL, VITE_CYREX_URL
- **Secret**: (Optional) Frontend API keys

## Docker Compose Integration

All `docker-compose.*.yml` files use `env_file` to load environment variables:

```yaml
services:
  api-gateway:
    env_file:
      - .env-k8s/api-gateway.env
    environment:
      # Docker-specific overrides
      PORT: 5000
```

**Benefits:**
- ✅ Single source of truth (K8s ConfigMaps/Secrets)
- ✅ Consistent configuration across environments
- ✅ Easy to update (change K8s files, regenerate .env files)
- ✅ Secrets are version-controlled (with placeholder values)

## Updating Configuration

### For Development

1. Edit the ConfigMap or Secret YAML file
2. Regenerate `.env` files:
   ```bash
   ./ops/k8s/generate-env-files.sh
   ```
3. Restart Docker Compose services:
   ```bash
   docker-compose -f docker-compose.dev.yml restart api-gateway
   ```

### For Production (Kubernetes)

1. Update the ConfigMap or Secret in Kubernetes:
   ```bash
   kubectl apply -f ops/k8s/configmaps/api-gateway-configmap.yaml
   kubectl apply -f ops/k8s/secrets/api-gateway-secret.yaml
   ```
2. Restart the deployment:
   ```bash
   kubectl rollout restart deployment/api-gateway
   ```

## Environment Variable Overrides

You can override values via environment variables before running `generate-env-files.sh`:

```bash
export POSTGRES_USER=deepiri
export POSTGRES_PASSWORD=mypassword
export REDIS_PASSWORD=myredispassword
export API_GATEWAY_PORT=5100
./ops/k8s/generate-env-files.sh
```

The script will replace placeholders in the generated `.env` files.

## Team-Specific Docker Compose Files

All team-specific `docker-compose.*-team.yml` files are configured to use the same `.env-k8s/` files:

- `docker-compose.backend-team.yml`
- `docker-compose.frontend-team.yml`
- `docker-compose.ai-team.yml`
- `docker-compose.ml-team.yml`
- `docker-compose.infrastructure-team.yml`
- `docker-compose.platform-engineers.yml`
- `docker-compose.qa-team.yml`
- `docker-compose.dev.yml` (all services)

## Security Notes

⚠️ **IMPORTANT:**
- Secret YAML files contain placeholder values
- **DO NOT** commit actual secrets to version control
- Use environment variables or secret management tools for production
- Consider using `.gitignore` for generated `.env-k8s/` files if they contain real secrets
- For production Kubernetes, use sealed-secrets or external secret management

## Troubleshooting

### .env files not found

```bash
# Generate .env files first
./ops/k8s/generate-env-files.sh
```

### Environment variables not loading

Check that:
1. `.env-k8s/` directory exists
2. Service-specific `.env` file exists for the service
3. `env_file` is correctly specified in docker-compose.yml

### Values not updating

1. Regenerate `.env` files:
   ```bash
   ./ops/k8s/generate-env-files.sh
   ```
2. Restart the service:
   ```bash
   docker-compose restart <service-name>
   ```

## Adding a New Service

1. Create ConfigMap:
   ```bash
   cp ops/k8s/configmaps/api-gateway-configmap.yaml ops/k8s/configmaps/new-service-configmap.yaml
   # Edit with new service configuration
   ```

2. Create Secret:
   ```bash
   cp ops/k8s/secrets/api-gateway-secret.yaml ops/k8s/secrets/new-service-secret.yaml
   # Edit with new service secrets
   ```

3. Update `generate-env-files.sh`:
   Add the service to the `SERVICES` array

4. Update docker-compose files:
   Add `env_file: - .env-k8s/new-service.env` to the service definition

