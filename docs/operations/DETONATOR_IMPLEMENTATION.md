# Detonator System Implementation Plan

**Project**: Autonomous Sovereignty Enforcement System  
**Location**: `platform-services/backend/deepiri-sovereignty-enforcement-service/`  
**Timeline**: 5 weeks  
**Status**: Planning Phase

---

## Table of Contents

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Phase 1: Foundation & Baseline](#phase-1-foundation--baseline)
4. [Phase 2: Core Detection Mechanisms](#phase-2-core-detection-mechanisms)
5. [Phase 3: Risk Scoring & Response](#phase-3-risk-scoring--response)
6. [Phase 4: Advanced Features](#phase-4-advanced-features)
7. [Phase 5: Testing & Deployment](#phase-5-testing--deployment)
8. [Technical Requirements](#technical-requirements)
9. [Dependencies](#dependencies)
10. [Configuration Management](#configuration-management)
11. [Security Considerations](#security-considerations)
12. [Monitoring & Observability](#monitoring--observability)
13. [Rollback Plan](#rollback-plan)

---

## Overview

This document outlines the step-by-step implementation plan for the Autonomous Sovereignty Enforcement System (Detonator). The system will autonomously monitor GitHub repository states and respond to unauthorized access or configuration changes.

### Key Objectives

- Implement state invariant enforcement (golden configuration)
- Deploy dual-token verification system
- Build negative authorization detection
- Create write-path canary testing
- Implement risk scoring with decay
- Build graduated response system (lock -> warn -> delete)
- Achieve zero false positives through multi-signal validation

### Success Criteria

- System operates autonomously without human intervention
- False positive rate < 0.1%
- Detection latency < 15 minutes for critical changes
- Response time: Lock within 24-48 hours, Delete within 72-120 hours
- All actions are logged and auditable
- System is reversible until deletion phase

---

## Project Structure

```
platform-services/backend/deepiri-sovereignty-enforcement-service/
├── src/
│   ├── detectors/
│   │   ├── state-invariant.ts
│   │   ├── dual-token.ts
│   │   ├── negative-auth.ts
│   │   ├── write-canary.ts
│   │   ├── cross-repo.ts
│   │   ├── temporal-consistency.ts
│   │   ├── event-replay.ts
│   │   ├── fingerprint.ts
│   │   ├── fail-closed.ts
│   │   ├── submodule-integrity.ts
│   │   ├── workflow-integrity.ts
│   │   └── image-integrity.ts
│   ├── scoring/
│   │   ├── risk-accumulator.ts
│   │   ├── decay-engine.ts
│   │   └── threshold-manager.ts
│   ├── responders/
│   │   ├── lock-services.ts
│   │   ├── delete-repos.ts
│   │   ├── backup-manager.ts
│   │   └── notify.ts
│   ├── baseline/
│   │   ├── baseline-manager.ts
│   │   ├── baseline-storage.ts
│   │   └── baseline-validator.ts
│   ├── github/
│   │   ├── github-client.ts
│   │   ├── github-api.ts
│   │   └── github-types.ts
│   ├── storage/
│   │   ├── state-store.ts
│   │   ├── event-store.ts
│   │   └── audit-log.ts
│   ├── orchestrator.ts
│   ├── scheduler.ts
│   ├── config.ts
│   └── server.ts
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── scripts/
│   ├── establish-baseline.ts
│   ├── test-detection.ts
│   └── simulate-failure.ts
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── .env.example
├── package.json
├── tsconfig.json
├── jest.config.js
└── README.md
```

---

## Phase 1: Foundation & Baseline

**Duration**: Week 1  
**Goal**: Establish project structure, GitHub integration, and baseline configuration

### Day 1-2: Project Setup

**Tasks**:
1. Create service directory structure
2. Initialize Node.js/TypeScript project
3. Setup build configuration (tsconfig.json, package.json)
4. Configure Docker container
5. Setup testing framework (Jest)
6. Create environment variable templates

**Deliverables**:
- Service directory created
- TypeScript configuration
- Dockerfile
- Basic server.ts with health check endpoint
- .env.example with all required variables

**Code Structure**:
```typescript
// src/server.ts
import express from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('sovereignty-enforcement');
const app = express();

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'sovereignty-enforcement' });
});

const PORT = process.env.PORT || 5010;
app.listen(PORT, () => {
  logger.info(`Sovereignty Enforcement Service started on port ${PORT}`);
});
```

### Day 3-4: GitHub API Integration

**Tasks**:
1. Create GitHub API client wrapper
2. Implement authentication for dual tokens
3. Create type definitions for GitHub API responses
4. Implement rate limiting and retry logic
5. Add error handling for GitHub API errors

**Deliverables**:
- github/github-client.ts with dual token support
- github/github-api.ts with API methods
- github/github-types.ts with TypeScript interfaces
- Rate limiting implementation
- Error handling for 403, 404, 429, 503, 504

**Code Structure**:
```typescript
// src/github/github-client.ts
export class GitHubClient {
  private tokenA: string;
  private tokenB: string;
  
  constructor(tokenA: string, tokenB: string) {
    this.tokenA = tokenA;
    this.tokenB = tokenB;
  }
  
  async checkAccess(repo: string, token: 'A' | 'B'): Promise<AccessResult> {
    // Implementation
  }
  
  async fetchRepoState(repo: string): Promise<RepoState> {
    // Implementation
  }
  
  // Additional methods
}
```

### Day 5: Baseline Establishment

**Tasks**:
1. Create baseline manager
2. Implement baseline capture logic
3. Create baseline storage (encrypted, external service)
4. Build baseline validation
5. Create CLI script for baseline establishment

**Deliverables**:
- baseline/baseline-manager.ts
- baseline/baseline-storage.ts
- baseline/baseline-validator.ts
- scripts/establish-baseline.ts CLI tool
- Baseline configuration file format

**Code Structure**:
```typescript
// src/baseline/baseline-manager.ts
export class BaselineManager {
  async establishBaseline(repos: string[]): Promise<BaselineConfig> {
    // Capture current state of all repos
    // Generate cryptographic hashes
    // Store securely
  }
  
  async loadBaseline(): Promise<BaselineConfig> {
    // Load from secure storage
  }
  
  async validateBaseline(baseline: BaselineConfig): Promise<boolean> {
    // Validate baseline integrity
  }
}
```

**Baseline Data Structure**:
```typescript
interface BaselineConfig {
  version: string;
  timestamp: Date;
  repos: {
    [repoName: string]: {
      stateHash: string;
      fingerprint: RepoFingerprint;
      submodules: SubmoduleConfig[];
      workflows: WorkflowConfig[];
      admins: string[];
      branchProtection: BranchProtectionRule[];
    };
  };
}
```

---

## Phase 2: Core Detection Mechanisms

**Duration**: Week 2  
**Goal**: Implement primary detection mechanisms

### Day 1-2: State Invariant Enforcement

**Tasks**:
1. Implement repo state fetching
2. Create state hashing function
3. Build state comparison logic
4. Implement state diff calculation
5. Create risk scoring for state changes

**Deliverables**:
- detectors/state-invariant.ts
- State comparison algorithm
- Risk scoring based on change severity

**Implementation Details**:
- Fetch repo state every 5-15 minutes
- Compare current state hash to baseline hash
- Calculate diff if hash mismatch
- Assign risk score: +5 to +10 based on severity
- Log all state changes to audit log

### Day 3: Dual-Token Verification

**Tasks**:
1. Implement dual token access checks
2. Create comparison logic for token results
3. Build disagreement detection
4. Implement risk scoring for token mismatches

**Deliverables**:
- detectors/dual-token.ts
- Token comparison logic
- Risk scoring for disagreements

**Implementation Details**:
- Check access with Token A
- Check access with Token B
- Compare results
- If both lose access: +8 risk
- If disagreement: +6 risk
- If only one fails: 0 risk (token issue)

### Day 4: Negative Authorization Detection

**Tasks**:
1. Integrate with GitHub Audit Log API
2. Implement event filtering for negative auth events
3. Create event parsing logic
4. Build risk scoring for events

**Deliverables**:
- detectors/negative-auth.ts
- Audit log integration
- Event type detection
- Risk scoring per event type

**Implementation Details**:
- Poll GitHub Audit Log API every 15 minutes
- Filter for: admin_removed, repo_transferred, permission_downgraded, etc.
- Parse event timestamps and details
- Assign risk scores: +5 to +10 per event
- Store events in event store

### Day 5: Write-Path Canary

**Tasks**:
1. Implement canary branch creation
2. Create canary branch deletion
3. Build retry logic for canary operations
4. Implement risk scoring for write failures

**Deliverables**:
- detectors/write-canary.ts
- Canary operation logic
- Failure detection and scoring

**Implementation Details**:
- Attempt to create temp branch every hour
- Attempt to delete temp branch
- Retry 3 times on failure
- If write fails consistently: +3 per failure
- Distinguish 403 (auth) from 503 (network)

---

## Phase 3: Risk Scoring & Response

**Duration**: Week 3  
**Goal**: Implement risk accumulation, decay, and response mechanisms

### Day 1-2: Risk Scoring System

**Tasks**:
1. Create risk accumulator
2. Implement decay engine
3. Build threshold manager
4. Create risk score storage
5. Implement score persistence

**Deliverables**:
- scoring/risk-accumulator.ts
- scoring/decay-engine.ts
- scoring/threshold-manager.ts
- Risk score storage in state store

**Implementation Details**:
- Accumulate risk from all detectors
- Decay: -1 per hour (no new events)
- Store current score and last update timestamp
- Check thresholds: 6 (lock), 10 (warn), 15 (immediate)
- Persist to external storage

### Day 3: Cross-Repo Correlation

**Tasks**:
1. Implement multi-repo checking
2. Create correlation logic
3. Build failure rate calculation
4. Implement risk scoring for correlation

**Deliverables**:
- detectors/cross-repo.ts
- Correlation algorithm
- Failure rate threshold logic

**Implementation Details**:
- Check all critical repos simultaneously
- Calculate failure rate
- If >= 50% fail: +2 per repo
- If 25-50% fail: +1 per repo
- If < 25% fail: 0 (isolated issue)

### Day 4: Temporal Consistency

**Tasks**:
1. Implement failure window tracking
2. Create consecutive failure counter
3. Build time window validation
4. Implement reset logic on success

**Deliverables**:
- detectors/temporal-consistency.ts
- Failure window management
- Time-based validation

**Implementation Details**:
- Track consecutive failures per repo
- Require 12 consecutive failures over 6 hours
- Reset counter on any success
- Only trigger if both conditions met

### Day 5: Response Mechanisms

**Tasks**:
1. Implement service locking
2. Create backup manager
3. Build notification system
4. Implement deletion logic

**Deliverables**:
- responders/lock-services.ts
- responders/backup-manager.ts
- responders/notify.ts
- responders/delete-repos.ts

**Implementation Details**:
- Lock: Set all deepiri-* services to read-only
- Backup: Create backups before deletion
- Notify: Send alerts via email, Slack, SMS
- Delete: Remove repos via GitHub API, stop containers

---

## Phase 4: Advanced Features

**Duration**: Week 4  
**Goal**: Implement advanced detection mechanisms

### Day 1: Event Replay Analysis

**Tasks**:
1. Implement event sequence tracking
2. Create timing analysis
3. Build anomaly detection for rapid sequences
4. Implement risk scoring for attack patterns

**Deliverables**:
- detectors/event-replay.ts
- Event sequence analyzer
- Timing-based anomaly detection

### Day 2: Fingerprint Verification

**Tasks**:
1. Implement repo fingerprinting
2. Create fingerprint comparison
3. Build mismatch detection
4. Implement risk scoring for fingerprint changes

**Deliverables**:
- detectors/fingerprint.ts
- Fingerprint generation
- Comparison logic

### Day 3: Submodule & Workflow Integrity

**Tasks**:
1. Implement submodule verification
2. Create workflow file monitoring
3. Build integrity checks
4. Implement risk scoring

**Deliverables**:
- detectors/submodule-integrity.ts
- detectors/workflow-integrity.ts
- Integrity checking logic

### Day 4: Fail-Closed Authorization

**Tasks**:
1. Implement authorization error detection
2. Create error classification
3. Build risk scoring for auth errors
4. Distinguish network vs auth errors

**Deliverables**:
- detectors/fail-closed.ts
- Error classification logic
- Risk scoring for auth failures

### Day 5: Orchestrator & Scheduler

**Tasks**:
1. Create main orchestrator
2. Implement detection scheduling
3. Build response coordination
4. Create service lifecycle management

**Deliverables**:
- orchestrator.ts
- scheduler.ts
- Service coordination logic

---

## Phase 5: Testing & Deployment

**Duration**: Week 5  
**Goal**: Comprehensive testing and production deployment

### Day 1-2: Unit Testing

**Tasks**:
1. Write unit tests for all detectors
2. Test risk scoring logic
3. Test decay engine
4. Test response mechanisms
5. Achieve > 80% code coverage

**Deliverables**:
- Unit tests for all modules
- Test fixtures and mocks
- Coverage reports

### Day 3: Integration Testing

**Tasks**:
1. Test GitHub API integration
2. Test baseline establishment
3. Test detection mechanisms end-to-end
4. Test response mechanisms
5. Test error handling

**Deliverables**:
- Integration test suite
- Test scenarios for each detector
- Error scenario tests

### Day 4: End-to-End Testing

**Tasks**:
1. Create test scenarios for false positives
2. Test temporal consistency
3. Test cross-repo correlation
4. Test graduated response
5. Test recovery mechanisms

**Deliverables**:
- E2E test suite
- False positive prevention tests
- Recovery mechanism tests

### Day 5: Deployment

**Tasks**:
1. Deploy to staging environment
2. Run baseline establishment
3. Monitor for 24 hours
4. Adjust thresholds if needed
5. Deploy to production with conservative settings

**Deliverables**:
- Production deployment
- Monitoring dashboard
- Runbooks and documentation

---

## Technical Requirements

### Runtime Environment

- Node.js 18+ (LTS)
- TypeScript 5.0+
- Docker for containerization
- Access to GitHub API (rate limits: 5000 requests/hour per token)

### External Services

- GitHub API (primary)
- External storage for baseline (encrypted)
- External storage for audit logs (immutable)
- Notification services (email, Slack, SMS)
- Container orchestration (Docker/Kubernetes)

### Dependencies

```json
{
  "dependencies": {
    "@octokit/rest": "^20.0.0",
    "@deepiri/shared-utils": "workspace:*",
    "express": "^4.18.0",
    "winston": "^3.11.0",
    "node-cron": "^3.0.3",
    "crypto": "built-in",
    "axios": "^1.6.0",
    "dotenv": "^16.3.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/express": "^4.17.0",
    "typescript": "^5.3.0",
    "jest": "^29.7.0",
    "@types/jest": "^29.5.0",
    "ts-jest": "^29.1.0"
  }
}
```

### Environment Variables

```bash
# GitHub Configuration
GITHUB_TOKEN_A=ghp_xxx
GITHUB_TOKEN_B=ghp_xxx
GITHUB_ORG=Team-Deepiri

# Critical Repositories
CRITICAL_REPOS=deepiri-platform,deepiri-core-api,diri-cyrex,deepiri-web-frontend

# Detection Configuration
STATE_CHECK_INTERVAL=5
WRITE_CANARY_INTERVAL=60
AUDIT_LOG_INTERVAL=15
TEMPORAL_CONSISTENCY_FAILURES=12
TEMPORAL_CONSISTENCY_HOURS=6

# Risk Scoring
RISK_LOCK_THRESHOLD=6
RISK_WARN_THRESHOLD=10
RISK_DELETE_THRESHOLD=10
RISK_IMMEDIATE_THRESHOLD=15
RISK_DECAY_RATE=1

# Response Configuration
GRACE_PERIOD_LOCK=24
GRACE_PERIOD_WARN=48
GRACE_PERIOD_DELETE=72
GRACE_PERIOD_IMMEDIATE=0
BACKUP_BEFORE_DELETE=true
REVERSIBILITY_WINDOW=168

# Storage
BASELINE_STORAGE_URL=https://storage.example.com
BASELINE_STORAGE_KEY=xxx
AUDIT_LOG_STORAGE_URL=https://audit.example.com
AUDIT_LOG_STORAGE_KEY=xxx

# Notifications
NOTIFICATION_EMAIL=admin@example.com
NOTIFICATION_SLACK_WEBHOOK=https://hooks.slack.com/xxx
NOTIFICATION_SMS_API_KEY=xxx

# Service Configuration
PORT=5010
LOG_LEVEL=info
NODE_ENV=production
```

---

## Dependencies

### Internal Dependencies

- @deepiri/shared-utils (logging, utilities)
- Access to other platform services (for locking)
- Container orchestration access (Docker/Kubernetes)

### External Dependencies

- GitHub API availability
- External storage services
- Notification services
- Network connectivity

### Dependency Management

- Use workspace dependencies for internal packages
- Pin external dependency versions
- Regular security audits
- Dependency update process

---

## Configuration Management

### Baseline Configuration

- Stored in encrypted external storage
- Versioned with timestamps
- Validated on load
- Backup copies maintained

### Runtime Configuration

- Environment variables for sensitive data
- Configuration file for non-sensitive settings
- Hot-reload capability for non-critical changes
- Validation on startup

### Configuration Schema

```typescript
interface ServiceConfig {
  detection: {
    stateInvariant: {
      enabled: boolean;
      checkInterval: number;
      baselineHash: string;
    };
    dualToken: {
      enabled: boolean;
      tokenA: string;
      tokenB: string;
    };
    // ... other detectors
  };
  scoring: {
    events: Record<string, number>;
    decay: {
      rate: number;
      minScore: number;
    };
  };
  response: {
    thresholds: {
      lock: number;
      warn: number;
      delete: number;
      immediate: number;
    };
    gracePeriods: {
      lock: number;
      warn: number;
      delete: number;
      immediate: number;
    };
  };
}
```

---

## Security Considerations

### Credential Management

- Tokens stored as environment variables
- Never logged or exposed in code
- Rotated regularly
- Separate tokens for different purposes

### Baseline Security

- Baseline stored encrypted
- Access control on baseline storage
- Audit trail for baseline changes
- Backup baseline copies

### Service Security

- Minimal permissions required
- Isolated container network
- No external network access except GitHub API
- Encrypted communication

### Audit Trail

- All actions logged to external service
- Immutable log storage
- Log retention policy
- Access control on audit logs

---

## Monitoring & Observability

### Metrics

- Risk score per repo
- Detection event counts
- Response action counts
- False positive rate
- System health

### Logging

- Structured logging (JSON)
- Log levels: error, warn, info, debug
- Correlation IDs for request tracking
- Log aggregation

### Alerts

- Risk score threshold breaches
- Detection failures
- Response action failures
- System health issues

### Dashboards

- Real-time risk score visualization
- Detection event timeline
- Response action history
- System health overview

---

## Rollback Plan

### Detection Issues

- Disable specific detectors via configuration
- Adjust risk thresholds
- Extend grace periods
- Manual risk score reset

### Response Issues

- Disable automatic responses
- Manual override for locks
- Restore from backups
- Rollback service deployment

### Baseline Issues

- Restore from backup baseline
- Re-establish baseline
- Validate baseline integrity
- Rollback to previous baseline version

### Complete Rollback

- Stop service
- Restore previous deployment
- Restore baseline
- Review audit logs
- Fix issues
- Redeploy

---

## Success Metrics

### Detection Accuracy

- False positive rate < 0.1%
- Detection latency < 15 minutes
- Coverage of all critical repos

### Response Effectiveness

- Lock within 24-48 hours
- Delete within 72-120 hours
- Zero data loss from false positives
- Successful recovery from backups

### System Reliability

- Uptime > 99.9%
- Zero unplanned downtime
- All actions logged and auditable
- Successful baseline establishment

---

## Post-Deployment

### Week 1 Post-Deployment

- Monitor risk scores daily
- Review all detection events
- Adjust thresholds if needed
- Document any issues

### Week 2-4 Post-Deployment

- Continue monitoring
- Refine thresholds
- Optimize detection intervals
- Improve documentation

### Ongoing

- Regular security audits
- Dependency updates
- Performance optimization
- Feature enhancements

---

## Appendix: Implementation Checklist

### Phase 1 Checklist
- [ ] Project structure created
- [ ] TypeScript configuration
- [ ] Docker container setup
- [ ] GitHub API client implemented
- [ ] Baseline manager created
- [ ] Baseline establishment script

### Phase 2 Checklist
- [ ] State invariant detector
- [ ] Dual-token detector
- [ ] Negative auth detector
- [ ] Write canary detector

### Phase 3 Checklist
- [ ] Risk accumulator
- [ ] Decay engine
- [ ] Threshold manager
- [ ] Cross-repo correlation
- [ ] Temporal consistency
- [ ] Response mechanisms

### Phase 4 Checklist
- [ ] Event replay analysis
- [ ] Fingerprint verification
- [ ] Submodule integrity
- [ ] Workflow integrity
- [ ] Fail-closed authorization
- [ ] Orchestrator

### Phase 5 Checklist
- [ ] Unit tests (>80% coverage)
- [ ] Integration tests
- [ ] E2E tests
- [ ] Staging deployment
- [ ] Production deployment
- [ ] Documentation complete

---

## Notes

- All code should follow existing platform conventions
- Use shared utilities from @deepiri/shared-utils
- Follow TypeScript best practices
- Write comprehensive tests
- Document all public APIs
- Maintain audit trail for all actions
- Regular security reviews required

