# Platform Team Onboarding Guide

Welcome to the Deepiri Platform Team! This guide will help you set up infrastructure, CI/CD, and developer tooling.

## Quick Reference

### Setup Minikube (for Kubernetes/Skaffold builds)
```bash
# Check if Minikube is running
minikube status

# If not running, start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)
```

### Build
```bash
# Build all services
docker compose -f docker-compose.dev.yml build

# Or use build script
./build.sh              # Linux/Mac/WSL
.\build.ps1             # Windows PowerShell
```

### When you DO need to build / rebuild
Only build if:
1. **Dockerfile changes**
2. **package.json/requirements.txt changes** (dependencies)
3. **First time setup**

**Note:** With hot reload enabled, code changes don't require rebuilds - just restart the service!

### Run all services
```bash
docker compose -f docker-compose.dev.yml up -d
```

### Stop all services
```bash
docker compose -f docker-compose.dev.yml down
```

### Running only services you need for your team
```bash
docker compose -f docker-compose.platform-engineers.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.platform-engineers.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f auth-service
# ... etc for all services
```

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Role-Specific Setup](#role-specific-setup)
4. [Development Workflow](#development-workflow)
5. [Key Resources](#key-resources)

## Prerequisites

### Required Software

- **Docker** and **Docker Compose**
- **Kubernetes CLI** (kubectl)
- **Terraform** (for IaC)
- **Git**
- **VS Code** or your preferred IDE
- **Cloud CLI tools** (AWS CLI, GCP CLI, Azure CLI)

### Required Accounts

- **GitHub Account** (for CI/CD)
- **Cloud Provider Accounts** (AWS/GCP/Azure)
- **Docker Hub** or container registry
- **Monitoring Tools** (Datadog, New Relic, etc.)

### System Requirements

- **RAM:** 16GB+ recommended
- **Storage:** 50GB+ free space
- **OS:** Linux or macOS (Windows with WSL)

## Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd Deepiri/deepiri
```

### 2. Docker Setup

**For WSL2 users (Recommended): Use Docker Engine instead of Docker Desktop**

Docker Engine provides more reliable WSL2 integration and better performance. Use our automated installation script:

```bash
# Run the automated Docker Engine installation script
cd deepiri
./scripts/setup-docker-wsl2.sh

# After the script completes, restart WSL2:
# In Windows PowerShell (as Administrator): wsl --shutdown
# Then restart your WSL2 terminal

# Verify Docker installation
docker --version
docker buildx version
docker-compose --version

# Test Docker
docker ps
docker run hello-world
```

**What the script does:**
- Installs Docker Engine, Buildx, and Compose (official Docker packages)
- Verifies Docker's official GPG key fingerprint (security check)
- Configures WSL2 for systemd (required for Docker service)
- Sets up DNS configuration
- Adds your user to the docker group
- Handles repository errors gracefully

**For macOS/Linux (non-WSL2):**
```bash
# macOS
brew install docker docker-compose

# Linux (Ubuntu/Debian)
# See: https://docs.docker.com/engine/install/ubuntu/
# Or use the manual installation steps in QUICK-START-SCRIPTS.md
```

**Verify Docker is working:**
```bash
docker --version
docker-compose --version
docker ps
```

### 3. Kubernetes Setup (if using)

```bash
# Install kubectl
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Verify
kubectl version --client

# Install Minikube (for local K8s development)
# macOS
brew install minikube

# Linux/WSL2
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install Skaffold (recommended for K8s development)
# macOS
brew install skaffold

# Linux/WSL2
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
chmod +x skaffold
sudo mv skaffold /usr/local/bin/
```

### 4. Terraform Setup (if using)

```bash
# macOS
brew install terraform

# Verify
terraform version
```

### 5. Cloud CLI Setup

```bash
# AWS CLI
pip install awscli
aws configure

# GCP CLI
# Download from cloud.google.com/sdk

# Azure CLI
# Download from docs.microsoft.com/cli/azure
```

## Role-Specific Setup

### Platform Engineer 1 (Lead) (Nahian R)

**Additional Setup:**
```bash
# Install platform tools
npm install -g vercel-cli
npm install -g netlify-cli

# Install GitHub CLI
brew install gh  # macOS
# or download from cli.github.com
```

**First Tasks:**
1. Review existing CI/CD in `.github/workflows/`
2. Set up internal developer platform
3. Create developer portal
4. Improve developer tooling
5. Set up productivity tools

**Key Files:**
- `.github/workflows/` (create CI/CD)
- `platform/` (create directory)
- `scripts/` (review existing)

**CI/CD Example:**
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: npm test
```

---

### Platform Engineer 2 - Infrastructure as Code

**Additional Setup:**
```bash
# Install Terraform
brew install terraform  # macOS
# or download from terraform.io

# Install Ansible (optional)
pip install ansible
```

**First Tasks:**
1. Review `docker-compose.yml`
2. Create Terraform configs
3. Set up Kubernetes configs
4. Automate resource provisioning
5. Create infrastructure templates

**Key Files:**
- `infrastructure/terraform/` (create)
- `infrastructure/kubernetes/` (create)
- `docker-compose.yml` (review)

**Terraform Example:**
```hcl
# infrastructure/terraform/main.tf
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "app" {
  ami           = "ami-12345"
  instance_type = "t3.medium"
}
```

---

### Cloud/Infrastructure Engineer 1 (Lead)

**Additional Setup:**
```bash
# Install cloud CLIs
pip install awscli
pip install google-cloud-sdk
az login  # Azure
```

**First Tasks:**
1. Set up cloud resources
2. Configure networking
3. Plan cost optimization
4. Design cloud architecture
5. Set up resource monitoring

**Key Files:**
- `infrastructure/cloud/` (create)
- `infrastructure/networking/` (create)
- `infrastructure/cost_optimization.md` (create)

---

### Cloud/Infrastructure Engineer 2

**Additional Setup:**
```bash
# Install monitoring tools
pip install prometheus-client
# Install Grafana (via Docker or local)
```

**First Tasks:**
1. Set up Prometheus
2. Configure Grafana dashboards
3. Set up alerting
4. Configure security scanning
5. Monitor resource usage

**Key Files:**
- `infrastructure/monitoring/prometheus.yml` (create)
- `infrastructure/monitoring/grafana/` (create)
- `ops/prometheus/` (review existing)

---

### Cloud/Infrastructure Engineer 3

**Additional Setup:**
```bash
# Install backup tools
# Review existing backup scripts
```

**First Tasks:**
1. Design disaster recovery plan
2. Set up high-availability
3. Create backup strategies
4. Plan failover mechanisms
5. Test recovery procedures

**Key Files:**
- `infrastructure/disaster_recovery/` (create)
- `infrastructure/backup/` (create)
- `scripts/mongo-backup.sh` (review)

---

### DevOps Engineer

**Additional Setup:**
```bash
# Install monitoring tools
npm install -g pm2
pip install ansible

# Install observability tools
```

**First Tasks:**
1. Set up CI/CD pipelines
2. Configure monitoring
3. Set up observability
4. Automate deployments
5. Set up logging

**Key Files:**
- `.github/workflows/` (create)
- `infrastructure/ci_cd/` (create)
- `infrastructure/monitoring/` (create)

## Development Workflow

### 1. Infrastructure Changes

```bash
# Using Terraform
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### 2. Docker Development

```bash
# Build images
docker-compose build

# Start services
docker-compose up -d

# View logs
docker-compose logs -f
```

### 3. Kubernetes Deployment with Skaffold (Recommended)

**Skaffold provides smart rebuilds, file sync, and automatic port-forwarding:**

```bash
# Setup Minikube (first time)
minikube start --driver=docker --cpus=4 --memory=8192
eval $(minikube docker-env)

# Start with Skaffold (handles everything automatically)
skaffold dev --port-forward

# Or use helper scripts
./scripts/setup-minikube-wsl2.sh      # Linux/WSL2
./scripts/start-skaffold-dev.sh        # Linux/WSL2
.\scripts\setup-minikube-wsl2.ps1     # Windows PowerShell
.\scripts\start-skaffold-dev.ps1      # Windows PowerShell
```

**Skaffold automatically:**
- ✅ Builds Docker images using Minikube's Docker daemon
- ✅ Deploys to Kubernetes
- ✅ Auto-syncs files for instant updates (no rebuilds needed)
- ✅ Port-forwards all services automatically
- ✅ Streams logs from all services
- ✅ Cleans up on exit

**Stop Skaffold:**
```bash
# Press Ctrl+C in Skaffold terminal (auto-cleanup)
# Or manually:
./scripts/stop-skaffold.sh        # Linux/Mac
.\scripts\stop-skaffold.ps1       # Windows
```

See [SKAFFOLD_QUICK_START.md](../SKAFFOLD_QUICK_START.md) or [docs/SKAFFOLD_SETUP.md](SKAFFOLD_SETUP.md) for detailed documentation.

### 4. Manual Kubernetes Deployment

```bash
# Apply configs
kubectl apply -f ops/k8s/

# Check status
kubectl get pods
kubectl get services
```

### 5. CI/CD Testing

```bash
# Test GitHub Actions locally (using act)
npm install -g act
act -l
```

## Key Resources

### Documentation

- **Platform Team README:** `README_PLATFORM_TEAM.md`
- **Getting Started:** `GETTING_STARTED.md`
- **Environment Variables:** `ENVIRONMENT_VARIABLES.md`
- **FIND_YOUR_TASKS:** `FIND_YOUR_TASKS.md`

### Important Directories

- `ops/` - Deployment configs
- `infrastructure/` - IaC configs
- `.github/workflows/` - CI/CD
- `scripts/` - Utility scripts

### Communication

- Team channels
- Infrastructure reviews
- Deployment coordination

## Getting Help

1. Check `FIND_YOUR_TASKS.md` for your role
2. Review `README_PLATFORM_TEAM.md`
3. Ask in team channels
4. Contact Platform Engineer Lead (Nahian R)

---

**Welcome to the Platform Team! Let's build robust infrastructure.**


