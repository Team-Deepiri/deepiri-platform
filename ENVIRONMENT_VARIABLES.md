# Environment Variables Reference

Complete reference for all environment variables used in Deepiri. This guide covers local development, Docker, and Kubernetes deployments.

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Environment Files Structure](#environment-files-structure)
3. [Local Development Variables](#local-development-variables)
4. [Kubernetes Configuration](#kubernetes-configuration)
5. [Variable Categories](#variable-categories)
6. [Local vs Cloud Variables](#local-vs-cloud-variables)

---

## Quick Reference

### Essential Variables for Local Dev

```bash
# Root .env (Docker Compose)
AI_PROVIDER=localai
LOCALAI_API_BASE=http://localhost:8080/v1
DATABASE_URL=postgresql://deepiri:deepiripassword@localhost:5432/deepiri
REDIS_URL=redis://localhost:6379
DEV_CLIENT_URL=http://localhost:5173
DEV_API_URL=http://localhost:5000/api
DEV_CYREX_URL=http://localhost:8000

# deepiri-core-api/.env
NODE_ENV=development
PORT=5000
DATABASE_URL=postgresql://deepiri:deepiripassword@localhost:5432/deepiri
REDIS_URL=redis://localhost:6379
AI_PROVIDER=localai
LOCALAI_API_BASE=http://localhost:8080/v1
CYREX_URL=http://localhost:8000
DEV_CLIENT_URL=http://localhost:5173
CORS_ORIGIN=http://localhost:5173

# diri-cyrex/.env
AI_PROVIDER=localai
LOCALAI_API_BASE=http://localhost:8080/v1
NODE_BACKEND_URL=http://localhost:5000
VECTOR_STORE=chromadb
CHROMADB_PATH=./chroma_db

# deepiri-web-frontend/.env.local
VITE_API_URL=http://localhost:5000/api
VITE_CYREX_URL=http://localhost:8000
```

---

## Environment Files Structure

```
deepiri/
├── .env                          # Root env (for Docker Compose)
├── env.example                   # Root env template
├── deepiri-core-api/
│   ├── .env                      # Backend env
│   └── env.example.deepiri-core-api    # Backend env template
├── diri-cyrex/
│   ├── .env                      # Python Agent env
│   └── env.example.diri-cyrex # Python Agent env template
└── deepiri-web-frontend/
    ├── .env.local                # Frontend env
    └── env.example.deepiri-web-frontend      # Frontend env template
```

---

## Local Development Variables

### Root `.env` (Docker Compose)

**Server Configuration:**
```bash
NODE_ENV=development
PORT=5000
HOST=0.0.0.0
```

**Database Configuration:**
```bash
DATABASE_URL=postgresql://deepiri:deepiripassword@localhost:5432/deepiri
POSTGRES_USER=deepiri
POSTGRES_PASSWORD=deepiripassword
POSTGRES_DB=deepiri
PGADMIN_EMAIL=admin@deepiri.com
PGADMIN_PASSWORD=admin

REDIS_URL=redis://localhost:6379
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redispassword
```

**AI Configuration:**
```bash
AI_PROVIDER=localai  # localai | openai | deepinfra
LOCALAI_API_BASE=http://localhost:8080/v1
LOCALAI_MODEL=gpt-4o-mini
```

**Development URLs:**
```bash
DEV_CLIENT_URL=http://localhost:5173
DEV_API_URL=http://localhost:5000/api
DEV_CYREX_URL=http://localhost:8000
```

### `deepiri-core-api/.env`

**Server Configuration:**
```bash
NODE_ENV=development
PORT=5000
HOST=0.0.0.0
```

**Database:**
```bash
DATABASE_URL=postgresql://deepiri:deepiripassword@localhost:5432/deepiri
REDIS_URL=redis://localhost:6379
```

**Authentication:**
```bash
JWT_SECRET=your-super-secret-jwt-key-minimum-32-characters-long
JWT_EXPIRES_IN=7d
SESSION_SECRET=your-session-secret-key-here
```

**AI Configuration:**
```bash
AI_PROVIDER=localai
LOCALAI_API_BASE=http://localhost:8080/v1
CYREX_URL=http://localhost:8000
```

**CORS:**
```bash
CORS_ORIGIN=http://localhost:5173
CLIENT_URL=http://localhost:5173
```

### `diri-cyrex/.env`

**Server Configuration:**
```bash
PORT=8000
HOST=0.0.0.0
ENVIRONMENT=development
DEBUG=true
```

**AI Configuration:**
```bash
AI_PROVIDER=localai
LOCALAI_API_BASE=http://localhost:8080/v1
LOCALAI_MODEL=gpt-4o-mini
```

**Backend Communication:**
```bash
NODE_BACKEND_URL=http://localhost:5000
CYREX_API_KEY=change-me
```

**RAG / Embeddings:**
```bash
VECTOR_STORE=chromadb
CHROMADB_PATH=./chroma_db
CHROMADB_COLLECTION=deepiri_embeddings
EMBEDDING_MODEL=all-minilm-l6-v2
```

### `deepiri-web-frontend/.env.local`

```bash
VITE_API_URL=http://localhost:5000/api
VITE_CYREX_URL=http://localhost:8000
```

---

## Kubernetes Configuration

### ConfigMap vs Secrets

**ConfigMaps** (`ops/k8s/configmaps/*.yaml`):
- Non-sensitive configuration
- Ports, feature flags, URLs
- Service names (e.g., `mongodb:27017`)
- Each service has its own configmap file

**Secrets** (`ops/k8s/secrets/secrets.yaml`):
- Sensitive data (passwords, API keys)
- JWT secrets, database passwords
- API keys
- Shared across all services

### Using K8s Config with Docker Compose

**Docker Compose automatically loads environment variables from your k8s configmaps and secrets.**

Configuration files location:
```
ops/k8s/
├── configmaps/
│   ├── api-gateway-configmap.yaml
│   ├── auth-service-configmap.yaml
│   ├── cyrex-configmap.yaml
│   └── ... (one per service)
└── secrets/
    └── secrets.yaml (shared by all services)
```

**To run containers with k8s config:**

```bash
# Use the k8s wrapper script (auto-loads configmaps & secrets)
./docker-compose-k8s.sh -f docker-compose.backend-team.yml up -d    # Linux/Mac
.\docker-compose-k8s.ps1 -f docker-compose.backend-team.yml up -d   # Windows

# Or use team start scripts (already configured)
cd team_dev_environments/backend-team
./start.sh          # Linux/Mac
.\start.ps1         # Windows
```

**How it works:**
1. Wrapper script reads all `ops/k8s/configmaps/*.yaml` files
2. Extracts environment variables from `data:` sections
3. Reads `ops/k8s/secrets/secrets.yaml`
4. Extracts secrets from `stringData:` section
5. Passes all variables to `docker compose`

**Single source of truth:** Edit k8s YAML files → restart containers → done!

### Kubernetes Service Names

In Kubernetes, services communicate using service names:
- `mongodb-service:27017` (not `localhost:27017`)
- `redis-service:6379` (not `localhost:6379`)
- `backend-service:5000` (not `localhost:5000`)
- `cyrex-service:8000` (not `localhost:8000`)
- `localai-service:8080` (not `localhost:8080`)

In Docker Compose, use docker service names:
- `mongodb:27017`
- `redis:6379`
- `api-gateway:5000`
- `cyrex:8000`

---

## Variable Categories

### Required Variables

**For Local Development:**
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `JWT_SECRET` - JWT signing secret
- `AI_PROVIDER` - AI provider (localai/openai/deepinfra)
- `DEV_CLIENT_URL` - Frontend URL
- `DEV_API_URL` - Backend API URL
- `DEV_CYREX_URL` - Python Agent URL

**For Kubernetes:**
- ConfigMap with service names
- Secrets with passwords and API keys

### Optional Variables

**AI Providers:**
- `OPENAI_API_KEY` - Only if using OpenAI
- `DEEPINFRA_API_KEY` - Only if using DeepInfra
- `LOCALAI_API_KEY` - Only if LocalAI requires it

**External Services:**
- `FIREBASE_PROJECT_ID` - Optional, can skip for local dev
- `GOOGLE_MAPS_API_KEY` - Optional
- `FCM_SERVER_KEY` - Optional

**Monitoring:**
- `ENABLE_METRICS` - Optional
- `PROMETHEUS_ENABLED` - Optional

---

## Local vs Cloud Variables

### ⚠️ Critical: PROD_* Variables

**PROD_* variables are ONLY for reference when creating cloud Kubernetes Secrets.**

- ❌ **DO NOT** use `PROD_*` variables in local `.env` files
- ❌ **DO NOT** set production values locally
- ✅ **ONLY** use `PROD_*` as reference when creating cloud K8s Secrets

### Local Development

**Use:**
- `DEV_*` variables (e.g., `DEV_CLIENT_URL`, `DEV_API_URL`)
- `localhost` URLs for all services
- `AI_PROVIDER=localai` for free local AI
- `.env` files for configuration

**Example:**
```bash
DEV_CLIENT_URL=http://localhost:5173
DEV_API_URL=http://localhost:5000/api
DATABASE_URL=postgresql://deepiri:deepiripassword@localhost:5432/deepiri
```

### Cloud/Production

**Use:**
- ConfigMaps for non-sensitive config
- Secrets for sensitive data
- Production URLs (e.g., `https://api.deepiri.com`)
- Service names in Kubernetes

**Example (Kubernetes Secret):**
```yaml
# In cloud K8s Secret (not .env file)
DATABASE_URL: postgresql://user:pass@postgres-cluster.example.com:5432/deepiri_prod
CLIENT_URL: https://deepiri.com
API_URL: https://api.deepiri.com
```

---

## Environment Variable Reference

### Server Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `NODE_ENV` | Environment mode | `development` | Yes |
| `PORT` | Server port | `5000` | Yes |
| `HOST` | Server host | `0.0.0.0` | Yes |

### Database Configuration

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://deepiri:deepiripassword@localhost:5432/deepiri` | Yes |
| `POSTGRES_USER` | PostgreSQL database user | `deepiri` | Yes |
| `POSTGRES_PASSWORD` | PostgreSQL database password | `deepiripassword` | Yes |
| `POSTGRES_DB` | PostgreSQL database name | `deepiri` | Yes |
| `PGADMIN_EMAIL` | pgAdmin admin email | `admin@deepiri.com` | No |
| `PGADMIN_PASSWORD` | pgAdmin admin password | `admin` | No |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` | Yes |
| `REDIS_PASSWORD` | Redis password | `redispassword` | Optional |

### AI Configuration

| Variable | Description | Options | Required |
|----------|-------------|---------|----------|
| `AI_PROVIDER` | AI provider | `localai` \| `openai` \| `deepinfra` | Yes |
| `LOCALAI_API_BASE` | LocalAI API base URL | `http://localhost:8080/v1` | If using LocalAI |
| `OPENAI_API_KEY` | OpenAI API key | `sk-...` | If using OpenAI |
| `OPENAI_API_BASE` | OpenAI API base URL | `https://api.openai.com/v1` | If using OpenAI |
| `OPENAI_MODEL` | OpenAI model name | `gpt-4o-mini` | If using OpenAI |

### Development URLs

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `DEV_CLIENT_URL` | Frontend URL (local) | `http://localhost:5173` | Yes |
| `DEV_API_URL` | Backend API URL (local) | `http://localhost:5000/api` | Yes |
| `DEV_CYREX_URL` | Python Agent URL (local) | `http://localhost:8000` | Yes |

### Authentication

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `JWT_SECRET` | JWT signing secret | `your-secret-key-32-chars-min` | Yes |
| `JWT_EXPIRES_IN` | JWT expiration | `7d` | Yes |
| `SESSION_SECRET` | Session secret | `your-session-secret` | Yes |

### RAG / Embeddings

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `VECTOR_STORE` | Vector store type | `chromadb` | Yes |
| `CHROMADB_PATH` | ChromaDB storage path | `./chroma_db` | If using ChromaDB |
| `EMBEDDING_MODEL` | Embedding model | `all-minilm-l6-v2` | Yes |

---

## Common Configuration Patterns

### Local Development with LocalAI

```bash
# Root .env
AI_PROVIDER=localai
LOCALAI_API_BASE=http://localhost:8080/v1
DATABASE_URL=postgresql://deepiri:deepiripassword@localhost:5432/deepiri
REDIS_URL=redis://localhost:6379
DEV_CLIENT_URL=http://localhost:5173
DEV_API_URL=http://localhost:5000/api
DEV_CYREX_URL=http://localhost:8000
```

### Local Development with OpenAI

```bash
# Root .env
AI_PROVIDER=openai
OPENAI_API_KEY=sk-your-key-here
OPENAI_API_BASE=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini
DATABASE_URL=postgresql://deepiri:deepiripassword@localhost:5432/deepiri
REDIS_URL=redis://localhost:6379
DEV_CLIENT_URL=http://localhost:5173
DEV_API_URL=http://localhost:5000/api
DEV_CYREX_URL=http://localhost:8000
```

### Kubernetes Local Dev

**ConfigMap:**
```yaml
AI_PROVIDER: "localai"
LOCALAI_API_BASE: "http://localai-service:8080/v1"
DATABASE_URL: "postgresql://deepiri:deepiripassword@postgres-service:5432/deepiri"
REDIS_URL: "redis://:password@redis-service:6379"
```

**Secrets:**
```yaml
JWT_SECRET: "your-secret-key"
POSTGRES_PASSWORD: "deepiripassword"
REDIS_PASSWORD: "redispassword"
```

---

## Troubleshooting

### Variable Not Found

- Check `.env` file exists in correct location
- Verify variable name spelling
- Restart service after changing `.env` files

### Wrong Service URLs

- Local dev: Use `localhost` URLs
- Docker: Use service names (e.g., `mongodb:27017`)
- Kubernetes: Use service names (e.g., `mongodb-service:27017`)

### PROD_* Variables in Local Dev

- ❌ Remove `PROD_*` variables from local `.env` files
- ✅ Only use `DEV_*` variables locally
- ✅ `PROD_*` are only for cloud K8s reference

---

**Last Updated:** 2024  
**Maintained by:** Platform Team

