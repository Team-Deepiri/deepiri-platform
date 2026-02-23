# Deepiri Documentation

Welcome to the Deepiri documentation! This directory contains comprehensive guides for setting up, developing, and troubleshooting the Deepiri platform.

## 📚 Documentation Structure

### 🚀 [Getting Started](./getting-started/)

Complete setup guides and onboarding documentation for new team members.

- **[Environment Setup](./getting-started/ENVIRONMENT_SETUP.md)** - Complete setup guide for new team members
  - Prerequisites
  - Initial setup steps
  - Running services
  - Development workflow
- **[Environment Variables](./getting-started/ENVIRONMENT_VARIABLES.md)** - Complete environment variable reference
- **[Getting Started](./getting-started/GETTING_STARTED.md)** - Local development setup
- **[Start Everything](./getting-started/START_EVERYTHING.md)** - Complete testing guide

### 👥 [Team Onboarding](./onboarding/)

Team-specific onboarding guides and documentation.

- **[AI Team Onboarding](./onboarding/AI_TEAM_ONBOARDING.md)** - AI team specific setup and guides
- **[Backend Team Onboarding](./onboarding/BACKEND_TEAM_ONBOARDING.md)** - Backend team specific setup
- **[Frontend Team Onboarding](./onboarding/FRONTEND_TEAM_ONBOARDING.md)** - Frontend team specific setup
- **[MLOps Team Onboarding](./onboarding/MLOPS_TEAM_ONBOARDING.md)** - MLOps team specific setup
- **[Platform Team Onboarding](./onboarding/PLATFORM_TEAM_ONBOARDING.md)** - Platform team specific setup
- **[Security QA Team Onboarding](./onboarding/SECURITY_QA_TEAM_ONBOARDING.md)** - Security and QA team setup

### 🏗️ [Architecture](./architecture/)

System architecture, design patterns, and technical documentation.

- **[Shared Utils Architecture](./architecture/SHARED_UTILS_ARCHITECTURE.md)** - Architecture documentation
  - Shared utilities structure
  - Monorepo setup
  - Long-term solutions
  - Migration plans
- **[AI Services Overview](./architecture/AI_SERVICES_OVERVIEW.md)** - AI services architecture
- **[Microservices Architecture](./architecture/MICROSERVICES_ARCHITECTURE.md)** - Microservices design patterns
- **[System Architecture](./architecture/SYSTEM_ARCHITECTURE.md)** - Overall system design

### ⚙️ [Development](./development/)

Development guides, API documentation, and technical deep-dives.

- **[API Logging & Audit](./development/API_REQUEST_RESPONSE_LOGGING_AUDIT_TRAILS.md)** - API logging and audit trails
- **[Database Indexing](./development/DATABASE_INDEXING.md)** - Database optimization
- **[Document Import Guide](./development/DOCUMENT_IMPORT_COMPLETE_GUIDE.md)** - Document import system
- **[Streaming Implementation](./development/STREAMING_IMPLEMENTATION_COMPLETE.md)** - Streaming features
- **[Makefile Explanation](./development/MAKEFILE-EXPLANATION.md)** - Build system documentation

### 🛠️ [Operations](./operations/)

Build, deployment, infrastructure, and operational documentation.

- **[Infrastructure Setup](./operations/INFRASTRUCTURE_SETUP.md)** - Infrastructure configuration
- **[Production Build](./operations/PRODUCTION_BUILD.md)** - Production deployment
- **[Docker Management](./operations/DOCKER_LOG_MANAGEMENT.md)** - Docker operations
- **[Backend Migration](./operations/BACKEND_POSTGRESQL_MIGRATION.md)** - Database migration guides

### 🔒 [Security](./security/)

Security guidelines, best practices, and compliance documentation.

- **[Password Storage](./security/ASED_PASSWORD_STORAGE_WALKTHROUGH.md)** - Secure password handling
- **[Code Security](./security/CODE_SECURITY_ENHANCEMENTS.md)** - Code security practices
- **[Cloud Security](./security/CLOUD_SECURITY_INTERN.md)** - Cloud security guidelines

### 🐛 [Troubleshooting](./troubleshooting/)

Comprehensive troubleshooting guides and solutions.

- **[Troubleshooting Guide](./troubleshooting/TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide
  - Common issues and solutions
  - Service-specific problems
  - Quick diagnostic commands
  - Prevention tips
- **[Port Conflict Prevention](./troubleshooting/PORT_CONFLICT_PREVENTION.md)** - Port conflict solutions
- **[Quick Fix Guides](./troubleshooting/QUICK_FIX.md)** - Quick resolution guides

### 📋 [Features](./features/)

Feature documentation, product checklists, and UI components.

- **[Product Checklist](./features/PRODUCT_CHECKLIST.md)** - Product feature overview
- **[UI Components](./features/UI_COMPONENTS_PLAN.md)** - UI component documentation
- **[User Features](./features/USER_FEATURE_PLAN.md)** - User-facing features

### 🚀 [Kubernetes](./k8s/)

Kubernetes deployment and management documentation.

- **[Kubernetes Implementation](./k8s/README_IMPLEMENTATION.md)** - K8s deployment guide
- **[Simplified Approach](./k8s/SIMPLIFIED_APPROACH.md)** - Simplified K8s setup

### 📦 [Archive](./archive/)

Historical documentation and legacy guides.

- **[Build Legacy](./archive/build-legacy/)** - Legacy build documentation
- **[Skaffold](./archive/skaffold/)** - Skaffold configuration guides

## 🗺️ Quick Navigation

### For New Team Members

1. Start with [Environment Setup](./getting-started/ENVIRONMENT_SETUP.md)
2. Check your [Team Onboarding](./onboarding/) guide
3. Review [Architecture](./architecture/) overview
4. Explore [Troubleshooting](./troubleshooting/) guides

### For Developers

1. Check [Development](./development/) guides for API and features
2. Review [Architecture](./architecture/) for system understanding
3. Use [Operations](./operations/) for deployment
4. Refer to [Troubleshooting](./troubleshooting/) for issues

### For DevOps/Platform Engineers

1. Review [Infrastructure](./operations/INFRASTRUCTURE_SETUP.md) setup
2. Check [Kubernetes](./k8s/) deployment guides
3. Use [Operations](./operations/) for production deployment
4. Refer to [Troubleshooting](./troubleshooting/) for operational issues

## 📝 Common Tasks

### First Time Setup

```bash
# 1. Install dependencies
bash scripts/fix-dependencies.sh

# 2. Start services
docker-compose -f docker-compose.dev.yml up -d

# 3. Verify services
curl http://localhost:5000/health
```

### Troubleshooting

```bash
# Check service status
docker-compose -f docker-compose.dev.yml ps

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Fix dependencies
bash scripts/fix-dependencies.sh
```

## 🔄 Documentation Updates

This documentation is actively maintained. To contribute:

1. Check existing documentation for similar content
2. Update relevant sections with new information
3. Ensure cross-references are maintained
4. Test any commands or procedures documented

## 📞 Support

- **Development Issues**: Check [Troubleshooting](./troubleshooting/)
- **Environment Problems**: See [Environment Setup](./getting-started/ENVIRONMENT_SETUP.md)
- **Team-Specific**: Refer to your [Team Onboarding](./onboarding/) guide
- **Architecture Questions**: Review [Architecture](./architecture/) documentation

---

**Last Updated**: February 2026  
**Maintained By**: Deepiri Platform Team
