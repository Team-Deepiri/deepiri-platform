# GitHub Tokens Setup Guide

This guide explains how to create and configure the GitHub tokens required for the Deepiri ASED (Autonomous Sovereignty Enforcement Detonator) service.

## Why Two Tokens?

The ASED system uses **dual-token verification** to eliminate false positives from temporary token expiration or network issues. If only one token fails, it's likely a temporary issue. If both tokens fail, it's a real security event.

## Token Requirements

### Token A - Primary Authority (Org Owner Bot)

**Purpose**: Primary monitoring and enforcement token

**Required Scopes**:
- `repo` (full access) - Read and write to repositories
- `admin:org` - Organization administration
- `read:audit_log` - Access to organization audit logs
- `workflow` - GitHub Actions workflow access

**Used For**:
- State invariant checks (reading repo configuration)
- Write-path canary tests (creating/deleting test branches)
- Repository deletion (if threshold breached)
- Fetching audit logs

**Account Type**: 
- **Recommended**: Organization-owned bot account or service account
- **Alternative**: Personal access token from org owner (less secure)

### Token B - Independent Verifier

**Purpose**: Independent verification to eliminate false positives

**Required Scopes**:
- `repo` (read-only is sufficient) - Read repository information
- `read:org` - Read organization information

**Used For**:
- Verifying access state independently
- Cross-checking Token A results
- Eliminating PAT expiration false positives

**Account Type**:
- **Recommended**: Different user account or separate bot
- **Critical**: Must be from a DIFFERENT account than Token A

## Step-by-Step Setup

### Step 1: Create Token A (Primary Authority)

1. **Go to GitHub Settings**:
   - Navigate to: https://github.com/settings/tokens
   - Or: Your Profile → Settings → Developer settings → Personal access tokens → Tokens (classic)

2. **Create New Token**:
   - Click "Generate new token" → "Generate new token (classic)"
   - Give it a descriptive name: `Deepiri-ASED-Primary` or `ASED-Token-A`

3. **Set Expiration**:
   - **Recommended**: 90 days (with rotation plan)
   - **Maximum**: 1 year
   - **Never expire**: Not recommended for security

4. **Select Scopes**:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `admin:org` (Full control of orgs and teams)
   - ✅ `read:audit_log` (Read org audit log)
   - ✅ `workflow` (Update GitHub Action workflows)

5. **Generate and Copy**:
   - Click "Generate token"
   - **IMPORTANT**: Copy the token immediately (you won't see it again!)
   - Format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### Step 2: Create Token B (Independent Verifier)

**CRITICAL**: Use a DIFFERENT GitHub account than Token A!

1. **Use Different Account**:
   - If Token A is from your personal account, create Token B from:
     - A team member's account
     - A dedicated bot/service account
     - An organization-owned app

2. **Go to GitHub Settings** (on the different account):
   - Navigate to: https://github.com/settings/tokens

3. **Create New Token**:
   - Click "Generate new token" → "Generate new token (classic)"
   - Name: `Deepiri-ASED-Verifier` or `ASED-Token-B`

4. **Set Expiration**:
   - Same as Token A (for easier rotation)

5. **Select Scopes**:
   - ✅ `repo` (Read-only is sufficient, but full access works too)
   - ✅ `read:org` (Read org and team membership)

6. **Generate and Copy**:
   - Copy the token immediately
   - Format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### Step 3: Configure in Environment

#### Option A: Docker Compose

Add to your `docker-compose.yml`:

```yaml
services:
  deepiri-ased:
    environment:
      - GITHUB_TOKEN_A=ghp_your_token_a_here
      - GITHUB_TOKEN_B=ghp_your_token_b_here
      - GITHUB_ORG=Team-Deepiri
      - CRITICAL_REPOS=deepiri-platform,deepiri-core-api,diri-cyrex,deepiri-web-frontend
```

#### Option B: .env File

Create `.env` file in `platform-services/backend/deepiri-ased/`:

```bash
GITHUB_TOKEN_A=ghp_your_token_a_here
GITHUB_TOKEN_B=ghp_your_token_b_here
GITHUB_ORG=Team-Deepiri
CRITICAL_REPOS=deepiri-platform,deepiri-core-api,diri-cyrex,deepiri-web-frontend
```

#### Option C: Kubernetes Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: deepiri-ased-secrets
type: Opaque
stringData:
  GITHUB_TOKEN_A: ghp_your_token_a_here
  GITHUB_TOKEN_B: ghp_your_token_b_here
```

### Step 4: Verify Configuration

1. **Start the service**:
   ```bash
   docker-compose up deepiri-ased
   ```

2. **Check logs**:
   ```bash
   docker-compose logs deepiri-ased
   ```

3. **Look for**:
   - "GitHub tokens configured"
   - "Baseline established successfully" (if first run)

4. **Test health endpoint**:
   ```bash
   curl http://localhost:5010/health
   ```

## Alternative: Using GitHub Apps

For better security and organization management, consider using **GitHub Apps** instead of personal access tokens:

### Benefits of GitHub Apps:
- Better permission scoping
- Organization-level installation
- Automatic token rotation
- Fine-grained permissions

### Setup GitHub App:

1. **Create GitHub App**:
   - Go to: https://github.com/organizations/YOUR_ORG/settings/apps
   - Click "New GitHub App"

2. **Configure Permissions**:
   - Repository permissions:
     - Contents: Read & Write
     - Metadata: Read-only
     - Administration: Read & Write
   - Organization permissions:
     - Members: Read-only
     - Audit log: Read-only

3. **Install App**:
   - Install on your organization
   - Select repositories (or all repos)

4. **Generate Installation Token**:
   - Use GitHub API to generate installation tokens
   - Tokens expire after 1 hour (auto-refresh needed)

5. **Use in ASED**:
   - Token A: GitHub App installation token
   - Token B: Personal access token (different account)

## Security Best Practices

1. **Never Commit Tokens**:
   - ❌ Don't commit tokens to git
   - ✅ Use environment variables
   - ✅ Use secrets management (AWS Secrets Manager, HashiCorp Vault, etc.)

2. **Rotate Regularly**:
   - Rotate tokens every 90 days
   - Update both tokens simultaneously
   - Test after rotation

3. **Monitor Token Usage**:
   - Check GitHub audit logs for token usage
   - Set up alerts for unusual activity

4. **Use Least Privilege**:
   - Token B only needs read access
   - Token A needs write access only for canary operations

5. **Separate Accounts**:
   - Token A and Token B must be from different accounts
   - This is critical for dual-token verification to work

## Troubleshooting

### "GitHub tokens not configured"
- Check environment variables are set
- Verify tokens start with `ghp_`
- Check for extra spaces or quotes

### "Authentication failed"
- Verify token hasn't expired
- Check token has correct scopes
- Verify token hasn't been revoked

### "Baseline establishment failed"
- Check both tokens have access to all critical repos
- Verify organization name is correct
- Check network connectivity to GitHub API

### "Dual-token disagreement"
- This is expected if tokens are from different accounts with different permissions
- Verify both tokens can access the same repos
- Check organization membership

## Token Rotation

When rotating tokens:

1. **Create new tokens** (following steps above)
2. **Update environment variables**:
   ```bash
   export GITHUB_TOKEN_A=ghp_new_token_a
   export GITHUB_TOKEN_B=ghp_new_token_b
   ```
3. **Restart service**:
   ```bash
   docker-compose restart deepiri-ased
   ```
4. **Verify**:
   - Check logs for "GitHub tokens configured"
   - Run test detection: `npm run test-detection`
5. **Revoke old tokens** (after verification)

## Support

For issues with token setup:
- Check GitHub documentation: https://docs.github.com/en/authentication
- Review service logs: `docker-compose logs deepiri-ased`
- Test tokens manually: `curl -H "Authorization: token ghp_xxx" https://api.github.com/user`

