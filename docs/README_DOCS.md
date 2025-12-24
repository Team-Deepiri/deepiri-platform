# Deepiri Documentation

Welcome to the Deepiri documentation! This directory contains comprehensive guides for setting up, developing, and troubleshooting the Deepiri platform.

## Documentation Index

### Getting Started
- **[../ENVIRONMENT_SETUP.md](../ENVIRONMENT_SETUP.md)** - Complete setup guide for new team members
  - Prerequisites
  - Initial setup steps
  - Running services
  - Development workflow
- **[../ENVIRONMENT_VARIABLES.md](../ENVIRONMENT_VARIABLES.md)** - Complete environment variable reference

### Troubleshooting
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide
  - Common issues and solutions
  - Service-specific problems
  - Quick diagnostic commands
  - Prevention tips

### Architecture
- **[SHARED_UTILS_ARCHITECTURE.md](SHARED_UTILS_ARCHITECTURE.md)** - Architecture documentation
  - Shared utilities structure
  - Monorepo setup
  - Long-term solutions
  - Migration plans

### Onboarding
- **[ISSUES_FIXED.md](ISSUES_FIXED.md)** - Summary of all fixes for team onboarding
  - All issues resolved
  - Verification checklist
  - Maintenance notes

## Quick Start

1. **New to the project?** Start with [ENVIRONMENT_SETUP.md](../ENVIRONMENT_SETUP.md)
2. **Need environment variables?** Check [ENVIRONMENT_VARIABLES.md](../ENVIRONMENT_VARIABLES.md)
3. **Encountering issues?** Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
4. **Want to understand architecture?** Read [SHARED_UTILS_ARCHITECTURE.md](SHARED_UTILS_ARCHITECTURE.md)

## Common Tasks

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

## Related Documentation

- **[../ENVIRONMENT_SETUP.md](../ENVIRONMENT_SETUP.md)** - Complete setup guide
- **[../ENVIRONMENT_VARIABLES.md](../ENVIRONMENT_VARIABLES.md)** - Environment variables reference
- **[../START_EVERYTHING.md](../START_EVERYTHING.md)** - Complete testing guide
- **[../GETTING_STARTED.md](../GETTING_STARTED.md)** - Local development setup

