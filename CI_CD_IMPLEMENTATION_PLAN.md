# Deepiri CI/CD Implementation Plan

## Overview
This document outlines the roles, responsibilities, and goals for CI/CD implementation across all Deepiri repositories, including Python package validation for modelkit and helox.

---

## Team Roles

### Austin - Lead Architect / Systems Support Engineer
- Provides CI/CD workflow template
- Reviews all CI/CD pull requests
- Defines standards and expectations
- Provides guidance on repo-specific edge cases
- Validates Python package publishing workflows

### Runbin - New QA Maintainer / DevOps Intern
- **Primary Focus**: Backend services and Python packages
- **Responsibilities**:
  - Implement CI/CD for all backend TypeScript services
  - Set up Python package validation for modelkit and helox
  - Configure shared utilities linting and testing
  - Ensure Docker build validation for all backend services
  - Maintain consistency across backend CI/CD workflows
  - Validate Python package dependencies and compatibility

### Sean - Senior DevOps Engineer
- **Primary Focus**: Frontend, AI services, and platform orchestration
- **Responsibilities**:
  - Implement CI/CD for all frontend repositories
  - Configure Cyrex AI service CI/CD (build + run, no linting)
  - Set up platform-wide orchestration workflows
  - Handle deployment pipeline integration
  - Manage cross-repository dependency validation
  - Ensure frontend-backend integration testing

Please make sure their work does not interfere with each other and assign separate responsibilities.

---

## Standard CI/CD Architecture
All repositories should follow this standardized baseline workflow.

### Required Steps for All Repositories:
- Checkout
- Install dependencies
- Linting
- Unit tests
- Build step (if applicable)
- Docker build validation (for backend services)
- Caching
- PR gating rules (ensure all checks pass before merge)
- Consistent workflow naming: `Deepiri CI - <repo-name>`

### Special Cases:

#### Python Package Repositories
- **deepiri-modelkit** (Shared ML Contracts)
  - Python environment setup with Poetry
  - Type checking with mypy
  - Code formatting with black
  - Unit tests with pytest
  - Package build validation
  - Dependency compatibility checking
  - No Docker build (library package)

- **diri-helox** (ML Training Platform)
  - Python environment setup with Poetry
  - Linting with ruff
  - Type checking with mypy
  - Code formatting with black
  - Unit tests with pytest
  - Integration tests for ML pipelines
  - Package build validation
  - No Docker build (development/research package)

- **diri-cyrex** (AI Agent Service)
  - Python environment setup with Poetry
  - Build validation (Dockerfile.cpu and Dockerfile)
  - Unit tests with pytest
  - Integration tests for AI agent functionality
  - No linting (research-focused, flexibility prioritized)
  - Docker build validation required

#### Frontend Repositories
- Node install
- Lint (ESLint)
- Build (Vite/React build)
- Test (Jest/Vitest)
- Type checking (TypeScript)

#### Backend TypeScript Services
- Lint (ESLint)
- Test (Jest)
- Build (TypeScript compilation)
- Docker validation
- Type checking (TypeScript)

#### Platform Repository (deepiri-platform)
- **Multi-service orchestration**:
  - Lint all shared utilities
  - Build all backend services
  - Build frontend
  - Run integration tests across services
  - Docker compose validation
  - Cross-repository dependency checks

---

## Repo Assignments

### Runbin — Backend & Python Package Focus
You own CI/CD implementation for:

- `deepiri-platform` (Platform orchestration)
- `deepiri-auth-service`
- `deepiri-api-gateway`
- `deepiri-language-intelligence-service`
- `deepiri-external-bridge-service`
- `deepiri-core-api`
- `deepiri-modelkit` (Python package - shared contracts)
- `diri-helox` (Python package - ML training)
- `.github` (global workflows)

### Sean — Frontend, AI, and Platform Services
You own CI/CD implementation for:

- `deepiri-web-frontend`
- `deepiri-landing`
- `diri-cyrex` (AI agent service)
- `deepiri-emotion-desktop`
- `platform-services/backend/deepiri-realtime-gateway`
- `platform-services/shared/deepiri-shared-utils`

Any new repositories added will be assigned following the same pattern.

---

## Python Package CI/CD Specifics

### deepiri-modelkit (Shared ML Contracts)
**Purpose**: Shared contracts, interfaces, and utilities for Deepiri AI/ML services
**CI/CD Requirements**:
- Poetry environment setup
- Type checking (mypy)
- Code formatting (black)
- Unit tests (pytest)
- Package build validation
- Dependency compatibility checking
- No Docker build (library package)

**Validation Steps**:
1. Install dependencies with `poetry install`
2. Run `mypy src/` for type checking
3. Run `black --check src/` for formatting
4. Run `pytest` for unit tests
5. Run `poetry build` to validate package creation
6. Check dependency compatibility

### diri-helox (ML Training Platform)
**Purpose**: ML training pipelines, model development, and research
**CI/CD Requirements**:
- Poetry environment setup
- Linting (ruff)
- Type checking (mypy)
- Code formatting (black)
- Unit tests (pytest)
- Integration tests for ML pipelines
- Package build validation
- No Docker build (development/research package)

**Validation Steps**:
1. Install dependencies with `poetry install`
2. Run `ruff check .` for linting
3. Run `mypy .` for type checking
4. Run `black --check .` for formatting
5. Run `pytest` for unit tests
6. Run integration tests for ML pipelines
7. Run `poetry build` to validate package creation

### diri-cyrex (AI Agent Service)
**Purpose**: AI agent API and interface
**CI/CD Requirements**:
- Poetry environment setup
- Build validation (both CPU and GPU Dockerfiles)
- Unit tests (pytest)
- Integration tests for AI agent functionality
- No linting (research-focused flexibility)
- Docker build validation required

**Validation Steps**:
1. Install dependencies with `poetry install`
2. Run `pytest` for unit tests
3. Run integration tests for AI agent functionality
4. Build Docker images (both CPU and GPU variants)
5. Validate Docker image functionality

---

## Responsibilities and Expectations

### CI/CD Implementors
- Implement CI/CD in each assigned repo using the standard template
- Ensure workflows are consistent, modular, and maintainable
- Ensure all checks pass before marking CI/CD as complete
- Submit PRs for review by Austin
- Add repo-specific overrides only when necessary
- Sync frequently to avoid duplicated work
- **Python Package Specific**: Validate package publishing workflows and dependency management

### Lead Architect
- Provide CI/CD standardized template
- Review all CI/CD PRs
- Confer with owner to approve architecture-level decisions
- Provide guidance and clarification whenever necessary
- Validate Python package CI/CD workflows for publishing readiness

---

## Acceptance Criteria for Each Repo

A CI/CD for each repository may be considered complete only when:

- The standardized workflow is correctly added on PRs
- Linting, testing, and build steps all run successfully
- If applicable, Docker build validation passes
- Caching is configured
- Workflow names are standardized
- Logic is neither redundant nor duplicated
- All repo-specific overrides are clearly documented in the workflow file
- Workflow is maintainable and accords with the provided template
- **Python Package Specific**:
  - Package build validation passes
  - Dependency compatibility is verified
  - Type checking completes successfully
  - No Docker build steps for library packages (modelkit, helox)

---

## Collaboration Rules
- Each repo has a single owner to avoid overlap
- Weekly sync between all implementors
- PRs must include:
  - The workflow file
  - A summary of changes
  - Any repo-specific override notes
  - Python package validation results (if applicable)
- Austin reviews all CI/CD PRs
- Ask questions early if a repo has unusual requirements or anything is unclear
- **Python Package Coordination**: Runbin handles Python package CI/CD, Sean focuses on service integration

---

## Python Package Integration Strategy

### Cross-Repository Dependencies
- **modelkit** → **helox**: Validate helox can import modelkit contracts
- **modelkit** → **cyrex**: Validate cyrex can use modelkit interfaces
- **helox** → **cyrex**: Validate model exports from helox work in cyrex

### Validation Workflow
1. **Unit Testing**: Each package tests independently
2. **Integration Testing**: Cross-package compatibility validation
3. **Build Validation**: Package creation and distribution readiness
4. **Dependency Checking**: Ensure no circular dependencies or version conflicts

---

## Goal
Once this is implemented, every Deepiri repository should have:

- A consistent CI/CD pipeline
- A maintainable workflow structure
- Clear ownership
- Python package validation for modelkit and helox
- Cross-repository dependency validation
- A foundation for future automation and deployment pipelines