
# External Requirements for the ASES Detonator (ASED)

**Detonator / Autonomous Sovereignty Enforcement System**

This is a complete list of **everything that must be configured outside the codebase** for the system you designed to function correctly and safely.

---

## 1. GitHub (CRITICAL)

### 1.1 GitHub Organization
You **must** have:
- ✅ A GitHub **Organization** (not personal repos)
- ✅ Org **Owner** privileges
- ✅ Access to the **Audit Log API**

Without org-level access, several detectors will not function.

---

### 1.2 Dual GitHub Tokens (Independent Identities)

You need **two separate GitHub identities**, not just two tokens.

#### Token A — Primary Authority
- Account: Org owner **bot/service account**
- Required scopes:
  - `repo` (full)
  - `admin:org`
  - `read:audit_log`
  - `workflow`
- Used for:
  - State invariant checks
  - Write-path canaries
  - Lock & delete actions

#### Token B — Independent Verifier
- Account: Different user or bot
- Required scopes:
  - `repo` (read-only is sufficient)
  - `read:org`
- Used for:
  - Revocation detection
  - Eliminating PAT expiration false positives

⚠️ **Do NOT**
- Use two tokens from the same account  
- Use GitHub Actions tokens  

---

### 1.3 GitHub Audit Log API
You must confirm access to:

```

GET /orgs/{org}/audit-log

```

Required event coverage:
- `org.remove_member`
- `repo.remove_member`
- `repo.transfer`
- `org.update_member`
- `protected_branch.destroy`
- `oauth_authorization.destroy`

If audit logs are unavailable → **negative-authorization detection fails**.

---

### 1.4 GitHub Webhooks (Strongly Recommended)
Create an **org-level webhook**.

**Events:**
- Repository
- Organization
- Member
- Team
- Push
- Workflow run

**Destination:**
```

POST /webhook/github

```

Purpose:
- Faster detection
- Event replay analysis
- Reduced API polling

---

### 1.5 Canary Branch Configuration
Ensure:
- Branch creation is allowed
- Canary branch pattern (e.g. `canary/*`) is:
  - Excluded from strict protection rules **OR**
  - Explicitly whitelisted

Otherwise, the write-canary detector will false-positive.

---

## 2. External Storage

### 2.1 Baseline Storage (Immutable & Encrypted)

You must provide **one**:
- S3 (versioning + object lock)
- GCS (retention policy)
- Azure Blob (immutable)
- Encrypted external KV store

**Required properties:**
- 🔒 Encryption at rest
- 🧾 Versioning
- ❌ No overwrite
- 🔐 Restricted credentials

Used for:
- Golden repo state
- Fingerprints
- Admin lists
- Branch protection rules

---

### 2.2 Audit Log Storage (Write-Only)
Must be **separate** from baseline storage.

Requirements:
- Append-only
- No delete access from service
- Timestamped entries
- External if possible

Examples:
- CloudWatch Logs
- Loki
- Elastic
- Datadog
- Custom write-only API

If the detonator is compromised, **audit logs must survive**.

---

## 3. Notifications Infrastructure

At least **one channel is mandatory**:

- Email (SMTP or provider)
- Slack Incoming Webhook
- SMS (Twilio or equivalent)

Used for:
- Lock notifications
- Warning escalation
- Deletion notices
- Post-incident reports

Even autonomous systems require notification for legal and audit reasons.

---

## 4. Platform / Infrastructure Permissions

### 4.1 Lock Capability (MANDATORY)
The service must be able to:
- Scale services to zero
- Enable read-only mode
- Disable write APIs
- Freeze CI/CD pipelines (optional)

Depending on platform:
- Kubernetes RBAC
- Docker socket
- Internal admin APIs

If this is missing → **lock stage is ineffective**.

---

### 4.2 Delete Capability (EXTREMELY RESTRICTED)
Only Token A should be able to:
- Delete or archive repos
- Remove secrets
- Stop containers permanently

Best practice:
- Separate deletion credentials
- Load only at delete stage

---

## 5. Scheduling & Time

You must have **one reliable scheduler**:
- `node-cron` (in container)
- Kubernetes CronJob
- Cloud Scheduler (recommended)

Guarantees:
- Detector execution consistency
- Valid temporal consistency & decay logic

Clock drift will break risk scoring.

---

## 6. GitHub Rate Limit Planning

Confirm:
- 5,000 requests/hour per token
- Polling intervals respect limits

Recommended:
- Token A: heavy usage
- Token B: light verification
- Webhooks to reduce polling

---

## 7. Legal / Organizational Preconditions

Strongly recommended (protects you, not the code):

- ✔️ Written authorization for automated deletion
- ✔️ Defined backup ownership
- ✔️ Incident response reference
- ✔️ Approval for autonomous action

---

## 8. One-Time Manual Setup Actions

These are **one-time only**:

1. Create two GitHub bot accounts
2. Generate & store tokens securely
3. Configure org webhook
4. Establish baseline via CLI
5. Verify audit log access
6. Test canary branch creation
7. Dry-run lock mode
8. Dry-run restore from backup

After this → **no human intervention required**.

---

## 🔥 Minimal Required Setup (Absolute Floor)

To function safely:

- ✅ GitHub org with audit logs
- ✅ Two independent GitHub tokens
- ✅ Immutable baseline storage
- ✅ Write-only audit logs
- ✅ One notification channel
- ✅ Permission to lock & delete infra

Everything else improves safety, speed, and auditability.
```
