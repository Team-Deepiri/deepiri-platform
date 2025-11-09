# Platform Team Onboarding Guide

Welcome to the Deepiri Platform Team! This guide will help you set up infrastructure, CI/CD, and developer tooling.

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
- **MLflow Account** (for model tracking)
- **InfluxDB Account** (for time-series analytics)
- **Pinecone/Weaviate Account** (for vector databases, optional)

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

```bash
# Verify Docker
docker --version
docker-compose --version

# Test Docker
docker run hello-world
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

### 6. MLOps Infrastructure Setup

```bash
cd python_backend/mlops

# Run setup script
bash scripts/setup_mlops_environment.sh

# Or manually
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install mlflow kubernetes prometheus-client

# Start MLflow
mlflow server --host 0.0.0.0 --port 5000

# Start monitoring stack
docker-compose -f docker/docker-compose.mlops.yml up -d
```

**MLOps Services:**
- MLflow: http://localhost:5000
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000

### 7. Time-Series Database Setup (InfluxDB)

```bash
# Using Docker
docker run -d --name influxdb -p 8086:8086 \
  -e INFLUXDB_DB=analytics \
  -e INFLUXDB_ADMIN_USER=admin \
  -e INFLUXDB_ADMIN_PASSWORD=admin \
  influxdb:2.7

# Or install locally
# macOS: brew install influxdb
# Ubuntu: wget https://dl.influxdata.com/influxdb/releases/influxdb2-2.7.0-linux-amd64.tar.gz
```

### 8. Vector Database Setup (Optional)

**Pinecone:**
- Sign up at pinecone.io
- Create index: `deepiri`
- Get API key

**Weaviate:**
```bash
# Using Docker
docker run -d --name weaviate -p 8080:8080 \
  semitechnologies/weaviate:latest
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

### 3. Kubernetes Deployment

```bash
# Apply configs
kubectl apply -f ops/k8s/

# Check status
kubectl get pods
kubectl get services
```

### 4. CI/CD Testing

```bash
# Test GitHub Actions locally (using act)
npm install -g act
act -l
```

## Key Resources

### Documentation

- **Platform Team README:** `README_PLATFORM_TEAM.md`
- **Environment Setup:** `ENVIRONMENT_SETUP.md`
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

