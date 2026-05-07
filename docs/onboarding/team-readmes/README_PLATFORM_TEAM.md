# Platform & Infrastructure Team - Deepiri

## Team Overview
The Platform & Infrastructure Team manages deployment pipelines, CI/CD automation, cloud resources, scaling, security policies, and infrastructure as code.

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

## Core Responsibilities

### Platform Engineer Lead
- Internal developer platform
- Tooling and productivity
- Developer experience
- Infrastructure automation

### Platform Engineers
- Infrastructure as Code (IaC)
- Resource provisioning
- Deployment automation
- CI/CD pipelines
- Container orchestration

### Cloud/Infrastructure Engineers
- Cloud resource management
- Networking
- Cost optimization
- Performance monitoring
- Security policies
- Disaster recovery
- High-availability systems

### DevOps Engineer
- CI/CD implementation
- Monitoring and observability
- Cloud infrastructure
- Automation
- Tooling

## Current Infrastructure

### Docker Setup
- `docker-compose.yml` - Production configuration
- `docker-compose.dev.yml` - Development configuration
- Services: MongoDB, Redis, Backend, Python AI, deepiri-web-frontend

### Services
- MongoDB 7.0
- Redis 7.2
- Node.js Backend (Port 5000)
- Python AI Service (Port 8000)
- React deepiri-web-frontend (Port 3000/5173)
- Prometheus (Port 9090)
- Grafana (Port 3001)
- Mongo Express (Port 8081)

## Infrastructure Architecture

### Current Stack
```
┌─────────────────────────────────────┐
│         Load Balancer               │
│      (Nginx / Cloud LB)             │
└──────────────┬──────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼────┐         ┌─────▼───┐
│deepiri-web-frontend│         │ API GW   │
│(React) │         │(Express) │
└────────┘         └─────┬─────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼────┐    ┌──────▼─────┐   ┌─────▼────┐
   │Backend  │    │Python AI   │   │WebSocket │
   │Services │    │Service     │   │Service   │
   └────┬────┘    └────────────┘   └──────────┘
        │
   ┌────┴────┐
   │         │
┌──▼──┐  ┌──▼──┐
│Mongo│  │Redis│
│ DB  │  │Cache│
└─────┘  └─────┘
```

## Deployment

### Docker Compose
```bash
# Development
docker-compose -f docker-compose.dev.yml up

# Production
docker-compose up -d
```

### Environment Variables
- `.env` - Main environment file
- `env.example` - Template
- Service-specific env files

## CI/CD Pipeline

### Pipeline Stages
1. **Build** - Build Docker images
2. **Test** - Run unit and integration tests
3. **Security Scan** - Dependency and container scanning
4. **Deploy Staging** - Deploy to staging environment
5. **E2E Tests** - End-to-end testing
6. **Deploy Production** - Deploy to production

### CI/CD Tools
- GitHub Actions (recommended)
- GitLab CI/CD
- Jenkins (if needed)

## Infrastructure as Code

### Current Setup
- Docker Compose for orchestration
- Dockerfiles for each service

### Recommended Additions
- Terraform for cloud resources
- Kubernetes manifests (if needed)
- Ansible for configuration management

## Cloud Resources

### Cloud Providers
- AWS
- Google Cloud Platform (GCP)
- DigitalOcean

### Resource Management
- Compute instances
- Databases (managed MongoDB/Redis)
- Load balancers
- CDN
- Storage buckets
- Networking (VPC, subnets)

## Monitoring & Observability

### Current Tools
- Prometheus - Metrics collection
- Grafana - Metrics visualization
- Winston - Application logging

### Recommended Additions
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Sentry - Error tracking
- Datadog / New Relic - APM
- CloudWatch / Stackdriver - Cloud monitoring

## Scaling Strategy

### Horizontal Scaling
- Multiple backend instances
- Load balancing
- Database replication
- Redis cluster

### Vertical Scaling
- Resource optimization
- Database indexing
- Caching strategies
- Query optimization

## Security

### Infrastructure Security
- Network segmentation
- Firewall rules
- SSL/TLS certificates
- Secret management
- Access control

### Container Security
- Image scanning
- Least privilege
- Security updates
- Vulnerability patching

## Disaster Recovery

### Backup Strategy
- Database backups (MongoDB)
- Redis persistence
- Configuration backups
- Code repository backups

### Recovery Procedures
- Backup restoration
- Service failover
- Data replication
- Incident response

## Cost Optimization

### Strategies
- Right-sizing instances
- Reserved instances
- Auto-scaling
- Resource cleanup
- Cost monitoring

## Developer Platform

### Internal Tools
- Development environment setup
- Local development scripts
- Testing utilities
- Documentation

### Developer Experience
- Quick onboarding
- Clear documentation
- Easy local setup
- Debugging tools

## Next Steps
1. Set up CI/CD pipeline (GitHub Actions)
2. Implement Infrastructure as Code (Terraform)
3. Set up cloud resources
4. Configure monitoring and alerting
5. Implement auto-scaling
6. Set up backup and disaster recovery
7. Optimize costs
8. Improve developer platform

## Resources
- Docker Documentation
- Docker Compose Documentation
- Kubernetes Documentation
- Terraform Documentation
- Cloud Provider Documentation (AWS/GCP/DO)
- Prometheus Documentation
- Grafana Documentation


