# Zero-Config Setup for Deepiri ASED

**Goal**: ASED runs automatically for all teammates with zero manual configuration.

## How It Works

### 1. GitHub App (Not Personal Tokens)

Instead of requiring each teammate to create personal access tokens:
- **One GitHub App** is created for the entire organization
- **Auto-installs** on all repositories (or selected ones)
- **Automatic token generation** - no manual token management
- **Fine-grained permissions** - only what's needed

### 2. Auto-Discovery

No manual repo list needed:
- Service **automatically discovers** all repos in the org
- Filters by pattern (default: `deepiri-.*`)
- Monitors all discovered repos
- Updates automatically when new repos are added

### 3. Infrastructure Integration

Uses existing platform infrastructure:
- **Kubernetes Secrets** - stores GitHub App credentials (single source of truth)
- **Kubernetes ConfigMaps** - stores service configuration
- **docker-compose-k8s.sh wrapper** - reads directly from YAML files (no .env generation)
- **Team environments** - works with existing team setup scripts

**No .env file generation needed!** The `docker-compose-k8s.sh` script reads directly from:
- `ops/k8s/configmaps/ased-configmap.yaml`
- `ops/k8s/secrets/ased-secret.yaml`

These YAML files are the single source of truth. You can:
- Edit them directly
- Transfer them via file transfer
- Store them in external secrets management
- Version control them (with placeholder values)

## One-Time Setup (Org Admin Only)

### Option A: Automated Setup (Recommended)

```bash
cd platform-services/backend/deepiri-ased

# Step 1: Create GitHub App (requires org owner token)
GITHUB_ORG_OWNER_TOKEN=ghp_xxx npm run setup-github-app

# Follow the instructions to:
# 1. Create GitHub App via web UI
# 2. Install on organization
# 3. Provide App ID, Installation ID, and Private Key

# Step 2: Save credentials
GITHUB_APP_ID=123456 \
GITHUB_INSTALLATION_ID=789012 \
GITHUB_APP_PRIVATE_KEY="$(cat key.pem)" \
npm run setup-github-app
```

This automatically:
- Saves credentials to `ops/k8s/secrets/ased-secret.yaml`
- Configures auto-discovery
- Sets up the service

### Option B: Manual Setup (5 minutes)

1. **Create GitHub App**:
   - Go to: https://github.com/organizations/YOUR_ORG/settings/apps
   - Click "New GitHub App"
   - Name: `deepiri-ased`
   - Permissions (see GITHUB_APP_PERMISSIONS.md for exact list):
     - Repository: Contents (Read & Write), Metadata (Read-only), Administration (Read & Write)
     - Organization: Members (Read-only), Administration (Read-only)
   - Install on: **All repositories** (or select specific ones)

2. **Get Credentials**:
   - After installation, you'll see:
     - App ID (e.g., `123456`)
     - Installation ID (e.g., `789012`)
   - Download the Private Key (.pem file)

3. **Save to Secrets**:
   ```bash
   # Edit ops/k8s/secrets/ased-secret.yaml
   # Add your GitHub App credentials:
   GITHUB_APP_ID: "123456"
   GITHUB_INSTALLATION_ID: "789012"
   GITHUB_APP_PRIVATE_KEY: |
     -----BEGIN RSA PRIVATE KEY-----
     ... (paste key content here)
     -----END RSA PRIVATE KEY-----
   GITHUB_ORG: "Team-Deepiri"
   ```

   **That's it!** No .env file generation needed. The service reads directly from these YAML files.

## For Teammates: Zero Steps!

Once the one-time setup is done, teammates just run:

```bash
# Use the k8s wrapper to load config directly from YAML files
./docker-compose-k8s.sh up -d deepiri-ased

# Or if using team environments (already configured):
cd team_dev_environments/backend-team
./start.sh  # Linux/Mac
.\start.ps1  # Windows
```

**No .env files needed!** The `docker-compose-k8s.sh` wrapper automatically:
- Reads from `ops/k8s/configmaps/ased-configmap.yaml`
- Reads from `ops/k8s/secrets/ased-secret.yaml`
- Passes all variables directly to docker-compose
- No file generation step required

The service will:
- ✅ Load GitHub App credentials from k8s secrets
- ✅ Auto-discover all repos in the org
- ✅ Establish baselines automatically
- ✅ Start monitoring immediately
- ✅ No tokens, no configuration, no commands needed

## How Auto-Discovery Works

1. **On Startup**:
   - Service connects to GitHub using App credentials
   - Lists all repositories in the organization
   - Filters by pattern: `deepiri-.*` (configurable)
   - Excludes archived/disabled repos

2. **Monitoring**:
   - All discovered repos are monitored
   - New repos matching pattern are automatically included
   - No manual updates needed

3. **Configuration**:
   ```yaml
   # ops/k8s/configmaps/ased-configmap.yaml
   AUTO_DISCOVER_REPOS: "true"
   REPO_PATTERN: "deepiri-.*"  # Regex pattern
   ```

## Benefits

### For Teammates
- ✅ **Zero configuration** - just run docker-compose
- ✅ **No tokens to manage** - GitHub App handles authentication
- ✅ **No repo lists** - auto-discovery finds everything
- ✅ **Always up-to-date** - new repos automatically monitored

### For Organization
- ✅ **Centralized security** - one app for entire org
- ✅ **Fine-grained permissions** - only what's needed
- ✅ **Automatic rotation** - GitHub handles token lifecycle
- ✅ **Audit trail** - all actions logged to GitHub

### For Security
- ✅ **No personal tokens** - reduces attack surface
- ✅ **Least privilege** - app only has needed permissions
- ✅ **Organization-level** - can't be bypassed by individuals
- ✅ **Automatic monitoring** - no gaps from manual setup

## Troubleshooting

### "GitHub App not configured"

Check that secrets are in YAML files:
```bash
# Verify secrets exist in YAML
cat ops/k8s/secrets/ased-secret.yaml

# Verify configmap exists
cat ops/k8s/configmaps/ased-configmap.yaml

# Check service logs
./docker-compose-k8s.sh logs deepiri-ased
```

**Note**: Make sure you're using `docker-compose-k8s.sh` wrapper, not plain `docker-compose`. The wrapper loads directly from YAML files.

### "No repos discovered"

Check pattern and permissions:
```bash
# Verify pattern matches your repos
REPO_PATTERN=deepiri-.*  # Should match your repo names

# Check GitHub App has access to repos
# Go to: https://github.com/organizations/YOUR_ORG/settings/apps
# Verify app is installed on repositories
```

### "Auto-discovery failed"

Fallback to manual list:
```bash
# In ops/k8s/secrets/ased-secret.yaml
CRITICAL_REPOS: "deepiri-platform,deepiri-core-api,diri-cyrex"
AUTO_DISCOVER_REPOS: "false"
```

## Migration from Personal Tokens

If you're currently using personal access tokens:

1. **Create GitHub App** (follow setup above)
2. **Update secrets** with App credentials
3. **Remove token variables**:
   ```yaml
   # Remove these:
   # GITHUB_TOKEN_A: ""
   # GITHUB_TOKEN_B: ""
   ```
4. **Restart service**:
   ```bash
   docker-compose restart deepiri-ased
   ```

The service automatically uses GitHub App if available, falls back to tokens if not.

## Next Steps

1. **Org Admin**: Run one-time setup (5 minutes)
2. **Teammates**: Just run `docker-compose up -d` - that's it!
3. **Monitor**: Check `/health` and `/risk-scores` endpoints
4. **Customize**: Adjust thresholds in `ops/k8s/configmaps/ased-configmap.yaml`

## Summary

**Before**: Each teammate needs to:
- Create 2 personal access tokens
- Configure environment variables
- List repositories manually
- Run setup commands

**After**: 
- Org admin: 5-minute one-time setup
- Teammates: Just run docker-compose
- Service: Auto-discovers, auto-configures, auto-monitors

**Result**: Fundamental security layer that "just works" for everyone.

