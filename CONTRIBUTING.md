# Contributing to Deepiri

Thank you for your interest in contributing to Deepiri! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Documentation](#documentation)
- [Getting Help](#getting-help)

---

## Code of Conduct

By participating in this project, you agree to:

- Be respectful and inclusive
- Welcome constructive feedback
- Focus on what is best for the community
- Show empathy towards other contributors

---

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/deepiri.git
   cd deepiri
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/deepiri.git
   ```

---

## Development Setup

### Option 1: Docker (Recommended)

The easiest way to get started is using Docker Compose:

```bash
# Copy environment variables
cp .env.example .env
# Edit .env with your API keys

# Start all services
docker compose -f docker-compose.dev.yml up -d

# View logs
docker compose -f docker-compose.dev.yml logs -f
```

**Services will be available at:**
- Frontend: http://localhost:5173
- Backend API: http://localhost:5000
- Python AI Service: http://localhost:8000
- MongoDB: localhost:27017
- Redis: localhost:6379
- Mongo Express: http://localhost:8081

### Option 2: Local Development

#### Backend Setup

```bash
cd deepiri-core-api
npm install
cp ../.env.example .env
# Edit .env with your configuration
npm run dev
```

#### Frontend Setup

```bash
cd deepiri-web-frontend
npm install
cp ../.env.example .env
# Edit .env with your configuration
npm run dev
```

#### Python AI Service Setup

```bash
cd diri-cyrex
pip install -r requirements.txt
cp ../.env.example .env
# Edit .env with your configuration
uvicorn app.main:app --reload --port 8000
```

### Initial Setup Script

You can also use the setup script:

```bash
npm run setup
```

This installs dependencies for all services.

---

## Project Structure

```
deepiri/
├── deepiri-core-api/          # Node.js backend (Express)
│   ├── models/         # MongoDB models
│   ├── services/       # Business logic
│   ├── routes/         # API routes
│   ├── middleware/     # Express middleware
│   ├── controllers/    # Route controllers
│   └── utils/          # Utility functions
│
├── deepiri-web-frontend/           # React deepiri-web-frontend (Vite)
│   ├── src/
│   │   ├── components/ # Reusable components
│   │   ├── pages/      # Page components
│   │   ├── api/        # API client functions
│   │   ├── contexts/   # React contexts
│   │   └── utils/      # Utility functions
│   └── public/         # Static assets
│
├── diri-cyrex/     # Python AI service (FastAPI)
│   ├── app/
│   │   ├── routes/     # API routes
│   │   └── settings.py # Configuration
│   └── train/          # ML training scripts
│
├── scripts/            # Utility scripts
├── ops/                # Deployment configs
└── docker-compose.dev.yml  # Development Docker setup
```

---

## Branch Protection Rules

### 🚫 Protected Branches: `main` and `dev`

**Direct pushes to `main` and `dev` are blocked** by multiple layers of protection:

1. **Server-side CI enforcement** - GitHub Actions automatically reject any direct push
2. **Local Git hooks** - Prevent accidental pushes before they reach GitHub
3. **PR blocking** - Pull Requests targeting `main` or `dev` are automatically blocked

You **must** create feature branches and open Pull Requests to merge your work.

### ✔ Allowed Workflow

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Push your branch:**
   ```bash
   git push -u origin feature/your-feature-name
   ```

3. **Open a Pull Request** into `staging` or another feature branch (NOT `main` or `dev`)

4. **CI will merge** `staging` → `dev` → `main` only during official deployments

### 🔧 Setup Git Hooks (One-Time Setup)

Run this once after cloning the repository:

```bash
./setup-hooks.sh
```

This ensures you can never accidentally push to `main` or `dev` from your local machine.

---

## Development Workflow

### 0. Initial Setup (Automatic!)

**Git hooks are automatically configured when you clone the repository!**

The hooks protect the `main` and `dev` branches from accidental pushes. See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for details.

**If hooks aren't working** (e.g., existing clone), run:
```bash
./setup-hooks.sh
```

### 1. Find Your Team

**Not sure which team you're on?** → [FIND_YOUR_TASKS.md](FIND_YOUR_TASKS.md)

This will help you:
- Identify your role and responsibilities
- Find your team-specific documentation
- Understand which services you work with

### 2. Follow Your Team's Path

After identifying your team, follow your team-specific onboarding:
- **AI Team:** [docs/AI_TEAM_ONBOARDING.md](docs/AI_TEAM_ONBOARDING.md)
- **ML Team:** [docs/ML_ENGINEER_COMPLETE_GUIDE.md](docs/ML_ENGINEER_COMPLETE_GUIDE.md)
- **Backend Team:** [docs/BACKEND_TEAM_ONBOARDING.md](docs/BACKEND_TEAM_ONBOARDING.md)
- **Frontend Team:** [docs/FRONTEND_TEAM_ONBOARDING.md](docs/FRONTEND_TEAM_ONBOARDING.md)
- **Infrastructure Team:** [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md)
- **Platform Engineers:** [docs/PLATFORM_TEAM_ONBOARDING.md](docs/PLATFORM_TEAM_ONBOARDING.md)
- **QA Team:** [docs/SECURITY_QA_TEAM_ONBOARDING.md](docs/SECURITY_QA_TEAM_ONBOARDING.md)

### 3. Create a Branch

Always create a new branch for your work:

```bash
# Update your main branch
git checkout main
git pull upstream main

# Create a feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
# or
git checkout -b docs/your-documentation-update
```

**⚠️ Remember:** You cannot push directly to `main` or `dev`. All changes must go through Pull Requests.

### Branch Naming Convention

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Adding or updating tests
- `chore/` - Maintenance tasks

### 2. Make Your Changes

- Write clean, readable code
- Follow the coding standards (see below)
- Add tests for new features
- Update documentation as needed

### 3. Test Your Changes

```bash
# Run backend tests
cd deepiri-core-api
npm test

# Run deepiri-web-frontend tests
cd deepiri-web-frontend
npm test

# Run Python tests
cd diri-cyrex
pytest

# Run all tests from root
npm test
```

### 4. Commit Your Changes

See [Commit Messages](#commit-messages) section for guidelines.

### 5. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

---

## Coding Standards

### General Principles

- **Write self-documenting code**: Use clear variable and function names
- **Keep functions small**: Functions should do one thing well
- **DRY (Don't Repeat Yourself)**: Avoid code duplication
- **KISS (Keep It Simple, Stupid)**: Prefer simple solutions over complex ones
- **YAGNI (You Aren't Gonna Need It)**: Don't add features until needed

### JavaScript/Node.js (Backend)

- Use **ES6+** features
- Follow **async/await** pattern (avoid callback hell)
- Use **const** and **let** (avoid **var**)
- Use **arrow functions** where appropriate
- Handle errors properly (try/catch, .catch())
- Use **JSDoc** comments for functions

**Example:**
```javascript
/**
 * Creates a new task for a user
 * @param {string} userId - User ID
 * @param {Object} taskData - Task data
 * @returns {Promise<Object>} Created task
 */
async function createTask(userId, taskData) {
  try {
    const task = new Task({
      userId,
      ...taskData
    });
    return await task.save();
  } catch (error) {
    logger.error('Error creating task:', error);
    throw error;
  }
}
```

### React (Frontend)

- Use **functional components** with hooks
- Use **React Hooks** (useState, useEffect, useContext, etc.)
- Extract reusable logic into **custom hooks**
- Use **PropTypes** or TypeScript for type checking
- Keep components small and focused
- Use **named exports** for components

**Example:**
```jsx
import { useState, useEffect } from 'react';
import { useAuth } from '../hooks/useAuth';

export function TaskList() {
  const { user } = useAuth();
  const [tasks, setTasks] = useState([]);

  useEffect(() => {
    // Fetch tasks
  }, [user]);

  return (
    <div>
      {tasks.map(task => (
        <TaskCard key={task.id} task={task} />
      ))}
    </div>
  );
}
```

### Python (AI Service)

- Follow **PEP 8** style guide
- Use **type hints** where possible
- Use **async/await** for async operations
- Document functions with **docstrings**
- Use **f-strings** for string formatting

**Example:**
```python
from typing import Dict, Any, Optional

async def generate_challenge(task: Dict[str, Any]) -> Dict[str, Any]:
    """
    Generate a gamified challenge from a task using AI.
    
    Args:
        task: Task data dictionary
        
    Returns:
        Challenge data dictionary
    """
    # Implementation
    pass
```

### File Naming

- **JavaScript/TypeScript**: `camelCase.js` or `camelCase.ts`
- **React Components**: `PascalCase.jsx`
- **Python**: `snake_case.py`
- **Tests**: `*.test.js` or `*.spec.js`

### Code Formatting

We use ESLint for JavaScript/TypeScript and follow Prettier formatting:

```bash
# Format code
npm run lint
```

---

## Testing

### Writing Tests

- Write tests for new features
- Write tests for bug fixes
- Aim for meaningful test coverage
- Use descriptive test names

### Backend Tests (Jest)

```javascript
// deepiri-core-api/tests/taskService.test.js
describe('Task Service', () => {
  describe('createTask', () => {
    it('should create a task successfully', async () => {
      const task = await taskService.createTask(userId, taskData);
      expect(task).toBeDefined();
      expect(task.userId).toBe(userId);
    });

    it('should throw error for invalid data', async () => {
      await expect(
        taskService.createTask(userId, {})
      ).rejects.toThrow();
    });
  });
});
```

### Frontend Tests (Vitest)

```javascript
// deepiri-web-frontend/src/components/TaskCard.test.jsx
import { render, screen } from '@testing-library/react';
import { TaskCard } from './TaskCard';

describe('TaskCard', () => {
  it('renders task title', () => {
    render(<TaskCard task={{ title: 'Test Task' }} />);
    expect(screen.getByText('Test Task')).toBeInTheDocument();
  });
});
```

### Python Tests (Pytest)

```python
# diri-cyrex/tests/test_challenge.py
import pytest
from app.routes.challenge import generate_challenge

def test_generate_challenge():
    task = {"title": "Test Task", "type": "manual"}
    result = await generate_challenge(task)
    assert result["success"] == True
    assert "data" in result
```

### Running Tests

```bash
# Backend
cd deepiri-core-api && npm test

# Frontend
cd deepiri-web-frontend && npm test

# Python
cd diri-cyrex && pytest

# All tests
npm test
```

---

## Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements
- `ci`: CI/CD changes

### Scope (Optional)

- `api`: Backend API changes
- `deepiri-web-frontend`: Frontend changes
- `ai`: AI service changes
- `deps`: Dependency updates
- `docker`: Docker configuration

### Examples

```
feat(api): add challenge generation endpoint

Add POST /api/challenges/generate endpoint that creates
challenges from tasks using the Python AI service.

Closes #123
```

```
fix(deepiri-web-frontend): resolve authentication token refresh issue

The token refresh was failing silently. Now properly handles
token expiration and redirects to login when needed.

Fixes #456
```

```
docs: update API documentation for task endpoints

Add examples and improve descriptions for task CRUD endpoints.
```

---

## Pull Request Process

### Before Submitting

1. **Update your branch**:
   ```bash
   git checkout main
   git pull upstream main
   git checkout feature/your-feature
   git rebase main
   ```

2. **Run tests**:
   ```bash
   npm test
   ```

3. **Lint your code**:
   ```bash
   npm run lint
   ```

4. **Check for console errors**:
   - Ensure no console.log statements in production code
   - Remove debug code

### PR Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] No console errors
- [ ] No merge conflicts
- [ ] Branch is up to date with main

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How was this tested?

## Screenshots (if applicable)
Add screenshots for UI changes

## Related Issues
Closes #123
```

### Review Process

1. Maintainers will review your PR
2. Address any feedback
3. Once approved, your PR will be merged
4. Squash commits when merging (maintainers will handle this)

---

## Documentation

### Code Documentation

- Add **JSDoc** comments for functions and classes
- Document complex algorithms or business logic
- Keep README files updated

### API Documentation

- Update API documentation when adding/changing endpoints
- Include request/response examples
- Document error cases

### User Documentation

- Update user-facing documentation for UI changes
- Keep guides and tutorials current

---

## Getting Help

### Resources

- **Documentation**: Check `SYSTEM_ARCHITECTURE.md` and `README.md`
- **Logs**: See `LOG_INSPECTION_GUIDE.md` for debugging
- **Issues**: Check existing GitHub issues

### Communication

- **GitHub Issues**: For bug reports and feature requests
- **Pull Requests**: For code discussions
- **Discussions**: For questions and general discussion

### Before Asking

1. Check existing documentation
2. Search existing issues
3. Review code comments
4. Check logs for errors

### Creating Issues

When creating an issue, include:

- **Description**: Clear description of the problem
- **Steps to Reproduce**: Step-by-step instructions
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Environment**: OS, Node version, Docker version, etc.
- **Logs**: Relevant log excerpts
- **Screenshots**: If applicable

---

## Additional Guidelines

### Security

- Never commit API keys or secrets
- Use environment variables for sensitive data
- Follow security best practices
- Report security vulnerabilities privately

### Performance

- Consider performance implications
- Optimize database queries
- Use caching where appropriate
- Profile slow operations

### Accessibility

- Ensure UI is accessible
- Use semantic HTML
- Include ARIA labels where needed
- Test with screen readers

### Browser Support

- Test in modern browsers (Chrome, Firefox, Safari, Edge)
- Ensure responsive design works on mobile
- Check cross-browser compatibility

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## Thank You!

Thank you for contributing to Deepiri! Your contributions help make productivity fun and engaging for everyone. 🎉

---

**Questions?** Open an issue or start a discussion on GitHub!

