# Skaffold Configuration Files

This directory contains all Skaffold configuration files for the Deepiri project.

## Files

### Main Configuration
- **`skaffold.yaml`** - Main Skaffold configuration (production-ready)
- **`skaffold-local.yaml`** - Local development configuration (uses local Docker registry)

### Team-Specific Configurations
- **`skaffold-ai-team.yaml`** - AI Team configuration
- **`skaffold-ml-team.yaml`** - ML Team configuration
- **`skaffold-backend-team.yaml`** - Backend Team configuration
- **`skaffold-frontend-team.yaml`** - Frontend Team configuration
- **`skaffold-infrastructure-team.yaml`** - Infrastructure Team configuration
- **`skaffold-platform-engineers.yaml`** - Platform Engineers configuration
- **`skaffold-qa-team.yaml`** - QA Team configuration

### Production/Cloud
- **`skaffold-prod-cloud.yaml`** - Production cloud deployment configuration

### Logs
- **`skaffold.log`** - Skaffold execution logs

## Usage

### Local Development

```bash
# Build with local config
skaffold build -f skaffold/skaffold-local.yaml -p dev-compose

# Run in dev mode
skaffold dev -f skaffold/skaffold-local.yaml --port-forward
```

### Team-Specific Builds

```bash
# AI Team
skaffold build -f skaffold/skaffold-ai-team.yaml

# Backend Team
skaffold build -f skaffold/skaffold-backend-team.yaml

# Frontend Team
skaffold build -f skaffold/skaffold-frontend-team.yaml
```

### Production

```bash
# Production cloud deployment
skaffold build -f skaffold/skaffold-prod-cloud.yaml
```

## Notes

- All Skaffold files have been moved to this `skaffold/` directory for better organization
- Scripts and documentation have been updated to reference the new paths
- When running Skaffold commands, always specify the full path: `skaffold/skaffold-*.yaml`

