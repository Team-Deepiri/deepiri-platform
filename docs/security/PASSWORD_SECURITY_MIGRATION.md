# Password Security Migration Guide

## Overview

The Deepiri platform now enforces strong password requirements for production deployments. Development environments remain unchanged with convenient defaults.

## Breaking Changes

**Production only.** Development environments (`docker-compose.dev.yml`) are not affected.

- `docker-compose.yml` now requires all passwords via environment variables (no defaults)
- Cyrex Pydantic settings validate password strength in production
- Python modules no longer fall back to hardcoded passwords

## Migration Steps

### Step 1: Generate Secure Passwords

```bash
# Generate all required passwords at once
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)"
echo "MONGO_ROOT_USER=deepiri_admin"
echo "MONGO_ROOT_PASSWORD=$(openssl rand -base64 32)"
echo "REDIS_PASSWORD=$(openssl rand -base64 32)"
echo "MINIO_ROOT_USER=$(openssl rand -base64 16)"
echo "MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)"
echo "INFLUXDB_PASSWORD=$(openssl rand -base64 32)"
echo "INFLUXDB_TOKEN=$(openssl rand -base64 48)"
echo "JWT_SECRET=$(openssl rand -base64 48)"
echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 24)"
```

### Step 2: Create .env File

```bash
cp .env.example .env
# Edit .env with the generated passwords
```

### Step 3: Secure the .env File

```bash
chmod 600 .env
```

### Step 4: Update Kubernetes Secrets (if applicable)

Update your K8s secrets with the new passwords. See `ops/k8s/secrets/`.

### Step 5: Update Existing Databases

If migrating a running deployment, update passwords in the actual databases:

```sql
-- PostgreSQL
ALTER USER deepiri WITH PASSWORD 'new-password-here';

-- MongoDB (via mongosh)
db.changeUserPassword("admin", "new-password-here")
```

```bash
# Redis
redis-cli CONFIG SET requirepass "new-password-here"
```

### Step 6: Test the Migration

```bash
# Verify all services start
docker compose up -d
docker compose ps
docker compose logs | grep -i error
```

### Step 7: Rollback Plan

```bash
# If something goes wrong:
docker compose down
git checkout HEAD~1 -- docker-compose.yml diri-cyrex/app/settings.py
cp .env.backup .env  # if you backed up
docker compose up -d
```

## Verification Checklist

- [ ] `.env` file created with strong passwords
- [ ] `.env` file permissions set to 600
- [ ] All services start without errors
- [ ] Health checks pass for all services
- [ ] No default passwords in logs

## Development Environment

No changes needed. `docker-compose.dev.yml` continues to use hardcoded defaults for convenience.

## Troubleshooting

### "ERROR: VARIABLE must be set in .env file"
Create a `.env` file from `.env.example` and fill in all required values.

### Pydantic validation error on startup
Check that your passwords meet production requirements:
- At least 12 characters
- Contains uppercase, lowercase, digits, and special characters
- Not a known weak password

### Services can't connect after password change
Ensure all services reference the same password. Delete old volumes if needed:
```bash
docker compose down -v  # WARNING: deletes data
docker compose up -d
```
