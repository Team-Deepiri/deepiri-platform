# Kubernetes Secrets

⚠️ **IMPORTANT: Never commit actual secrets to git!**

## Setup

1. **Copy the example file:**
   ```bash
   cp secrets.yaml.example secrets.yaml
   ```

2. **Edit `secrets.yaml` with your actual values:**
   ```bash
   # Use your preferred editor
   vim secrets.yaml
   # or
   code secrets.yaml
   ```

3. **The actual `secrets.yaml` file is gitignored** - it won't be committed.

## File Structure

- `secrets.yaml.example` - Template file (committed to git)
- `secrets.yaml` - Your actual secrets (gitignored, never committed)
- `README.md` - This file (committed to git)

## For Docker Compose

The `docker-compose-k8s.sh` and `docker-compose-k8s.ps1` wrapper scripts automatically load variables from `secrets.yaml` when running your containers.

**No manual .env file creation needed!**

## For Kubernetes

Apply the secrets to your cluster:

```bash
kubectl apply -f secrets.yaml
```

## Development vs Production

**Development (local):**
- Use placeholder values in `secrets.yaml`
- Default passwords are fine (e.g., `password`, `redispassword`)
- Optional API keys can be left empty

**Production:**
- ⚠️ **NEVER commit production secrets to git**
- Use strong passwords/keys
- Store production secrets in your cloud provider's secret manager:
  - AWS Secrets Manager
  - Azure Key Vault
  - GCP Secret Manager
  - Kubernetes Secrets (encrypted at rest)

## Required vs Optional

### Required for Local Dev
- `JWT_SECRET` - Can use default for local
- `MONGO_ROOT_PASSWORD` - Can use default for local
- `REDIS_PASSWORD` - Can use default for local

### Optional for Local Dev
- `OPENAI_API_KEY` - Only if using OpenAI (leave empty for LocalAI)
- `FIREBASE_*` - Only if using Firebase features
- `STRIPE_*` - Only if testing payment features
- External API keys - Only if testing those integrations

## Security Notes

1. **Never commit secrets.yaml** (it's gitignored)
2. **Rotate secrets regularly** in production
3. **Use different secrets** for dev/staging/production
4. **Limit secret access** with Kubernetes RBAC
5. **Enable encryption at rest** for Kubernetes secrets in production

---

For more information, see: [ENVIRONMENT_VARIABLES.md](../../../ENVIRONMENT_VARIABLES.md)

