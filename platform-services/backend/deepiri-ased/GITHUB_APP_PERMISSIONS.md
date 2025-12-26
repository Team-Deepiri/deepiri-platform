# GitHub App Required Permissions

## Exact Permissions Configuration

When creating the GitHub App, configure these **exact** permissions:

### Repository Permissions

| Permission | Access Level | Why Needed |
|------------|--------------|------------|
| **Contents** | Read & Write | Read repo state, create/delete canary branches |
| **Metadata** | Read-only | Read repository metadata (name, visibility, etc.) |
| **Administration** | Read & Write | Check admin access, read branch protection, delete repos if needed |
| **Pull requests** | Read-only | Monitor PR events (optional, for future enhancements) |
| **Issues** | Read-only | Monitor issue events (optional, for future enhancements) |

### Organization Permissions

| Permission | Access Level | Why Needed |
|------------|--------------|------------|
| **Members** | Read-only | Verify admin lists, detect member removals |
| **Administration** | Read-only | Access organization audit logs (if available) |

### Account Permissions

| Permission | Access Level | Why Needed |
|------------|--------------|------------|
| **Email addresses** | Read-only | Not needed, can be set to "No access" |
| **Followers** | Read-only | Not needed, can be set to "No access" |

## Minimum Required Permissions

**Critical (Must Have)**:
- Repository: Contents (Read & Write)
- Repository: Metadata (Read-only)
- Repository: Administration (Read & Write)
- Organization: Members (Read-only)

**Optional (Nice to Have)**:
- Organization: Administration (Read-only) - for audit logs
- Repository: Pull requests (Read-only) - for future event monitoring
- Repository: Issues (Read-only) - for future event monitoring

## Installation Settings

- **Install on**: All repositories (recommended) OR Select specific repositories
- **Where can this GitHub App be installed**: Only on this account (organization)

## Webhook Configuration (Optional)

If you want real-time event processing:
- **Webhook URL**: `https://your-domain.com/webhook/github` (or leave empty)
- **Webhook secret**: Generate a random string (store in secrets)
- **Events**: 
  - Repository
  - Organization
  - Member
  - Push

## Setup Steps

1. Go to: https://github.com/organizations/YOUR_ORG/settings/apps
2. Click "New GitHub App"
3. Fill in:
   - **Name**: `deepiri-ased` (or your preferred name)
   - **Homepage URL**: `https://github.com/YOUR_ORG`
   - **Webhook URL**: (optional, leave empty if not using webhooks)
   - **Webhook secret**: (optional, generate random string)
4. Set permissions (as listed above)
5. Click "Create GitHub App"
6. Click "Install App" → Select organization → Install on all repos
7. After installation, you'll see:
   - **App ID** (e.g., `123456`)
   - **Installation ID** (e.g., `789012`)
8. Click "Generate a private key" → Download `.pem` file

## Security Notes

- **Least Privilege**: App only has permissions it needs
- **Organization-Level**: Can't be bypassed by individual users
- **Automatic Rotation**: GitHub handles token lifecycle
- **Audit Trail**: All app actions are logged in GitHub audit logs

## Verification

After setup, verify permissions:

```bash
# Test app access
curl -H "Authorization: Bearer YOUR_INSTALLATION_TOKEN" \
     https://api.github.com/installation/repositories

# Should return list of accessible repositories
```

