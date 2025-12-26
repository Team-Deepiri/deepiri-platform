# How ASED Zero-Config System Works - Complete Explanation

## Overview

This document explains the complete flow of how the ASED (Autonomous Sovereignty Enforcement Detonator) system works from YAML configuration files to a fully running monitoring service. **No .env files, no manual steps, just works.**

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    YAML Configuration Files                  │
│  ┌──────────────────────┐  ┌────────────────────────────┐  │
│  │ ased-configmap.yaml  │  │  ased-secret.yaml          │  │
│  │ (Non-sensitive)      │  │  (GitHub App credentials)  │  │
│  └──────────────────────┘  └────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│           docker-compose-k8s.sh (Wrapper Script)           │
│  • Reads YAML files using Python YAML parser                │
│  • Extracts environment variables                           │
│  • Handles multi-line values (private keys)                 │
│  • Exports as shell environment variables                   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    docker-compose                            │
│  • Receives environment variables from wrapper               │
│  • Builds and starts ASED container                         │
│  • Passes env vars to container                             │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              ASED Docker Container                          │
│  ┌────────────────────────────────────────────────────┐   │
│  │  docker-entrypoint.sh                               │   │
│  │  • Checks GitHub App credentials                      │   │
│  │  • Establishes baseline if missing                  │   │
│  │  • Starts Node.js service                           │   │
│  └────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          ▼                                  │
│  ┌────────────────────────────────────────────────────┐   │
│  │  Node.js Service (server.ts)                        │   │
│  │  • Loads config from environment                    │   │
│  │  • Initializes Orchestrator                         │   │
│  │  • Starts detection cycles                          │   │
│  └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Orchestrator                             │
│  • GitHub App Client (authenticates)                       │
│  • Repo Discovery (auto-finds repos)                       │
│  • Baseline Manager (establishes baseline)                  │
│  • Detectors (monitor repos)                                │
│  • Risk Scoring (accumulates risk)                         │
│  • Responders (lock/delete on threshold)                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step Flow

### Phase 1: Configuration Loading

#### Step 1.1: YAML Files (Single Source of Truth)

**Location**: `ops/k8s/configmaps/ased-configmap.yaml` and `ops/k8s/secrets/ased-secret.yaml`

**ConfigMap** (Non-sensitive):
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: deepiri-ased-configmap
data:
  PORT: "5010"
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  STATE_CHECK_INTERVAL: "5"
  AUTO_DISCOVER_REPOS: "true"
  REPO_PATTERN: "deepiri-.*"
```

**Secret** (Sensitive):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: deepiri-ased-secret
type: Opaque
stringData:
  GITHUB_APP_ID: "123456"
  GITHUB_INSTALLATION_ID: "789012"
  GITHUB_APP_PRIVATE_KEY: |
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA...
    (multi-line private key)
    -----END RSA PRIVATE KEY-----
  GITHUB_ORG: "Team-Deepiri"
```

**Key Points**:
- YAML files are the **only** source of configuration
- No .env files needed
- Can be transferred via SCP, Git, or external secrets management
- Multi-line values (like private keys) are preserved

---

#### Step 1.2: docker-compose-k8s.sh Wrapper

**What it does**:
1. Reads all YAML files from `ops/k8s/configmaps/` and `ops/k8s/secrets/`
2. Parses YAML using Python's `yaml` library (handles multi-line values)
3. Extracts `data:` and `stringData:` sections
4. Exports as shell environment variables
5. Runs `docker-compose` with those variables

**Code Flow**:
```bash
# For each YAML file:
python3 << EOF
import yaml
import os

with open('yaml_file', 'r') as f:
    config = yaml.safe_load(f)

# Extract from ConfigMap (data section)
if 'data' in config:
    for key, value in config['data'].items():
        os.environ[key] = str(value)  # Export as env var

# Extract from Secret (stringData section)
if 'stringData' in config:
    for key, value in config['stringData'].items():
        os.environ[key] = str(value)  # Export as env var
EOF

# Now all variables are exported, run docker-compose
docker-compose "$@"
```

**Result**: Environment variables are available to docker-compose:
- `GITHUB_APP_ID=123456`
- `GITHUB_APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n..."`
- `PORT=5010`
- etc.

---

### Phase 2: Container Startup

#### Step 2.1: Docker Compose

**docker-compose.yml**:
```yaml
deepiri-ased:
  build:
    context: .
    dockerfile: platform-services/backend/deepiri-ased/Dockerfile
  environment:
    - GITHUB_APP_ID=${GITHUB_APP_ID}  # From wrapper
    - GITHUB_APP_PRIVATE_KEY=${GITHUB_APP_PRIVATE_KEY}  # From wrapper
    - PORT=${PORT:-5010}  # From wrapper
    # ... all other vars
```

**What happens**:
1. Docker Compose receives environment variables from wrapper
2. Builds the ASED Docker image
3. Starts container with environment variables injected
4. Runs `docker-entrypoint.sh` as entrypoint

---

#### Step 2.2: docker-entrypoint.sh

**What it does**:
1. **Checks GitHub App credentials**:
   ```bash
   if [ -n "$GITHUB_APP_ID" ] && [ -n "$GITHUB_INSTALLATION_ID" ] && [ -n "$GITHUB_APP_PRIVATE_KEY" ]; then
     echo "GitHub App configured"
   fi
   ```

2. **Checks for baseline**:
   ```bash
   if [ ! -f "/app/data/baseline.json" ]; then
     echo "Baseline not found, will be established on startup"
   fi
   ```

3. **Starts Node.js service**:
   ```bash
   exec node dist/server.js
   ```

**Key Point**: Entrypoint doesn't establish baseline itself - that's done by the orchestrator on first run.

---

### Phase 3: Service Initialization

#### Step 3.1: server.ts

**What it does**:
1. Loads configuration from environment variables (via `dotenv`)
2. Creates `Orchestrator` instance
3. Calls `orchestrator.initialize()`
4. Starts scheduler for detection cycles
5. Starts Express server for health checks

**Code**:
```typescript
const config = loadConfig();  // Reads from process.env
orchestrator = new Orchestrator();  // Passes config
await orchestrator.initialize();  // Sets up everything
scheduler = new Scheduler(orchestrator);  // Starts cycles
app.listen(PORT);  // Starts HTTP server
```

---

#### Step 3.2: Orchestrator Constructor

**What it does**:
1. **Loads config** from environment:
   ```typescript
   this.config = loadConfig();  // Reads process.env
   ```

2. **Initializes GitHub Client** (GitHub App preferred):
   ```typescript
   if (this.config.github.appId && this.config.github.installationId && this.config.github.privateKey) {
     // Use GitHub App
     const appClient = new GitHubAppClient(
       this.config.github.appId,
       this.config.github.installationId,
       this.config.github.privateKey,
       this.config.github.org
     );
     this.githubClient = appClient;
     this.isGitHubApp = true;
   }
   ```

3. **Initializes all components**:
   - Baseline Manager
   - Storage (Audit Log, State Store)
   - Detectors (State Invariant, Dual Token, Write Canary, etc.)
   - Scoring (Risk Accumulator, Decay Engine, Threshold Manager)
   - Responders (Lock, Backup, Notify, Delete)

---

#### Step 3.3: GitHub App Client Authentication

**How GitHub App authentication works**:

1. **Octokit with App Auth**:
   ```typescript
   this.octokit = new Octokit({
     authStrategy: createAppAuth,
     auth: {
       appId: appId,
       privateKey: privateKey,
       installationId: installationId,
     },
   });
   ```

2. **Automatic Token Generation**:
   - `@octokit/auth-app` automatically:
     - Generates JWT from App ID + Private Key
     - Exchanges JWT for installation access token
     - Refreshes token when it expires (1 hour)
     - **No manual token management needed!**

3. **Token Lifecycle**:
   ```
   JWT (10 min) → Installation Token (1 hour) → Auto-refresh
   ```

**Key Point**: GitHub App handles all token management automatically. No manual token creation or rotation needed.

---

#### Step 3.4: Orchestrator.initialize()

**What it does**:

1. **Tries to load baseline**:
   ```typescript
   const baseline = await this.baselineManager.loadBaseline();
   ```

2. **If baseline doesn't exist**:
   ```typescript
   if (!baseline) {
     // Get repos to baseline
     let repos = this.config.detection.crossRepo.criticalRepos;
     
     // Auto-discover if enabled
     if (this.config.github.autoDiscoverRepos && this.isGitHubApp) {
       const discovery = new RepoDiscovery(this.githubClient, this.config.github.repoPattern);
       repos = await discovery.getCriticalRepos();
     }
     
     // Establish baseline
     await this.baselineManager.establishBaseline(repos);
   }
   ```

3. **Initializes detectors**:
   ```typescript
   await this.detectors.stateInvariant.initialize();
   ```

---

### Phase 4: Auto-Discovery

#### Step 4.1: RepoDiscovery.getCriticalRepos()

**What it does**:

1. **Lists all org repos**:
   ```typescript
   const allRepos = await this.githubApp.listOrgRepos(this.pattern);
   // Uses: octokit.repos.listForOrg({ org, type: 'all' })
   ```

2. **Filters by pattern**:
   ```typescript
   if (!pattern || repo.name.match(new RegExp(pattern))) {
     repos.push(repoName);
   }
   // Pattern: "deepiri-.*" matches: deepiri-platform, deepiri-core-api, etc.
   ```

3. **Filters active repos**:
   ```typescript
   const state = await this.githubApp.fetchRepoState(repo);
   return !state.archived && !state.disabled;
   ```

4. **Prioritizes core repos**:
   ```typescript
   const coreRepos = ['deepiri-platform', 'deepiri-core-api', ...];
   // Adds core repos first, then others
   ```

**Result**: List of repositories to monitor, e.g.:
- `Team-Deepiri/deepiri-platform`
- `Team-Deepiri/deepiri-core-api`
- `Team-Deepiri/diri-cyrex`
- etc.

---

### Phase 5: Baseline Establishment

#### Step 5.1: BaselineManager.establishBaseline()

**What it does**:

For each repository:

1. **Fetches current state**:
   ```typescript
   const state = await this.githubClient.fetchRepoState(repo);
   // Returns: { owner, admins, branchProtection, webhooks, defaultBranch, visibility, archived, disabled }
   ```

2. **Fetches fingerprint**:
   ```typescript
   const fingerprint = await this.githubClient.fetchRepoFingerprint(repo);
   // Returns: { repoId, createdAt, rootCommitHash, ownerOrgId, defaultBranchSha }
   ```

3. **Hashes state**:
   ```typescript
   const stateHash = this.hashRepoState(state);
   // Creates SHA256 hash of normalized state
   ```

4. **Stores baseline**:
   ```typescript
   const baseline = {
     timestamp: new Date(),
     version: '1.0',
     repos: {
       [repo]: {
         stateHash,
         fingerprint,
         admins: state.admins,
         branchProtection: state.branchProtection,
       }
     }
   };
   await this.baselineStorage.save(baseline);
   ```

**Result**: Baseline stored in `/app/data/baseline.json` (or remote storage)

---

### Phase 6: Detection Cycle

#### Step 6.1: Scheduler

**What it does**:
```typescript
// Runs every 5 minutes (configurable)
setInterval(() => {
  orchestrator.runDetectionCycle();
}, 5 * 60 * 1000);
```

---

#### Step 6.2: Detection Cycle Flow

**For each repository**:

1. **State Invariant Check**:
   ```typescript
   const currentState = await this.githubClient.fetchRepoState(repo);
   const currentHash = this.baselineManager.hashRepoState(currentState);
   const baselineHash = baseline.repos[repo].stateHash;
   
   if (currentHash !== baselineHash) {
     // State changed! Calculate risk
     const diff = this.baselineManager.computeStateDiff(baselineState, currentState);
     risk = calculateRisk(diff.severity);  // 5-10 points
   }
   ```

2. **Write Canary Check**:
   ```typescript
   const canaryBranch = await this.githubClient.createCanaryBranch(repo);
   if (!canaryBranch) {
     risk += 5;  // Write access lost
   } else {
     await this.githubClient.deleteCanaryBranch(repo, canaryBranch);
   }
   ```

3. **Negative Auth Check** (org-level):
   ```typescript
   const auditLog = await this.githubClient.fetchAuditLog(org);
   const negativeEvents = auditLog.filter(e => 
     e.type === 'member.removed' || 
     e.type === 'repo.transferred' ||
     e.type === 'repo.access_revoked'
   );
   if (negativeEvents.length > 0) {
     risk += 9;  // High risk
   }
   ```

4. **Cross-Repo Correlation**:
   ```typescript
   const failures = repos.filter(r => detectionFailed(r));
   const failureRate = failures.length / repos.length;
   if (failureRate > 0.5) {  // 50% threshold
     risk += 4;  // Systemic issue
   }
   ```

---

#### Step 6.3: Risk Accumulation

**What it does**:
```typescript
// Accumulate risks
for (const [key, risk] of detectionResults.entries()) {
  const repo = key.split('-')[0];
  this.scoring.accumulator.addRisk(repo, risk, key);
}

// Apply decay (risk decreases over time)
this.scoring.decay.applyDecay(this.scoring.accumulator);
// Decay: -1 point per hour

// Check thresholds
const score = this.scoring.accumulator.getScore(repo);
const threshold = this.scoring.thresholds.checkThresholds(score);
// Thresholds: lock=6, warn=10, delete=15, immediate=20
```

---

#### Step 6.4: Response Actions

**What it does**:
```typescript
if (threshold.level === 'lock') {
  await this.responders.lock.lockAll([repo]);
  // Locks all Deepiri services
}

if (threshold.level === 'delete') {
  await this.responders.backup.backup(repo);  // If enabled
  await this.responders.delete.deleteRepositories([repo]);
  // Deletes repository
}

await this.responders.notify.sendAlert(threshold.level, repo, score);
// Sends email/Slack notification
```

---

## Complete Data Flow

### Configuration Flow
```
YAML Files
  ↓
docker-compose-k8s.sh (Python YAML parser)
  ↓
Environment Variables (exported)
  ↓
docker-compose (injects into container)
  ↓
Container Environment (process.env)
  ↓
loadConfig() (reads process.env)
  ↓
ServiceConfig object
  ↓
Orchestrator (uses config)
```

### Authentication Flow
```
GitHub App Credentials (from YAML)
  ↓
GitHubAppClient (creates Octokit with App Auth)
  ↓
@octokit/auth-app (generates JWT)
  ↓
GitHub API (exchanges JWT for installation token)
  ↓
Installation Token (1 hour, auto-refreshed)
  ↓
All GitHub API calls (authenticated)
```

### Discovery Flow
```
AUTO_DISCOVER_REPOS=true (from YAML)
  ↓
RepoDiscovery.getCriticalRepos()
  ↓
GitHubAppClient.listOrgRepos(pattern)
  ↓
GitHub API: GET /orgs/{org}/repos
  ↓
Filter by pattern: "deepiri-.*"
  ↓
Filter active repos (not archived/disabled)
  ↓
List of repositories
  ↓
Orchestrator.config.detection.crossRepo.criticalRepos
```

### Baseline Flow
```
Baseline missing
  ↓
Orchestrator.initialize()
  ↓
Auto-discover repos (if enabled)
  ↓
For each repo:
  - Fetch current state
  - Fetch fingerprint
  - Hash state
  - Store in baseline
  ↓
Baseline saved
  ↓
State Invariant Detector uses baseline
```

### Detection Flow
```
Scheduler (every 5 minutes)
  ↓
Orchestrator.runDetectionCycle()
  ↓
For each repo:
  - State Invariant Check
  - Write Canary Check
  - Negative Auth Check
  - Cross-Repo Correlation
  ↓
Risk Accumulation
  ↓
Decay Application
  ↓
Threshold Check
  ↓
Response Actions (if threshold breached)
```

---

## Key Design Decisions

### 1. Why YAML Files?
- **Single source of truth**: No .env file generation needed
- **Kubernetes compatible**: Same format as production
- **Version controllable**: Can commit with placeholders
- **Transferable**: Easy to transfer via SCP, Git, etc.

### 2. Why GitHub App?
- **No manual tokens**: Automatic token generation
- **Organization-level**: Can't be bypassed
- **Auto-rotation**: GitHub handles token lifecycle
- **Fine-grained permissions**: Only what's needed

### 3. Why Auto-Discovery?
- **Zero config**: No manual repo list
- **Always up-to-date**: New repos automatically included
- **Pattern-based**: Flexible filtering

### 4. Why Baseline Auto-Establishment?
- **Zero setup**: Works on first run
- **Self-healing**: Re-establishes if missing
- **Graceful degradation**: Service starts even if baseline fails

---

## Error Handling

### Configuration Missing
- **GitHub App not configured**: Service starts but detection fails
- **Baseline missing**: Auto-establishes on first run
- **Repos not found**: Uses configured repos or logs warning

### Authentication Failures
- **Invalid credentials**: Service logs error, retries on next cycle
- **Token expired**: GitHub App auto-refreshes (handled by Octokit)
- **Access revoked**: Detected by negative auth check

### Detection Failures
- **API rate limit**: Retries with exponential backoff
- **Network error**: Logs error, continues with other repos
- **Baseline corruption**: Re-establishes baseline

---

## Summary

**The complete flow**:
1. YAML files → docker-compose-k8s.sh → Environment variables
2. docker-compose → Container with env vars
3. docker-entrypoint.sh → Node.js service
4. server.ts → Orchestrator initialization
5. Orchestrator → GitHub App auth → Auto-discovery → Baseline establishment
6. Scheduler → Detection cycles → Risk scoring → Response actions

**Key Points**:
- ✅ **Zero config**: Just YAML files
- ✅ **Auto-discovery**: Finds repos automatically
- ✅ **Auto-baseline**: Establishes on first run
- ✅ **GitHub App**: No manual tokens
- ✅ **Self-healing**: Handles errors gracefully

**Result**: Teammates just run `./docker-compose-k8s.sh up -d deepiri-ased` and it works!

