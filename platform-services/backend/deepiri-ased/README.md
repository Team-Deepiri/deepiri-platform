# Deepiri ASED - Autonomous Sovereignty Enforcement Detonator

Autonomous system for monitoring and protecting Deepiri platform repositories through state invariant enforcement, dual-token verification, and graduated response mechanisms.

## Overview

The Deepiri ASED (Autonomous Sovereignty Enforcement Detonator) is a comprehensive security system that:

- Monitors GitHub repository states continuously
- Detects unauthorized access and configuration changes
- Responds with graduated actions (lock -> warn -> delete)
- Operates autonomously without human intervention
- Achieves zero false positives through multi-signal validation

## Features

### Detection Mechanisms

1. **State Invariant Enforcement** - Verifies critical GitHub states haven't changed
2. **Dual-Token Verification** - Requires two independent tokens to agree
3. **Negative Authorization Detection** - Monitors GitHub audit logs for explicit removal events
4. **Write-Path Canary** - Tests write access periodically
5. **Cross-Repo Correlation** - Detects systemic issues across multiple repos
6. **Temporal Consistency** - Requires continuous failures over time

### Response System

- **Lock Mode** (Risk 6-9): Services locked to read-only
- **Warning Mode** (Risk 10-14): Enhanced monitoring and backups
- **Delete Mode** (Risk 10+): Repository deletion after grace period
- **Immediate Mode** (Risk 15+): Accelerated deletion for critical threats

## Installation

```bash
cd platform-services/backend/deepiri-ased
npm install
```

## Configuration

### Quick Setup

- **Zero-Config Setup** (Recommended): See [ZERO_CONFIG_SETUP.md](./ZERO_CONFIG_SETUP.md)
- **Manual Setup**: See [SETUP.md](./SETUP.md) for detailed setup guide

### How Configuration Works

**No .env file generation needed!** Configuration is loaded directly from YAML files:

- **Config**: `ops/k8s/configmaps/ased-configmap.yaml`
- **Secrets**: `ops/k8s/secrets/ased-secret.yaml`

Use the `docker-compose-k8s.sh` wrapper to automatically load from YAML:

```bash
./docker-compose-k8s.sh up -d deepiri-ased
```

See [HOW_IT_WORKS_COMPLETE.md](./HOW_IT_WORKS_COMPLETE.md) for complete technical details, or [ZERO_CONFIG_SETUP.md](./ZERO_CONFIG_SETUP.md) for zero-config setup guide.

### GitHub App Permissions

See [GITHUB_APP_PERMISSIONS.md](./GITHUB_APP_PERMISSIONS.md) for exact permission requirements.

### GitHub Tokens (Legacy)

**IMPORTANT**: You need two GitHub Personal Access Tokens from different accounts.

See [GITHUB_TOKENS_SETUP.md](./GITHUB_TOKENS_SETUP.md) for detailed instructions on:
- Where to get tokens
- What scopes are needed
- How to configure them
- Security best practices

**Quick version**:
1. Go to https://github.com/settings/tokens
2. Create Token A: `repo`, `admin:org`, `read:audit_log`, `workflow`
3. Create Token B (different account): `repo`, `read:org`
4. Add to environment variables (see below)

### Environment Variables (Legacy - Use YAML Instead)

**Note**: For zero-config setup, use YAML files (see above). The `.env` file is only for local development/testing.

For local development, copy `.env.example` to `.env` and configure:

```bash
# GitHub Configuration (REQUIRED)
GITHUB_TOKEN_A=ghp_xxx                    # Primary token (org owner bot)
GITHUB_TOKEN_B=ghp_xxx                    # Verifier token (different account)
GITHUB_ORG=Team-Deepiri                   # Your GitHub organization

# Critical Repositories (REQUIRED)
CRITICAL_REPOS=deepiri-platform,deepiri-core-api,diri-cyrex,deepiri-web-frontend

# Detection Intervals (minutes)
STATE_CHECK_INTERVAL=5
WRITE_CANARY_INTERVAL=60
AUDIT_LOG_INTERVAL=15

# Risk Thresholds
RISK_LOCK_THRESHOLD=6
RISK_WARN_THRESHOLD=10
RISK_DELETE_THRESHOLD=10
RISK_IMMEDIATE_THRESHOLD=15

# Grace Periods (hours)
GRACE_PERIOD_LOCK=24
GRACE_PERIOD_WARN=48
GRACE_PERIOD_DELETE=72
```

## Usage

### Docker (Recommended)

The Docker setup automatically handles:
- Dependency installation
- Baseline establishment (if missing)
- Service startup

```bash
# Add to docker-compose.yml (see SETUP.md)
docker-compose up -d deepiri-ased

# Check logs
docker-compose logs -f deepiri-ased
```

### Local Development

#### First Time Setup

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your GitHub tokens
   ```

3. **Establish baseline**:
   ```bash
   npm run establish-baseline
   ```

4. **Start service**:
   ```bash
   npm run dev
   ```

#### Subsequent Runs

```bash
npm run dev  # Development
npm run build && npm start  # Production
```

### Test Detection

```bash
npm run test-detection
```

### Simulate Failure

```bash
npm run simulate-failure <repo> <risk>
```

Example:
```bash
npm run simulate-failure deepiri-platform 10
```

## API Endpoints

### Health Check

```bash
GET /health
```

### Trigger Detection Cycle

```bash
POST /trigger
```

### Get Risk Scores

```bash
GET /risk-scores
```

## Architecture

```
deepiri-ased/
├── src/
│   ├── detectors/          # Detection mechanisms
│   ├── scoring/             # Risk scoring system
│   ├── responders/          # Response actions
│   ├── baseline/            # Baseline management
│   ├── github/              # GitHub API integration
│   ├── storage/             # State and audit storage
│   ├── orchestrator.ts      # Main coordination
│   ├── scheduler.ts         # Cron scheduling
│   └── server.ts            # HTTP server
├── scripts/                 # Utility scripts
└── tests/                   # Test suites
```

## Detection Flow

1. **State Check** - Every 5-15 minutes, verify repo state matches baseline
2. **Token Verification** - Check both tokens have access
3. **Write Canary** - Test write access every hour
4. **Audit Log** - Monitor for negative auth events
5. **Risk Accumulation** - Add detected risks to score
6. **Decay** - Reduce score by 1 per hour (no new events)
7. **Threshold Check** - Compare score to thresholds
8. **Response** - Execute appropriate response action

## Response Actions

### Lock (Risk 6-9)

- All `deepiri-*` services set to read-only
- Notifications sent
- 24-48 hour grace period
- Fully reversible

### Warn (Risk 10-14)

- Services remain locked
- Backups created
- Enhanced notifications
- 48-72 hour grace period
- Still reversible

### Delete (Risk 10+ after grace period)

- Repositories deleted via GitHub API
- Containers stopped
- Local files removed
- 7-day reversibility window from backup

## Security Considerations

- Tokens stored as environment variables
- Baseline encrypted at rest
- All actions logged to audit trail
- Minimal permissions required
- Isolated container network

## Monitoring

The service logs all actions to:
- Local files: `data/audit.log`
- External storage (if configured)
- Console (development mode)

Risk scores are persisted to: `data/state.json`

## Troubleshooting

### Baseline Not Found

```bash
npm run establish-baseline
```

### False Positives

- Check temporal consistency settings
- Verify dual tokens are both valid
- Review cross-repo correlation thresholds

### Service Not Responding

- Check health endpoint: `GET /health`
- Review logs: `logs/sovereignty-enforcement-*.log`
- Verify GitHub tokens are valid

## Development

```bash
# Run tests
npm test

# Watch mode
npm run test:watch

# Coverage
npm run test:coverage
```

## Docker

```bash
docker build -t deepiri-ased .
docker run -p 5010:5010 --env-file .env deepiri-ased
```

## License

See LICENSE.md

## Support

For issues or questions, contact the platform engineering team.

