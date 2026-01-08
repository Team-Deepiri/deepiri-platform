# Security & QA Team Onboarding Guide

Welcome to the Deepiri Security & QA Team! This guide will help you get set up for security, testing, and quality assurance.

## Quick Reference

### Setup Minikube (for Kubernetes/Skaffold builds)
```bash
# Check if Minikube is running
minikube status

# If not running, start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)
```

### Build
```bash
# Build all services
docker compose -f docker-compose.dev.yml build

# Or use build script
./build.sh              # Linux/Mac/WSL
.\build.ps1             # Windows PowerShell
```

### When you DO need to build / rebuild
Only build if:
1. **Dockerfile changes**
2. **package.json/requirements.txt changes** (dependencies)
3. **First time setup**

**Note:** With hot reload enabled, code changes don't require rebuilds - just restart the service!

### Run all services
```bash
docker compose -f docker-compose.dev.yml up -d
```

### Stop all services
```bash
docker compose -f docker-compose.dev.yml down
```

### Running only services you need for your team
```bash
docker compose -f docker-compose.qa-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.qa-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f frontend-dev
# ... etc for all services
```

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Role-Specific Setup](#role-specific-setup)
4. [Development Workflow](#development-workflow)
5. [Key Resources](#key-resources)

## Prerequisites

### Required Software

- **Node.js** 18.x+ (for testing)
- **Python** 3.10+ (for security tools)
- **Docker** (for test environments)
- **Git**
- **VS Code** or your preferred IDE

### Required Accounts

- **GitHub Account** (for Dependabot access)
- **Security scanning tools** (Snyk, OWASP ZAP, etc.)
- **Test management tools** (if used)
- **OAuth Provider Accounts** (for testing OAuth flows)
- **Integration Test Accounts** (GitHub, Notion, Trello test accounts)

### System Requirements

- **RAM:** 8GB minimum
- **Storage:** 20GB+ free space
- **OS:** Windows 10+, macOS 10.15+, or Linux

## Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd deepiri-platform
```

### 2. Set Up Git Hooks (REQUIRED)

**⚠️ IMPORTANT:** This protects the `main` and `dev` branches from accidental pushes.

```bash
./setup-hooks.sh
```

This enables local Git hooks that prevent you from pushing directly to protected branches. You'll need to use Pull Requests instead.

**Why?** See [BRANCH_PROTECTION.md](../BRANCH_PROTECTION.md) for details.

### 3. Environment Setup (Security & QA Team)

**Security & QA team needs ALL services for comprehensive testing:**

```bash
# Copy environment files
cp env.example .env

# Start ALL services for comprehensive testing
docker-compose -f docker-compose.dev.yml up -d

# Or start specific services if testing individual components
docker-compose -f docker-compose.dev.yml up -d \
  mongodb \
  redis \
  influxdb \
  mongo-express \
  api-gateway \
  auth-service \
  task-orchestrator \
  gamification-service \
  analytics-service \
  notification-service \
  external-bridge-service \
  challenge-service \
  realtime-gateway \
  cyrex \
  mlflow \
  jupyter \
  deepiri-web-frontend-dev

# Verify all services are running
docker-compose -f docker-compose.dev.yml ps

# Test each service health endpoint
curl http://localhost:5000/health  # API Gateway
curl http://localhost:5001/health  # User Service
curl http://localhost:5002/health  # Task Service
curl http://localhost:5003/health  # Gamification Service
curl http://localhost:5004/health  # Analytics Service
curl http://localhost:5005/health  # Notification Service
curl http://localhost:5006/health  # Integration Service
curl http://localhost:5007/health  # Challenge Service
curl http://localhost:5008/health  # WebSocket Service
curl http://localhost:8000/health   # Python Agent
curl http://localhost:5500        # MLflow
curl http://localhost:8888        # Jupyter
curl http://localhost:5173        # deepiri-web-frontend

# View logs for security/QA testing
docker-compose -f docker-compose.dev.yml logs -f
```

**All Security & QA Services:**
- **All microservices** - For comprehensive security and QA testing
- **All databases** - For data security testing
- **deepiri-web-frontend** - For UI/UX testing
- **AI services** - For AI security testing

**Note:** Security & QA team needs all services to perform:
- End-to-end testing
- Security audits across all services
- Integration testing
- Performance testing
- Load testing

### 3. Install Testing Tools

```bash
# Backend testing
cd deepiri-core-api
npm install --save-dev jest supertest

# deepiri-web-frontend testing
cd deepiri-web-frontend
npm install --save-dev @testing-library/react @testing-library/jest-dom

# Python testing
cd diri-cyrex
pip install pytest pytest-cov
```

### 4. Stop Services (When Done)

```bash
# Stop all services
docker-compose -f docker-compose.dev.yml stop

# Or stop specific services for targeted testing
docker-compose -f docker-compose.dev.yml stop auth-service task-orchestrator

# Remove containers and volumes (cleanup)
docker-compose -f docker-compose.dev.yml down -v
```

### 5. Install Security Tools

```bash
# Install security scanning tools
npm install -g snyk
pip install safety bandit

# Install OWASP ZAP (download from owasp.org)
```

## Role-Specific Setup

### IT Lead

**Additional Setup:**
```bash
# Install security tools
pip install bandit safety
npm install -g npm-audit-resolver
```

**First Tasks:**
1. Review `docs/architecture/MICROSERVICES_SETUP.md` - Microservices architecture
2. Review security architecture for all microservices
3. Review `platform-services/backend/deepiri-auth-service/server.js` - OAuth 2.0 service (port 5001)
4. Review `platform-services/backend/deepiri-external-bridge-service/server.js` - Webhook service (port 5006)
5. Review `platform-services/backend/deepiri-notification-service/server.js` - Push notification service (port 5005)
6. Test OAuth flows across services
7. Test webhook security
8. Audit API Gateway security
9. Set up network defense for microservices
10. Review cloud security configs
11. Audit each microservice security
8. Test OAuth flows for security
9. Test webhook signature verification
10. Plan security improvements

**Key Files:**
- `platform-services/backend/deepiri-auth-service/src/oauthService.js` - NEW: OAuth 2.0 service
- `platform-services/backend/deepiri-external-bridge-service/src/webhookService.js` - NEW: Webhook service
- `platform-services/backend/deepiri-notification-service/src/pushNotificationService.js` - NEW: Push notifications
- `infrastructure/security/` (create)
- `deepiri-core-api/SECURITY_AUDIT.md` (review)

**Security Testing:**
```bash
# Test OAuth flows
# Test webhook signature verification
# Test API authentication
# Test data encryption
# Test rate limiting
```
- `services/auth-service/` (review)

---

### IT Internal Support

**Additional Setup:**
```bash
# Install documentation tools
npm install -g docsify
```

**First Tasks:**
1. Create employee onboarding docs
2. Set up tech support system
3. Create hardware/software provisioning guide
4. Document internal processes

**Key Files:**
- `docs/internal/` (create)
- `scripts/onboarding/` (create)

---

### IT External Support

**Additional Setup:**
```bash
# Install help desk tools (if using)
```

**First Tasks:**
1. Create user documentation
2. Build help center UI
3. Set up support ticket system
4. Create user guides

**Key Files:**
- `docs/user/` (create)
- `deepiri-web-frontend/src/pages/support/` (create)

---

### Support Engineer

**Additional Setup:**
```bash
# Install monitoring tools
npm install -g pm2
```

**First Tasks:**
1. Set up resource monitoring
2. Create monitoring dashboards
3. Set up alerting
4. Document support processes

**Key Files:**
- `docs/support/` (create)
- `scripts/monitoring/` (create)

---

### Security Operations

**Additional Setup:**
```bash
# Install security scanning tools
npm install -g snyk
pip install safety bandit
pip install pip-audit
```

**First Tasks:**
1. Review Dependabot alerts
2. Set up dependency scanning
3. Configure vulnerability checks
4. Create security policies
5. Set up automated security scanning

**Key Files:**
- `scripts/security/` (create)
- `.github/dependabot.yml` (review/update)
- `infrastructure/security/security_policy.md` (create)

**Security Scanning:**
```bash
# Scan dependencies
snyk test

# Scan Python packages
safety check
pip-audit

# Scan code
bandit -r diri-cyrex/
```

---

### QA Lead

**Additional Setup:**
```bash
# Install test management tools
npm install -g testcafe
```

**First Tasks:**
1. Review existing tests
2. Create test plans
3. Set up test strategy
4. Plan integration testing
5. Design regression test suite

**Key Files:**
- `tests/` (review)
- `qa/` (create directory)
- `qa/test_plans.md` (create)

---

### QA Engineer 1 - Manual Testing

**Additional Setup:**
```bash
# Install browser testing tools
# Chrome DevTools, Firefox Developer Tools
```

**First Tasks:**
1. Review application functionality
2. Create test cases
3. Perform manual testing
4. Document bugs
5. Create UAT scenarios

**Key Files:**
- `qa/manual/test_cases.md` (create)
- `qa/manual/uat_scenarios.md` (create)
- `qa/manual/bug_reports.md` (create)

**Test Case Template:**
```markdown
## Test Case: TC-001
**Description:** User can create a task
**Steps:**
1. Navigate to tasks page
2. Click "New Task"
3. Enter task title
4. Click "Save"
**Expected:** Task is created and displayed
**Actual:** [Fill during testing]
**Status:** Pass/Fail
```

---

### QA Engineer 2 - Automation Testing

**Additional Setup:**
```bash
# Install automation tools
npm install --save-dev playwright
npm install --save-dev cypress
npm install --save-dev selenium-webdriver
```

**First Tasks:**
1. Set up automation framework
2. Create API tests
3. Create E2E tests
4. Set up test reporting
5. Integrate with CI/CD

**Key Files:**
- `tests/automation/` (create)
- `qa/automation/` (create)

**Test Example:**
```javascript
// tests/automation/api_tests.js
const axios = require('axios');

describe('API Tests', () => {
  test('GET /api/tasks', async () => {
    const response = await axios.get('http://localhost:5000/api/tasks');
    expect(response.status).toBe(200);
  });
});
```

---

### QA Intern 1

**Setup:**
Follow basic setup, focus on:
- Test script creation
- Bug tracking
- Test data preparation

---

### QA Intern 2

**Setup:**
Follow basic setup, focus on:
- Regression test maintenance
- Environment setup
- Test configuration

## Development Workflow

### 1. Security Scanning

```bash
# Daily security scan
cd scripts/security
./dependency_scan.sh
./vulnerability_check.sh
```

### 2. Testing

```bash
# Run all tests
cd deepiri-core-api && npm test
cd diri-cyrex && pytest
cd deepiri-web-frontend && npm test

# Run integration tests
pytest tests/integration/
```

### 3. Bug Reporting

1. Create issue in GitHub
2. Label as bug
3. Assign to appropriate team
4. Track resolution

### 4. Test Documentation

```bash
# Update test cases
# Document test results
# Create test reports
```

## Key Resources

### Documentation

- **Security & QA Team README:** `README_SECURITY_QA_TEAM.md`
- **FIND_YOUR_TASKS:** `FIND_YOUR_TASKS.md`
- **Getting Started:** `GETTING_STARTED.md`
- **Environment Variables:** `ENVIRONMENT_VARIABLES.md`

### Important Directories

- `tests/` - Test files
- `qa/` - QA documentation
- `scripts/security/` - Security scripts
- `infrastructure/security/` - Security configs

### Communication

- Team channels
- Security alerts
- Bug triage meetings
- Test review process

## Getting Help

1. Check `FIND_YOUR_TASKS.md` for your role
2. Review `README_SECURITY_QA_TEAM.md`
3. Ask in team channels
4. Contact IT Lead or QA Lead

---

**Welcome to the Security & QA Team! Let's ensure quality and security.**




