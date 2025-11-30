# Skaffold Configurations Explained

## Overview

You have three main Skaffold configuration files, each serving different purposes:

1. **`skaffold.yaml`** - Regular/default config (Kubernetes deployment)
2. **`skaffold-local.yaml`** - Local development config (includes Docker Compose profile)
3. **`skaffold-prod-cloud.yaml`** - Production/cloud config (pushes to registry)

Plus **7 team-specific configs** for focused development.

---

## 1. `skaffold.yaml` - Regular/Default Config

**Purpose**: Default Skaffold configuration for Kubernetes deployments

**Key Features**:
- Builds images with standard names (e.g., `deepiri-core-api`, `deepiri-cyrex`)
- **Deploys directly to Kubernetes** (Minikube or cloud cluster)
- Uses local Docker daemon (Minikube's daemon via `eval $(minikube docker-env)`)
- Includes file sync for hot-reloading during development
- Has profiles: `dev`, `gpu`, `cpu`, `prod`

**When to Use**:
- When you want to deploy to Kubernetes directly
- For full-stack development with K8s orchestration
- When testing Kubernetes deployments locally

**Usage**:
```bash
# Deploy to Kubernetes
skaffold dev -f skaffold.yaml

# Or with a profile
skaffold dev -f skaffold.yaml -p dev
```

**Image Names**: `deepiri-core-api`, `deepiri-cyrex`, `deepiri-api-gateway`, etc.

---

## 2. `skaffold-local.yaml` - Local Development Config

**Purpose**: Optimized for local development with Docker Compose support

**Key Features**:
- **`dev-compose` profile**: Builds images with Docker Compose naming (`deepiri-dev-*`)
- Builds images but **doesn't deploy to K8s** (when using `dev-compose` profile)
- Includes **jupyter** image (for AI/ML teams)
- All services included for full local development
- Uses local Docker daemon (Minikube's daemon)

**When to Use**:
- **Primary choice for local development**
- When using Docker Compose to run services (faster startup)
- When you need all services including jupyter
- For the hybrid workflow: `skaffold build` → `docker compose up`

**Usage**:
```bash
# Build images for Docker Compose (doesn't deploy to K8s)
skaffold build -f skaffold-local.yaml -p dev-compose

# Then run with Docker Compose
docker compose -f docker-compose.dev.yml up -d
```

**Image Names**: `deepiri-dev-cyrex`, `deepiri-dev-frontend`, `deepiri-dev-api-gateway`, etc.

**Profiles**:
- `dev-compose`: Builds for Docker Compose (no K8s deployment)
- `dev`: Enhanced sync for K8s development
- `gpu`: GPU-enabled builds
- `cpu`: CPU-only builds

---

## 3. `skaffold-prod-cloud.yaml` - Production/Cloud Config

**Purpose**: Production deployments to cloud Kubernetes clusters

**Key Features**:
- **Pushes images to container registry** (e.g., GCR, Docker Hub)
- Supports Google Cloud Build (GCP) or local builds with push
- Deploys to cloud Kubernetes clusters
- Uses standard image names (no `-dev` suffix)
- Can use in-cluster config or kubeconfig

**When to Use**:
- Production deployments
- Staging environment deployments
- CI/CD pipelines
- Cloud Kubernetes clusters (GKE, EKS, AKS)

**Usage**:
```bash
# Build and push to registry, then deploy to cloud
skaffold run -f skaffold-prod-cloud.yaml -p prod

# Or for staging
skaffold run -f skaffold-prod-cloud.yaml -p staging
```

**Image Names**: `deepiri-core-api`, `deepiri-cyrex`, `deepiri-api-gateway`, etc. (pushed to registry)

**Profiles**:
- `prod`: Production deployment with GCP build
- `staging`: Staging deployment
- `gpu`: GPU-enabled builds for cloud

---

## 4. Team-Specific Configs

**Purpose**: Build only the services each team needs (faster builds)

**Available Configs**:
- `skaffold-ai-team.yaml` - AI team (Cyrex, Jupyter, Challenge Service)
- `skaffold-ml-team.yaml` - ML team (Cyrex, Jupyter, Analytics Service)
- `skaffold-backend-team.yaml` - Backend team (all microservices)
- `skaffold-frontend-team.yaml` - Frontend team (frontend + backend services)
- `skaffold-infrastructure-team.yaml` - Infrastructure team (all services)
- `skaffold-qa-team.yaml` - QA team (all services for E2E testing)
- `skaffold-platform-engineers.yaml` - Platform engineers (all services)

**When to Use**:
- When you only need specific services
- To speed up builds (fewer images to build)
- For focused development workflows

**Usage**:
```bash
# Build only your team's services
skaffold build -f skaffold-ai-team.yaml

# Then tag and run with Docker Compose
eval $(minikube docker-env)
./scripts/tag-skaffold-to-latest.sh
docker compose -f docker-compose.dev.yml up -d
```

**Image Names**: `deepiri-dev-*` (same as `dev-compose` profile)

---

## Quick Comparison Table

| Config File | Purpose | Deploys to K8s? | Pushes to Registry? | Image Names | Use Case |
|-------------|---------|-----------------|---------------------|-------------|----------|
| `skaffold.yaml` | Default K8s | ✅ Yes | ❌ No | `deepiri-*` | K8s development |
| `skaffold-local.yaml` | Local dev | ❌ No (dev-compose) | ❌ No | `deepiri-dev-*` | Docker Compose workflow |
| `skaffold-prod-cloud.yaml` | Production | ✅ Yes | ✅ Yes | `deepiri-*` | Cloud deployments |
| `skaffold-*-team.yaml` | Team-specific | ❌ No | ❌ No | `deepiri-dev-*` | Focused development |

---

## Recommended Workflows

### Local Development (Most Common)
```bash
# 1. Build all images
skaffold build -f skaffold-local.yaml -p dev-compose

# 2. Run with Docker Compose
docker compose -f docker-compose.dev.yml up -d
```

### Team-Specific Development
```bash
# 1. Build only your team's services
skaffold build -f skaffold-ai-team.yaml

# 2. Tag images
eval $(minikube docker-env)
./scripts/tag-skaffold-to-latest.sh

# 3. Run with Docker Compose
docker compose -f docker-compose.dev.yml up -d
```

### Kubernetes Development
```bash
# Deploy directly to K8s
skaffold dev -f skaffold.yaml -p dev
```

### Production Deployment
```bash
# Build, push, and deploy to cloud
skaffold run -f skaffold-prod-cloud.yaml -p prod
```

---

## Summary

- **`skaffold.yaml`**: Default, deploys to K8s
- **`skaffold-local.yaml`**: Local dev, includes `dev-compose` profile for Docker Compose
- **`skaffold-prod-cloud.yaml`**: Production, pushes to registry and deploys to cloud
- **Team configs**: Focused builds for specific teams

**For most local development, use `skaffold-local.yaml` with the `dev-compose` profile!**

