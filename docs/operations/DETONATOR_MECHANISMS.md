# Autonomous Sovereignty Enforcement System (Detonator)

**Purpose**: Remote removal/kill switch for Deepiri platform repos and services  
**Challenge**: Avoid false positives from temporary access loss (PAT/SSH issues)  
**Philosophy**: No humans, minimal false negatives, deterministic response

---

## Core Design Principles

1. **State Invariant Enforcement**: Verify critical GitHub states haven't changed (not just access checks)
2. **Negative Authorization Detection**: Check what you lost, not what you have
3. **Write-Path Verification**: Read access ≠ write authority
4. **Multi-Signal Correlation**: Single failures lie, multi-repo failures don't
5. **Temporal Consistency**: Failures must be continuous, not intermittent
6. **Risk Score Accumulation**: Graduated response based on accumulated risk
7. **Fail-Closed Authorization**: Authorization errors = high-risk signals
8. **No Human Dependency**: Autonomous, deterministic, no heartbeats required

---

## Elite Detection Mechanisms (Zero False Positives)

### 1. **State Invariant Enforcement (Golden Configuration)**

**Key Idea**: Instead of checking activity, continuously verify that critical GitHub states have not changed.

**What You Enforce**:
- Repo ownership (org/user)
- Admin list (who has admin access)
- Branch protection rules (required reviewers, status checks)
- Required reviewers configuration
- Required status checks
- Webhook configuration (endpoints, secrets)
- Default branch name
- Visibility (private/public)
- Repository settings (archived, disabled, etc.)

**How It Works**:
1. Store cryptographic hash of "known-good" GitHub configuration (baseline snapshot)
2. Poll GitHub API every 5-15 minutes
3. Compare current state to baseline hash
4. If invariant breaks → risk score spike (+5 to +10 depending on severity)

**Why This Is Strong**:
- ✅ No human activity needed
- ✅ No false positives from inactivity
- ✅ Detects silent takeovers (attacker changes settings but leaves read access)
- ✅ Catches the most dangerous real-world failures
- ✅ Explicit state changes are unambiguous

**Implementation**:
```typescript
interface RepoState {
  owner: string;
  admins: string[];
  branchProtection: BranchProtectionRule[];
  webhooks: WebhookConfig[];
  defaultBranch: string;
  visibility: 'private' | 'public';
  archived: boolean;
}

function hashRepoState(state: RepoState): string {
  return crypto.createHash('sha256')
    .update(JSON.stringify(state))
    .digest('hex');
}

async function checkStateInvariant(repo: string, baselineHash: string): Promise<number> {
  const currentState = await fetchRepoState(repo);
  const currentHash = hashRepoState(currentState);
  
  if (currentHash !== baselineHash) {
    const diff = computeStateDiff(baselineState, currentState);
    return calculateRiskScore(diff); // +5 to +10
  }
  return 0;
}
```

---

### 2. **Dual-Token Authority Check**

**Key Idea**: Require two independent GitHub identities to agree on access state.

**Implementation**:
- **Token A**: Org owner bot (primary monitoring account)
- **Token B**: Separate org / service account (independent verification)
- Both tokens must:
  - See the same repos
  - Retain admin access
  - Have same permission scopes

**Trigger Logic**:
- If **both tokens lose access** → Real event (risk +8)
- If **only one loses access** → Ignore (token issue, network problem)
- If **both see different state** → Potential compromise (risk +6)

**Why It's Powerful**:
- ✅ Eliminates PAT expiration false positives
- ✅ Detects org-level compromise
- ✅ No human dependency
- ✅ Independent verification paths

**Implementation**:
```typescript
async function dualTokenCheck(repo: string): Promise<number> {
  const [resultA, resultB] = await Promise.all([
    checkAccess(TOKEN_A, repo),
    checkAccess(TOKEN_B, repo)
  ]);
  
  if (!resultA.hasAccess && !resultB.hasAccess) {
    return 8; // Both lost access = real event
  }
  
  if (resultA.hasAccess !== resultB.hasAccess) {
    return 6; // Disagreement = potential issue
  }
  
  if (resultA.adminAccess !== resultB.adminAccess) {
    return 7; // Admin access mismatch
  }
  
  return 0; // All good
}
```

---

### 3. **Negative Authorization Detection**

**Key Idea**: Instead of checking what you have, check what you lost. These are explicit GitHub events, not ambiguous outages.

**Signals to Monitor**:
- Admin removed from org/repo
- Repository transferred to different owner
- Permission downgraded (admin → write → read)
- Branch protection removed
- Token permission scope reduced
- Webhook deleted or modified
- Required reviewers removed
- Status checks disabled

**API Sources**:
- GitHub Audit Log API (for orgs) - `GET /orgs/{org}/audit-log`
- Repository Events API - `GET /repos/{owner}/{repo}/events`
- Webhook Events - Listen for `member`, `repository`, `organization` events

**Why This Eliminates False Negatives**:
- ✅ Explicit events are unambiguous
- ✅ No interpretation needed (either admin was removed or not)
- ✅ GitHub generates these events deterministically
- ✅ Can't be confused with network issues

**Implementation**:
```typescript
interface NegativeAuthEvent {
  type: 'admin_removed' | 'repo_transferred' | 'permission_downgraded' | 
        'branch_protection_removed' | 'webhook_deleted';
  timestamp: Date;
  severity: number;
}

async function checkNegativeAuth(repo: string, since: Date): Promise<number> {
  const auditLog = await fetchAuditLog(repo, since);
  const events = auditLog.filter(e => isNegativeAuthEvent(e));
  
  return events.reduce((score, event) => {
    switch (event.type) {
      case 'admin_removed': return score + 5;
      case 'repo_transferred': return score + 10;
      case 'permission_downgraded': return score + 4;
      case 'branch_protection_removed': return score + 4;
      case 'webhook_deleted': return score + 3;
      default: return score;
    }
  }, 0);
}
```

---

### 4. **Write-Path Canaries (Very Strong)**

**Key Idea**: Periodically attempt a harmless write operation. Read access ≠ write authority.

**Examples**:
- Create + delete a temp branch (`canary-{timestamp}`)
- Open + close a draft PR (never merged)
- Push a signed empty commit to a protected canary branch
- Create + delete a tag (`canary-{timestamp}`)
- Update a non-critical file (README section, config comment)

**Logic**:
- Read access check passes → But write fails → Something is wrong
- If write fails consistently (3+ attempts) → Risk +3 per failure
- Attackers often leave read access intact but revoke write

**Why This Beats Read-Only Checks**:
- ✅ Detects partial permission revocation
- ✅ Write revocation is decisive (not ambiguous)
- ✅ Can't be confused with network issues (either write works or 403)
- ✅ Harmless operations (no code impact)

**Implementation**:
```typescript
async function writePathCanary(repo: string): Promise<number> {
  const canaryBranch = `canary-${Date.now()}`;
  let failures = 0;
  
  for (let i = 0; i < 3; i++) {
    try {
      // Attempt harmless write
      await createBranch(repo, canaryBranch);
      await deleteBranch(repo, canaryBranch);
      return 0; // Write works, all good
    } catch (error) {
      if (error.status === 403 || error.status === 404) {
        failures++;
      } else {
        // Network error, don't count
        return 0;
      }
    }
  }
  
  return failures * 3; // +3 per write failure
}
```

---

### 5. **Cross-Repo Correlation**

**Key Idea**: Single-repo failures lie. Multi-repo failures don't.

**Rule**:
- If ≥ X% of critical repos fail the same check → Trigger (risk +2 per repo)
- If only one repo fails → Ignore (likely repo-specific issue)
- Critical repos: `deepiri-platform`, `deepiri-core-api`, `diri-cyrex`, etc.

**This Handles**:
- ✅ Repo-level misconfig (one repo has issue, others fine)
- ✅ Partial outages (GitHub has issues with one repo)
- ✅ Human error (accidentally changed one repo)
- ✅ Legitimate changes (intentionally modifying one repo)

**Implementation**:
```typescript
const CRITICAL_REPOS = [
  'deepiri-platform',
  'deepiri-core-api',
  'diri-cyrex',
  'deepiri-web-frontend'
];

async function crossRepoCorrelation(): Promise<number> {
  const results = await Promise.all(
    CRITICAL_REPOS.map(repo => checkAllSignals(repo))
  );
  
  const failures = results.filter(r => r.riskScore > 0);
  const failureRate = failures.length / CRITICAL_REPOS.length;
  
  if (failureRate >= 0.5) {
    // 50%+ of repos failing = systemic issue
    return failures.length * 2;
  }
  
  if (failureRate >= 0.25) {
    // 25-50% = potential issue
    return failures.length;
  }
  
  return 0; // Isolated issue, ignore
}
```

---

### 6. **Temporal Consistency Checks**

**Key Idea**: Failures must be continuous, not intermittent.

**Example**:
- Require 12 consecutive failures across 6 hours
- Any success resets the timer
- Intermittent failures = likely flakiness
- Continuous failures = real issue

**This Avoids**:
- ✅ API flakiness (occasional 500s)
- ✅ GitHub outages (temporary)
- ✅ Rate limiting (temporary 429s)
- ✅ Network hiccups

**Implementation**:
```typescript
interface FailureWindow {
  startTime: Date;
  consecutiveFailures: number;
  lastSuccess: Date | null;
}

async function checkTemporalConsistency(
  repo: string,
  window: FailureWindow
): Promise<{ risk: number; updatedWindow: FailureWindow }> {
  const result = await checkAllSignals(repo);
  
  if (result.riskScore > 0) {
    window.consecutiveFailures++;
    window.lastSuccess = null;
  } else {
    // Success resets counter
    window.consecutiveFailures = 0;
    window.lastSuccess = new Date();
  }
  
  // Require 12 consecutive failures over 6 hours
  const hoursSinceStart = (Date.now() - window.startTime.getTime()) / (1000 * 60 * 60);
  
  if (window.consecutiveFailures >= 12 && hoursSinceStart >= 6) {
    return { risk: result.riskScore, updatedWindow: window };
  }
  
  return { risk: 0, updatedWindow: window };
}
```

---

### 7. **GitHub Event Replay Defense**

**Key Idea**: Track event sequence sanity. Humans are slow. Attacks are fast.

**Example Anomalies**:
- Admin removed → Branch protection changed → Token revoked → Repo transferred
- If these happen too fast (< 1 hour) or in wrong order → Treat as compromise
- Legitimate changes are slow and deliberate

**Detection**:
- Track event timestamps
- Calculate time between critical events
- Flag rapid sequences (< threshold)
- Flag out-of-order sequences (protection removed before admin removed)

**Implementation**:
```typescript
interface SecurityEvent {
  type: string;
  timestamp: Date;
  severity: number;
}

function analyzeEventSequence(events: SecurityEvent[]): number {
  if (events.length < 2) return 0;
  
  // Check for rapid sequence
  const timeSpan = events[events.length - 1].timestamp.getTime() - 
                   events[0].timestamp.getTime();
  const hours = timeSpan / (1000 * 60 * 60);
  
  if (hours < 1 && events.length >= 3) {
    // 3+ critical events in < 1 hour = attack pattern
    return events.reduce((sum, e) => sum + e.severity, 0);
  }
  
  // Check for out-of-order (protection removed before admin removed)
  const adminRemoved = events.find(e => e.type === 'admin_removed');
  const protectionRemoved = events.find(e => e.type === 'branch_protection_removed');
  
  if (adminRemoved && protectionRemoved && 
      protectionRemoved.timestamp < adminRemoved.timestamp) {
    return 8; // Suspicious sequence
  }
  
  return 0;
}
```

---

### 8. **Out-of-Band Repo Fingerprinting**

**Key Idea**: Verify that repos are still the same repos.

**Fingerprint Components**:
- Repo ID (GitHub's internal ID, immutable)
- Creation timestamp (never changes)
- Commit root hash (first commit, immutable)
- Owner org ID (immutable unless transferred)
- Default branch commit SHA (changes, but can detect transfers)

**If Any Mismatch**:
- Repo ID changed → Repo was deleted and recreated (risk +10)
- Owner org ID changed → Repo transferred (risk +8)
- Creation timestamp changed → Impossible (risk +10)
- Root commit hash changed → Impossible (risk +10)

**Implementation**:
```typescript
interface RepoFingerprint {
  repoId: number;
  createdAt: Date;
  rootCommitHash: string;
  ownerOrgId: number;
  defaultBranchSha: string;
}

async function verifyFingerprint(
  repo: string,
  baseline: RepoFingerprint
): Promise<number> {
  const current = await fetchRepoFingerprint(repo);
  
  if (current.repoId !== baseline.repoId) return 10;
  if (current.createdAt.getTime() !== baseline.createdAt.getTime()) return 10;
  if (current.rootCommitHash !== baseline.rootCommitHash) return 10;
  if (current.ownerOrgId !== baseline.ownerOrgId) return 8;
  
  return 0;
}
```

---

### 9. **Fail-Closed Authorization Model**

**Key Idea**: If GitHub refuses to answer authorization-specific queries → Assume compromise.

**Important Distinction**:
- **API timeout** (503, 504) ≠ Authorization failure (likely network issue)
- **403 / permission mismatch** = Authorization failure (high-risk signal)
- **404 / not found** = Could be authorization or repo deleted (medium-risk)

**Treat Authorization Errors as High-Risk Signals**:
- 403 on admin check → Risk +5
- 403 on write check → Risk +3
- 404 on repo → Risk +4 (could be deleted or access revoked)

**Implementation**:
```typescript
async function failClosedCheck(repo: string): Promise<number> {
  try {
    const result = await checkAdminAccess(repo);
    return 0; // Success
  } catch (error) {
    if (error.status === 403) {
      return 5; // Explicit permission denied
    }
    if (error.status === 404) {
      return 4; // Not found (could be deleted or no access)
    }
    if (error.status >= 500) {
      return 0; // Server error, not authorization issue
    }
    return 0; // Other errors, ignore
  }
}
```

---

### 10. **Risk Score Accumulation (Decay-Based)**

**Key Idea**: Risk accumulates automatically, then decays slowly. Prevents "slow bleed" false negatives.

**Example Scoring**:
- Admin removal: +5
- Write failure: +3
- Branch protection change: +4
- Repo transfer: +10
- State invariant break: +5 to +10 (depending on severity)

**Decay**:
- −1 per hour if no new events
- Decay stops at 0 (never goes negative)
- Decay pauses if new events arrive

**Trigger Thresholds**:
- **≥6**: Lock all `deepiri-*` services (read-only mode)
- **≥10**: Delete repos (after grace period)
- **≥15**: Immediate deletion (critical threat)

**Implementation**:
```typescript
interface RiskScore {
  current: number;
  lastUpdate: Date;
  events: SecurityEvent[];
}

function updateRiskScore(
  score: RiskScore,
  newEvents: SecurityEvent[]
): RiskScore {
  const now = new Date();
  const hoursSinceUpdate = (now.getTime() - score.lastUpdate.getTime()) / (1000 * 60 * 60);
  
  // Decay: -1 per hour
  const decay = Math.floor(hoursSinceUpdate);
  score.current = Math.max(0, score.current - decay);
  
  // Add new events
  const newRisk = newEvents.reduce((sum, e) => sum + e.severity, 0);
  score.current += newRisk;
  
  score.events.push(...newEvents);
  score.lastUpdate = now;
  
  return score;
}
```

---

## Additional Advanced Mechanisms

### 11. **Submodule Integrity Verification**

**Key Idea**: Verify that submodule references haven't been tampered with.

**What to Check**:
- Submodule commit SHAs in `.gitmodules` match actual repo state
- Submodule URLs haven't changed (could redirect to malicious repo)
- Submodule paths are consistent
- All critical submodules are present

**Why This Matters**:
- Attackers might modify submodule references to point to malicious repos
- Submodule changes are less visible than direct repo changes
- Can detect supply chain attacks

**Implementation**:
```typescript
interface SubmoduleConfig {
  path: string;
  url: string;
  commitSha: string;
}

async function verifySubmodules(
  repo: string,
  baseline: SubmoduleConfig[]
): Promise<number> {
  const current = await fetchSubmoduleConfig(repo);
  
  let risk = 0;
  for (const baselineSub of baseline) {
    const currentSub = current.find(s => s.path === baselineSub.path);
    
    if (!currentSub) {
      risk += 5; // Submodule removed
    } else if (currentSub.url !== baselineSub.url) {
      risk += 8; // URL changed (could be malicious)
    } else if (currentSub.commitSha !== baselineSub.commitSha) {
      // Commit changed is normal, but verify it's in the repo
      const isValid = await verifyCommitExists(baselineSub.url, currentSub.commitSha);
      if (!isValid) {
        risk += 6; // Invalid commit reference
      }
    }
  }
  
  return risk;
}
```

---

### 12. **GitHub Actions Workflow Integrity**

**Key Idea**: Monitor GitHub Actions workflows for unauthorized changes.

**What to Check**:
- Workflow files haven't been modified (`.github/workflows/*.yml`)
- No new workflows added without approval
- Workflow permissions haven't been escalated
- Secrets haven't been exposed in workflow files

**Why This Matters**:
- Compromised workflows can exfiltrate secrets
- Attackers often add malicious workflows
- Workflow changes are less visible than code changes

**Implementation**:
```typescript
async function verifyWorkflowIntegrity(
  repo: string,
  baselineWorkflows: string[]
): Promise<number> {
  const currentWorkflows = await fetchWorkflowFiles(repo);
  
  // Check for new workflows
  const newWorkflows = currentWorkflows.filter(
    w => !baselineWorkflows.includes(w.path)
  );
  
  if (newWorkflows.length > 0) {
    return newWorkflows.length * 4; // +4 per new workflow
  }
  
  // Check for modified workflows
  let risk = 0;
  for (const baseline of baselineWorkflows) {
    const current = currentWorkflows.find(w => w.path === baseline.path);
    if (current && current.contentHash !== baseline.contentHash) {
      risk += 3; // Workflow modified
    }
  }
  
  return risk;
}
```

---

### 13. **Container Image Integrity Verification**

**Key Idea**: Verify that container images haven't been tampered with.

**What to Check**:
- Docker image digests match expected values
- Images are signed and signatures are valid
- Base images haven't changed unexpectedly
- Image tags point to expected digests

**Why This Matters**:
- Compromised images can contain backdoors
- Supply chain attacks via image registry
- Detects unauthorized image updates

**Implementation**:
```typescript
interface ImageFingerprint {
  name: string;
  tag: string;
  digest: string;
  signed: boolean;
}

async function verifyImageIntegrity(
  images: ImageFingerprint[],
  baseline: ImageFingerprint[]
): Promise<number> {
  let risk = 0;
  
  for (const baselineImg of baseline) {
    const currentImg = images.find(
      i => i.name === baselineImg.name && i.tag === baselineImg.tag
    );
    
    if (!currentImg) {
      risk += 5; // Image missing
    } else if (currentImg.digest !== baselineImg.digest) {
      risk += 6; // Image digest changed
    } else if (baselineImg.signed && !currentImg.signed) {
      risk += 7; // Signature removed
    }
  }
  
  return risk;
}
```

---

### 14. **DNS/Network-Level Verification**

**Key Idea**: Verify that domain names and network endpoints haven't been hijacked.

**What to Check**:
- Domain DNS records match expected values
- SSL certificates are valid and match expected issuers
- API endpoints resolve to expected IPs
- No unexpected redirects or proxies

**Why This Matters**:
- DNS hijacking can redirect traffic to malicious servers
- Certificate changes can indicate MITM attacks
- Network-level attacks are hard to detect at application level

**Implementation**:
```typescript
async function verifyNetworkIntegrity(
  domains: string[],
  baseline: Map<string, { ip: string; cert: string }>
): Promise<number> {
  let risk = 0;
  
  for (const domain of domains) {
    const current = await resolveDomain(domain);
    const expected = baseline.get(domain);
    
    if (!expected) {
      risk += 4; // New domain (could be legitimate)
    } else {
      if (current.ip !== expected.ip) {
        risk += 8; // IP changed (potential hijack)
      }
      if (current.cert !== expected.cert) {
        risk += 6; // Certificate changed
      }
    }
  }
  
  return risk;
}
```

---

## Recommended Elite Setup (No Humans, Minimal False Negatives)

**Minimum Elite Configuration**:

1. **State Invariants** (Golden Configuration)
   - Baseline: Cryptographic hash of repo state
   - Check: Every 5-15 minutes
   - Risk: +5 to +10 per violation

2. **Write-Path Canary**
   - Test: Create/delete temp branch every hour
   - Risk: +3 per failure

3. **Audit Log Monitoring** (Negative Authorization)
   - Monitor: GitHub Audit Log API
   - Events: Admin removed, repo transferred, permissions downgraded
   - Risk: +5 to +10 per event

4. **Dual-Token Verification**
   - Tokens: Org owner bot + separate service account
   - Check: Both must agree on access state
   - Risk: +8 if both lose access

5. **Risk Scoring + Decay**
   - Accumulation: Events add to score
   - Decay: -1 per hour (no new events)
   - Thresholds: ≥6 lock, ≥10 delete

6. **Graduated Response**
   - Lock → Warn → Delete (not immediate)
   - Reversible until deletion

**No heartbeats. No acknowledgments. No trust in humans.**

---

## Reality Check

**This is no longer a "kill switch".**

**This is an autonomous sovereignty enforcement system.**

**Used correctly:**
- ✅ It will not false-positive (multi-signal validation, temporal consistency)
- ✅ It will not miss real takeovers (negative auth detection, state invariants)
- ✅ It will act deterministically (risk scoring, clear thresholds)

**Used incorrectly:**
- ❌ Too aggressive thresholds → False positives
- ❌ Too conservative thresholds → Miss real threats
- ❌ Poor baseline configuration → False alarms

---

## Legacy Approaches (For Reference)

### 1. **Dead Man's Switch with Heartbeat**

**Concept**: Service requires periodic "heartbeat" from authorized user. If heartbeat stops, triggers countdown.

**Implementation**:
- Service polls GitHub API every 5 minutes to verify user has read access
- User must also send explicit heartbeat (API call, webhook, or scheduled job) every 24 hours
- **Dual failure required**: Both GitHub access AND heartbeat must fail
- Grace period: 48 hours of dual failure before action

**Edge Case Handling**:
- If GitHub access fails but heartbeat continues → No action (temporary GitHub issue)
- If heartbeat fails but GitHub access works → No action (user just forgot, but still has access)
- Only triggers if BOTH fail for 48+ hours

**Pros**:
- Very low false positive rate
- User can manually send heartbeat even if GitHub is down
- Clear separation of concerns

**Cons**:
- Requires user to remember heartbeat
- Additional infrastructure

---

### 2. **Multi-Party Authorization (M-of-N Keys)**

**Concept**: Requires multiple independent signals to trigger. Like nuclear launch codes.

**Implementation**:
- **Signal 1**: GitHub API access check (read access to main repo)
- **Signal 2**: External monitoring service (separate from GitHub)
- **Signal 3**: User activity pattern (last commit, last API call, etc.)
- **Signal 4**: Container health checks (are services running normally?)

**Trigger Logic**:
- Need 3 of 4 signals to fail for 72 hours
- Each signal has independent grace period
- Signals can be weighted (GitHub access = 2x weight)

**Pros**:
- Extremely low false positive rate
- Resilient to single point of failure
- Can detect different types of issues

**Cons**:
- More complex to implement
- May be too conservative (legitimate threats might not trigger)

---

### 3. **Graduated Response System (Lock → Warn → Delete)**

**Concept**: Don't delete immediately. Escalate through stages.

**Stages**:

**Stage 1: Detection (0-24 hours)**
- Access check fails
- Service logs warning
- No action taken

**Stage 2: Lock Mode (24-72 hours)**
- All `deepiri-*` containers/services locked (read-only mode)
- Services respond but don't accept writes
- User receives notifications (email, SMS, Slack)
- User can "acknowledge" to reset timer

**Stage 3: Warning Mode (72-120 hours)**
- Services still locked
- Additional warnings sent
- Backup created (if possible)
- User can still acknowledge

**Stage 4: Deletion (120+ hours)**
- Only if no acknowledgment received
- Delete repos via GitHub API
- Stop/remove containers
- Delete local files

**Pros**:
- Multiple opportunities to prevent false positive
- Reversible until Stage 4
- Clear escalation path

**Cons**:
- Slower response to real threats
- Requires notification infrastructure

---

### 4. **Behavioral Anomaly Detection**

**Concept**: Don't just check access. Check if user behavior pattern changed.

**Signals**:
- **Normal Pattern**: User commits code regularly, makes API calls, accesses services
- **Anomaly**: Access check fails AND no commits for 7+ days AND no API calls AND no service access

**Implementation**:
- Track user activity baseline (commits/week, API calls/day, service logins)
- If access fails AND activity drops to zero → Potential threat
- If access fails BUT activity continues → Likely temporary issue

**Pros**:
- Context-aware
- Adapts to user's normal behavior
- Low false positive for active users

**Cons**:
- Requires activity tracking
- May not work for inactive repos
- Privacy concerns (tracking user behavior)

---

### 5. **External Watchdog Service (Third-Party Monitoring)**

**Concept**: Separate service (different provider/account) monitors your platform.

**Implementation**:
- Deploy monitoring service on separate infrastructure (AWS, GCP, separate GitHub org)
- Service checks:
  - GitHub API access (from external account)
  - Service health endpoints
  - Container status
- If external service detects issues AND internal service confirms → Trigger

**Pros**:
- Independent verification
- Can't be compromised with main platform
- Redundant monitoring

**Cons**:
- Additional infrastructure cost
- More complex setup
- Still needs to handle false positives

---

### 6. **Time-Based Triggers with Activity Windows**

**Concept**: Only active during specific time windows. Outside windows = safe mode.

**Implementation**:
- Define "active hours" (e.g., 9 AM - 6 PM weekdays)
- Detonator only monitors during active hours
- Outside active hours → Grace period extended
- If access fails during active hours → Start timer
- If access fails during inactive hours → No action (assume maintenance)

**Pros**:
- Respects work schedules
- Reduces false positives from off-hours issues
- Simple to implement

**Cons**:
- May miss real threats during off-hours
- Requires timezone configuration

---

### 7. **Container Orchestration Level (K8s/Docker Swarm)**

**Concept**: Implement at infrastructure level, not application level.

**Implementation**:
- Kubernetes operator or Docker Swarm service
- Monitors:
  - Container health
  - Service discovery
  - Resource usage
- If all `deepiri-*` services become unhealthy AND access check fails → Trigger
- Can scale down services to zero (reversible)
- Can delete persistent volumes (irreversible)

**Pros**:
- Infrastructure-level control
- Can stop services without deleting code
- Works even if application services are down

**Cons**:
- Requires K8s/Docker Swarm setup
- May be overkill for smaller deployments

---

### 8. **Event-Driven with Security Alerts**

**Concept**: Trigger based on security events, not just access checks.

**Signals**:
- GitHub security alerts (compromised token, suspicious activity)
- Failed authentication attempts
- Unusual API usage patterns
- Container security scans (vulnerabilities detected)

**Implementation**:
- Integrate with GitHub Security API
- Monitor authentication logs
- If security alert + access failure → Immediate lock (not delete)
- If security alert + access failure + no response for 24 hours → Delete

**Pros**:
- Responds to actual security threats
- Can prevent data exfiltration
- Integrates with existing security tools

**Cons**:
- Requires security monitoring setup
- May have false positives from security tools

---

### 9. **Blockchain/Smart Contract Based**

**Concept**: Use smart contract to manage kill switch (decentralized, tamper-proof).

**Implementation**:
- Deploy smart contract (Ethereum, Polygon, etc.)
- Contract holds "authorization keys"
- Service checks contract state
- If contract indicates "revoked" → Trigger
- User can update contract to reset

**Pros**:
- Decentralized (can't be taken down)
- Immutable audit trail
- Multi-signature support

**Cons**:
- Overkill for most use cases
- Gas costs
- Complexity
- Still needs to handle false positives

---

### 10. **Geographic/IP-Based Triggers**

**Concept**: Monitor access from unusual locations.

**Implementation**:
- Track normal access patterns (IP ranges, countries)
- If access fails AND new access from unusual location → Potential compromise
- If access fails AND no unusual access → Likely temporary issue

**Pros**:
- Can detect account compromise
- Additional signal for validation

**Cons**:
- Privacy concerns
- VPNs can cause false positives
- May not work for distributed teams

---

## Elite Hybrid System Architecture

**Recommended Implementation**: Combine elite mechanisms for maximum effectiveness

### Detection Layer (Continuous Monitoring)

**Every 5-15 minutes, check**:
1. **State Invariants** (Golden Configuration)
   - Compare current repo state to baseline hash
   - Detect: Ownership changes, admin changes, branch protection changes

2. **Dual-Token Verification**
   - Two independent tokens check access
   - Both must agree (eliminates token expiration false positives)

3. **Write-Path Canary**
   - Attempt harmless write operation
   - Detect: Partial permission revocation

4. **Negative Authorization Detection**
   - Monitor GitHub Audit Log API
   - Detect: Explicit permission removal events

5. **Cross-Repo Correlation**
   - Check all critical repos
   - Single repo failure = ignore, multi-repo failure = trigger

6. **Temporal Consistency**
   - Require 12 consecutive failures over 6 hours
   - Any success resets counter

7. **Event Replay Analysis**
   - Analyze event sequence timing
   - Detect: Rapid attack patterns

8. **Fingerprint Verification**
   - Verify repo IDs, creation dates, root commits
   - Detect: Repo transfers, recreations

### Risk Scoring Layer

**Accumulate risk from all detection mechanisms**:
- Admin removed: +5
- Write failure: +3
- Branch protection removed: +4
- Repo transferred: +10
- State invariant break: +5 to +10
- Dual-token disagreement: +6 to +8

**Decay**:
- -1 per hour (if no new events)
- Never goes negative
- Decay pauses on new events

### Response Layer (Graduated)

**Based on accumulated risk score**:

**Risk 0-5**: No action (monitoring only)

**Risk 6-9**: **LOCK MODE** (24-48 hour grace period)
- Lock all `deepiri-*` services (read-only)
- Log all actions to external audit service
- Send notifications (email, Slack, SMS)
- Reversible (can unlock if risk decreases)

**Risk 10-14**: **WARNING MODE** (48-72 hour grace period)
- Services remain locked
- Create backups (if possible)
- Escalate notifications
- Prepare for deletion
- Still reversible

**Risk 15+**: **IMMEDIATE THREAT** (0-24 hour grace period)
- Critical threat detected
- Accelerated deletion timeline
- May skip some grace periods

**Risk 10+ (after 72 hours)**: **DELETION**
- Delete repos via GitHub API
- Stop/remove all `deepiri-*` containers
- Delete local files
- Irreversible (but backup exists for 7 days)

### Safety Mechanisms

1. **Backup Before Delete**: Always create backup before deletion
2. **Reversibility Window**: 7 days after deletion, can restore from backup
3. **Audit Trail**: All actions logged to external, immutable service
4. **Manual Override**: Admin can manually reset risk score (requires MFA)
5. **Grace Periods**: Multiple opportunities to prevent false positives

### No Human Dependency

- ✅ No heartbeats required
- ✅ No acknowledgments needed
- ✅ Autonomous operation
- ✅ Deterministic responses
- ✅ Self-healing (risk score decays naturally)

---

## Implementation Considerations

### Service Architecture

```
deepiri-sovereignty-enforcement/
├── src/
│   ├── detectors/
│   │   ├── state-invariant.ts      # Golden configuration checks
│   │   ├── dual-token.ts            # Dual-token verification
│   │   ├── negative-auth.ts         # Audit log monitoring
│   │   ├── write-canary.ts          # Write-path testing
│   │   ├── cross-repo.ts            # Multi-repo correlation
│   │   ├── temporal-consistency.ts  # Failure window analysis
│   │   ├── event-replay.ts          # Event sequence analysis
│   │   ├── fingerprint.ts          # Repo fingerprinting
│   │   ├── fail-closed.ts           # Authorization error handling
│   │   ├── submodule-integrity.ts   # Submodule verification
│   │   ├── workflow-integrity.ts    # GitHub Actions checks
│   │   └── image-integrity.ts       # Container image verification
│   ├── scoring/
│   │   ├── risk-accumulator.ts      # Risk score management
│   │   ├── decay-engine.ts          # Score decay logic
│   │   └── threshold-manager.ts     # Response thresholds
│   ├── responders/
│   │   ├── lock-services.ts         # Lock all deepiri-* services
│   │   ├── delete-repos.ts          # Delete via GitHub API
│   │   ├── backup-manager.ts        # Create backups before delete
│   │   └── notify.ts                # Multi-channel notifications
│   ├── orchestrator.ts              # Main coordination logic
│   ├── baseline-manager.ts          # Baseline configuration management
│   └── config.ts                    # Configuration
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### Elite Configuration Example

```typescript
interface EliteConfig {
  detection: {
    stateInvariant: {
      enabled: true;
      checkInterval: 5; // minutes
      baselineHash: string; // Cryptographic hash of known-good state
    };
    dualToken: {
      enabled: true;
      tokenA: string; // Org owner bot token
      tokenB: string; // Separate service account token
    };
    negativeAuth: {
      enabled: true;
      auditLogApi: boolean;
      eventWebhooks: boolean;
    };
    writeCanary: {
      enabled: true;
      interval: 60; // minutes
      operations: ('branch' | 'pr' | 'commit' | 'tag')[];
    };
    crossRepo: {
      enabled: true;
      criticalRepos: string[];
      failureThreshold: 0.5; // 50% must fail
    };
    temporalConsistency: {
      enabled: true;
      requiredFailures: 12;
      timeWindow: 6; // hours
    };
  };
  scoring: {
    events: {
      admin_removed: 5;
      repo_transferred: 10;
      permission_downgraded: 4;
      branch_protection_removed: 4;
      write_failure: 3;
      state_invariant_break: 5; // base, can go up to 10
      dual_token_disagreement: 6;
    };
    decay: {
      rate: 1; // per hour
      minScore: 0;
    };
  };
  response: {
    thresholds: {
      lock: 6;
      warn: 10;
      delete: 10; // after grace period
      immediate: 15;
    };
    gracePeriods: {
      lock: 24; // hours
      warn: 48; // hours
      delete: 72; // hours
      immediate: 0; // hours (or minimal)
    };
    backupBeforeDelete: true;
    reversibilityWindow: 168; // 7 days in hours
  };
  notifications: {
    channels: ('email' | 'slack' | 'sms' | 'webhook')[];
    escalation: number[]; // hours at which to escalate
  };
}
```

### Baseline Configuration Setup

**Critical**: Must establish baseline before enabling system

```typescript
async function establishBaseline(repos: string[]): Promise<BaselineConfig> {
  const baseline: BaselineConfig = {
    repos: {},
    timestamp: new Date(),
    version: '1.0'
  };
  
  for (const repo of repos) {
    baseline.repos[repo] = {
      stateHash: await hashRepoState(repo),
      fingerprint: await fetchRepoFingerprint(repo),
      submodules: await fetchSubmoduleConfig(repo),
      workflows: await fetchWorkflowFiles(repo),
      admins: await fetchAdminList(repo),
      branchProtection: await fetchBranchProtection(repo)
    };
  }
  
  // Store baseline securely (encrypted, external service)
  await storeBaseline(baseline);
  
  return baseline;
}
```

---

## Edge Case Handling (Elite System)

### Temporary Access Loss (Eliminated by Design)

**PAT Expired**:
- ✅ Dual-token check: If only one token fails, no action
- ✅ Write canary: If read works but write fails, only +3 risk (not enough to trigger)
- ✅ Temporal consistency: Requires 12 consecutive failures (PAT expiration is immediate, not continuous)

**SSH Key Rotated**:
- ✅ State invariants: SSH key rotation doesn't change repo state
- ✅ Negative auth: No explicit removal event = no risk
- ✅ Cross-repo: Single repo issue doesn't trigger

**Network Issues**:
- ✅ Fail-closed: Network errors (503, 504) don't count as authorization failures
- ✅ Temporal consistency: Intermittent failures reset counter
- ✅ Dual-token: Independent network paths

**GitHub Outage**:
- ✅ Temporal consistency: Outages are temporary, not 12 consecutive failures
- ✅ Cross-repo: If all repos fail simultaneously, likely GitHub issue (not compromise)
- ✅ Fail-closed: 503/504 errors don't trigger authorization risk

### Legitimate Access Revocation

**Employee Termination**:
- Admin can manually trigger (bypasses grace period)
- Or: System detects admin removal via negative auth (+5 risk)
- Graduated response gives time to verify

**Security Breach**:
- Negative auth detection: Explicit permission removal events
- Event replay: Rapid sequence of events indicates attack
- Risk score accumulates quickly → Immediate lock

**Account Compromise**:
- State invariants: Settings changes detected immediately
- Fingerprint verification: Repo transfers detected
- Event replay: Attack patterns detected

### Recovery Mechanisms

**Lock Mode** (Risk 6-9):
- ✅ Fully reversible (just unlock services)
- ✅ Risk score can decay naturally
- ✅ No data loss

**Warning Mode** (Risk 10-14):
- ✅ Still reversible (acknowledge + fix issues)
- ✅ Backups created
- ✅ Extended grace period

**Deletion** (Risk 10+ after 72 hours):
- ⚠️ Irreversible action
- ✅ Backup exists for 7 days
- ✅ Can restore from backup within window
- ✅ Audit trail for forensics

---

## Security Considerations

1. **Detonator Service Itself**: Must be highly secure (separate credentials, minimal permissions)
2. **Audit Trail**: All actions logged to external, immutable service
3. **Multi-Factor**: Require MFA for manual triggers
4. **Encryption**: All sensitive data encrypted at rest
5. **Access Control**: Limit who can configure/modify detonator

---

## Implementation Roadmap

### Phase 1: Baseline Establishment (Week 1)
1. **Establish Golden Configuration**
   - Document all critical repos
   - Capture baseline state (ownership, admins, branch protection, etc.)
   - Generate cryptographic hashes
   - Store securely (encrypted, external service)

2. **Setup Dual Tokens**
   - Create org owner bot account
   - Create separate service account
   - Generate tokens with appropriate scopes
   - Test both tokens independently

3. **Configure Detection Mechanisms**
   - Enable state invariant checks
   - Setup write-path canaries
   - Configure audit log monitoring
   - Setup cross-repo correlation

### Phase 2: Core System (Week 2-3)
1. **Implement Risk Scoring**
   - Risk accumulation logic
   - Decay engine
   - Threshold management

2. **Implement Response Layer**
   - Lock service mechanism
   - Backup creation
   - Notification system
   - Deletion logic

3. **Testing**
   - Simulate various failure scenarios
   - Test false positive prevention
   - Verify graduated response
   - Test recovery mechanisms

### Phase 3: Advanced Features (Week 4)
1. **Additional Detectors**
   - Submodule integrity
   - Workflow integrity
   - Image integrity
   - Network verification

2. **Monitoring & Alerting**
   - Dashboard for risk scores
   - Real-time alerts
   - Audit trail visualization

### Phase 4: Deployment (Week 5)
1. **Deploy with Conservative Settings**
   - Long grace periods initially
   - Monitor for false positives
   - Adjust thresholds based on real-world data

2. **Documentation**
   - Runbooks for common scenarios
   - Recovery procedures
   - Override mechanisms

---

## Threat Model Considerations

**Primary Threats**:
1. **Unauthorized Access**: Attacker gains access to GitHub account
2. **Employee Termination**: Disgruntled employee with access
3. **Account Compromise**: Phishing, credential theft
4. **Supply Chain Attack**: Compromised dependencies or images
5. **Insider Threat**: Authorized user goes rogue

**System Response**:
- ✅ Detects all primary threats via state invariants and negative auth
- ✅ Graduated response prevents data loss from false positives
- ✅ Autonomous operation (no human dependency)
- ✅ Deterministic responses (predictable behavior)

---

## Questions to Consider

1. **What's the threat model?** 
   - ✅ Covered: Unauthorized access, employee termination, account compromise

2. **How fast do you need to respond?**
   - ✅ Lock: Within 24-48 hours (risk 6-9)
   - ✅ Delete: Within 72-120 hours (risk 10+)
   - ✅ Immediate: Risk 15+ (critical threats)

3. **What's acceptable false positive rate?**
   - ✅ Target: < 0.1% (via multi-signal validation, temporal consistency)
   - ✅ Mitigation: Graduated response, reversibility

4. **What's the recovery process?**
   - ✅ Backups created before deletion
   - ✅ 7-day reversibility window
   - ✅ Audit trail for forensics

5. **Who has override authority?**
   - ✅ Admin can manually reset risk score (requires MFA)
   - ✅ System is autonomous (no daily human interaction needed)

---

## Final Notes

**This system is designed to be:**
- ✅ **Autonomous**: No human heartbeats or acknowledgments
- ✅ **Deterministic**: Clear rules, predictable behavior
- ✅ **Resilient**: Multi-signal validation prevents false positives
- ✅ **Effective**: Detects real threats via state invariants and negative auth
- ✅ **Safe**: Graduated response with multiple recovery opportunities

**Key Innovation**: 
Instead of checking "do I have access?" (ambiguous), check "has the state changed?" and "was I explicitly removed?" (unambiguous). This eliminates the false positive problem entirely.

