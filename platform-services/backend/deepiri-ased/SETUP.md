# Deepiri ASED Setup Guide

Quick setup guide for the Autonomous Sovereignty Enforcement Detonator.

## Prerequisites

1. **GitHub Organization** with admin access
2. **Two GitHub Personal Access Tokens** from different accounts
3. **Docker** (for containerized deployment)

## Quick Start

### 1. Get GitHub Tokens

See [GITHUB_TOKENS_SETUP.md](./GITHUB_TOKENS_SETUP.md) for detailed instructions.

**Quick version**:
1. Go to https://github.com/settings/tokens
2. Create Token A with scopes: `repo`, `admin:org`, `read:audit_log`, `workflow`
3. Create Token B (from different account) with scopes: `repo`, `read:org`
4. Copy both tokens (format: `ghp_xxxxxxxxxxxx`)

### 2. Configure Environment

#### Docker Compose (Already Configured)

The service is already in `docker-compose.yml`. Configuration is loaded from YAML files:

**ConfigMap**: `ops/k8s/configmaps/ased-configmap.yaml`  
**Secret**: `ops/k8s/secrets/ased-secret.yaml`

**Start the service**:
```bash
# Use wrapper to load from YAML files
./docker-compose-k8s.sh up -d deepiri-ased
```

No manual environment variables needed - everything comes from YAML files!

#### Local Development

**Option 1: Use YAML files (Recommended)**

1. Configure YAML files:
   ```bash
   # Edit config
   vim ops/k8s/configmaps/ased-configmap.yaml
   
   # Edit secrets
   vim ops/k8s/secrets/ased-secret.yaml
   ```

2. Start with wrapper:
   ```bash
   ./docker-compose-k8s.sh up -d deepiri-ased
   ```

**Option 2: Use .env file (For testing only)**

1. Copy environment template:
   ```bash
   cd platform-services/backend/deepiri-ased
   cp .env.example .env
   ```

2. Edit `.env` and set GitHub App credentials:
   ```bash
   GITHUB_APP_ID=123456
   GITHUB_INSTALLATION_ID=789012
   GITHUB_APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
   GITHUB_ORG=Team-Deepiri
   ```

### 3. Start Service

#### Docker Compose

```bash
docker-compose up -d deepiri-ased
```

The service will automatically:
- Install dependencies
- Check for baseline
- Establish baseline if missing
- Start monitoring

#### Local Development

```bash
cd platform-services/backend/deepiri-ased
npm install
npm run establish-baseline  # First time only
npm run dev
```

### 4. Verify Setup

1. **Check health**:
   ```bash
   curl http://localhost:5010/health
   ```

2. **Check logs**:
   ```bash
   docker-compose logs -f deepiri-ased
   ```

3. **Check risk scores**:
   ```bash
   curl http://localhost:5010/risk-scores
   ```

4. **Look for**:
   - "GitHub tokens configured"
   - "Baseline established successfully"
   - "Scheduler started"

## What Happens Automatically

When the service starts:

1. **Initialization**:
   - Loads configuration from environment
   - Validates GitHub tokens
   - Loads or establishes baseline

2. **Baseline Establishment** (first run):
   - Captures current state of all critical repos
   - Stores cryptographic hashes
   - Saves to `/app/data/baseline.json`

3. **Monitoring Starts**:
   - State checks every 5 minutes
   - Write canary tests every hour
   - Audit log checks every 15 minutes
   - Risk score decay every hour

4. **Automatic Responses**:
   - Risk 6-9: Lock services (read-only)
   - Risk 10-14: Warn + backup
   - Risk 10+ (after grace period): Delete repos

## Configuration Options

### Detection Intervals

```bash
STATE_CHECK_INTERVAL=5        # Minutes between state checks
WRITE_CANARY_INTERVAL=60      # Minutes between write tests
AUDIT_LOG_INTERVAL=15         # Minutes between audit log checks
```

### Risk Thresholds

```bash
RISK_LOCK_THRESHOLD=6        # Lock services at this score
RISK_WARN_THRESHOLD=10        # Warn at this score
RISK_DELETE_THRESHOLD=10      # Delete at this score (after grace period)
RISK_IMMEDIATE_THRESHOLD=15   # Immediate deletion (no grace period)
```

### Grace Periods (hours)

```bash
GRACE_PERIOD_LOCK=24         # Hours before lock action
GRACE_PERIOD_WARN=48         # Hours before warn action
GRACE_PERIOD_DELETE=72       # Hours before delete action
GRACE_PERIOD_IMMEDIATE=0     # Hours for immediate threats
```

## Manual Operations

### Establish Baseline Manually

```bash
docker-compose exec deepiri-ased npm run establish-baseline
```

### Test Detection

```bash
docker-compose exec deepiri-ased npm run test-detection
```

### Simulate Failure

```bash
docker-compose exec deepiri-ased npm run simulate-failure deepiri-platform 10
```

### Trigger Detection Cycle

```bash
curl -X POST http://localhost:5010/trigger
```

## Monitoring

### Logs

```bash
# Follow logs
docker-compose logs -f deepiri-ased

# Check error logs
docker-compose exec deepiri-ased cat /app/logs/sovereignty-enforcement-error.log
```

### Metrics

- Risk scores: `GET /risk-scores`
- Health: `GET /health`
- Audit log: `/app/data/audit.log`

## Troubleshooting

### "GitHub tokens not configured"

- Check environment variables are set
- Verify tokens in docker-compose.yml or .env
- Restart service after setting tokens

### "Baseline not found"

- Service will auto-establish on first run
- Or run manually: `npm run establish-baseline`
- Check tokens have access to all repos

### "Authentication failed"

- Verify tokens haven't expired
- Check token scopes are correct
- Verify tokens are from different accounts

### Service won't start

- Check logs: `docker-compose logs deepiri-ased`
- Verify port 5010 is available
- Check Docker has enough resources

## Next Steps

1. **Review Configuration**: Adjust thresholds and intervals as needed
2. **Set Up Notifications**: Configure email/Slack/SMS alerts
3. **Test System**: Run `test-detection` and `simulate-failure`
4. **Monitor**: Watch logs and risk scores for first 24 hours
5. **Adjust**: Fine-tune thresholds based on real-world usage

## Security Notes

- Tokens are stored in environment variables (never in code)
- Baseline is encrypted at rest
- All actions are logged to audit trail
- Service runs with minimal permissions
- Tokens should be rotated every 90 days

## Support

- See [GITHUB_TOKENS_SETUP.md](./GITHUB_TOKENS_SETUP.md) for token setup
- See [README.md](./README.md) for full documentation
- Check logs for detailed error messages

