# deepiri-web-frontend Team Onboarding Guide

Welcome to the Deepiri deepiri-web-frontend Team! This guide will help you get set up and start building beautiful user interfaces.

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
docker compose -f docker-compose.frontend-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.frontend-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f frontend-dev
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f auth-service
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

- **Node.js** 18.x or higher
- **npm** or **yarn**
- **Git**
- **VS Code** (recommended) with extensions:
  - ESLint
  - Prettier
  - React snippets
  - Tailwind CSS IntelliSense

### Accounts you may need

- **Firebase Account** (for authentication, we may utilize this)
- **GitHub  want** (for repository access)
- **Figma Access** (for design files, if available)

### System Requirements

- **RAM:** 8GB minimum, 16GB+ recommended
- **Storage:** 10GB+ free space
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

### 3. deepiri-web-frontend Setup

```bash
cd deepiri-web-frontend

# Install dependencies
npm install

# Copy environment file
cp env.example.deepiri-web-frontend .env.local

# Edit .env with your configuration
# IMPORTANT: Point to API Gateway (not individual services)
# VITE_API_URL=http://localhost:5000/api
# VITE_CYREX_URL=http://localhost:8000
# VITE_FIREBASE_API_KEY=your-key
```

### 4. Start Required Microservices (deepiri-web-frontend Team)

**deepiri-web-frontend team only needs these services:**
- deepiri-web-frontend (for development)
- API Gateway (to route requests)
- Core services: User, Task, Gamification, Analytics
- WebSocket (for real-time updates)
- Python Agent (for AI features)
- Databases: MongoDB, Redis

```bash
# Start only the services needed for deepiri-web-frontend development
docker-compose -f docker-compose.dev.yml up -d \
  mongodb \
  redis \
  api-gateway \
  user-service \
  task-orchestrator \
  gamification-service \
  analytics-service \
  realtime-gateway \
  cyrex \
  deepiri-web-frontend-dev

# Check service status
docker-compose -f docker-compose.dev.yml ps

# View logs
docker-compose -f docker-compose.dev.yml logs -f deepiri-web-frontend-dev
```

**Services NOT needed for deepiri-web-frontend:**
- `influxdb` (unless working on analytics dashboards)
- `mlflow` (MLOps only)
- `jupyter` (AI team only)
- `notification-service` (unless testing notifications)
- `external-bridge-service` (unless testing integrations)
- `challenge-service` (unless testing challenges)
- `mongo-express` (optional, for database admin)

### 4. Start Development Server

```bash
# If using Docker (recommended)
# deepiri-web-frontend is already running via docker-compose above

# Or run locally (if not using Docker)
cd deepiri-web-frontend
npm run dev
```

deepiri-web-frontend runs on http://localhost:5173

**Important:** deepiri-web-frontend connects to API Gateway (port 5000), which routes to all microservices.

### 5. Verify Setup

```bash
# Check if deepiri-web-frontend is running
curl http://localhost:5173

# Check API Gateway connection
curl http://localhost:5000/health

# Check required services
curl http://localhost:5001/health  # User Service
curl http://localhost:5002/health  # Task Service
curl http://localhost:5003/health  # Gamification Service
curl http://localhost:5004/health  # Analytics Service
curl http://localhost:5008/health  # WebSocket Service
curl http://localhost:8000/health  # Python Agent

# Open browser to http://localhost:5173
```

**Note:** All API calls should go through the API Gateway at `http://localhost:5000/api/*`

### 6. Stop Services (When Done)

```bash
# Stop all deepiri-web-frontend-related services
docker-compose -f docker-compose.dev.yml stop \
  deepiri-web-frontend-dev \
  api-gateway \
  user-service \
  task-orchestrator \
  gamification-service \
  analytics-service \
  realtime-gateway \
  cyrex

# Or stop everything
docker-compose -f docker-compose.dev.yml down
```

## Role-Specific Setup

### deepiri-web-frontend Lead

**Additional Setup:**
```bash
# Install design system tools
npm install storybook
npm install @storybook/react
```

**First Tasks:**
1. Review `deepiri-web-frontend/src/App.tsx`
2. Review component structure
3. Establish design system
4. Set up component library
5. Review UX/UI consistency

**Key Files:**
- `deepiri-web-frontend/src/App.tsx`
- `deepiri-web-frontend/src/components/`
- `deepiri-web-frontend/src/pages/`
- `deepiri-web-frontend/vite.config.ts`

---

### Graphic Designer

**Additional Setup:**
- **Figma** (design tool)
- **Adobe Creative Suite** (optional)
- **SVG optimization tools**

**First Tasks:**
1. Review existing assets in `deepiri-web-frontend/public/`
2. Review `deepiri-web-frontend/src/assets/`
3. Create logo and branding assets
4. Design system assets
5. Icon sets

**Key Files:**
- `deepiri-web-frontend/public/` (favicon, logos)
- `deepiri-web-frontend/src/assets/` (create branding assets)
- `deepiri-web-frontend/src/styles/brand.css` (create)

**Asset Guidelines:**
- Logo: SVG format, multiple sizes
- Icons: SVG sprite or icon font
- Colors: Define in CSS variables
- Typography: Define font families

---

### deepiri-web-frontend Engineer 1 - Web Pages & Forms

**Additional Setup:**
```bash
cd deepiri-web-frontend

# Install form libraries
npm install react-hook-form
npm install yup
npm install @hookform/resolvers

# Install Firebase
npm install firebase
```

**First Tasks:**
1. Review `deepiri-web-frontend/src/pages/`
2. Review `deepiri-web-frontend/src/components/`
3. Create dashboard pages
4. Implement form components
5. Integrate Firebase authentication

**Key Files:**
- `deepiri-web-frontend/src/pages/Dashboard.jsx` (create)
- `deepiri-web-frontend/src/components/forms/` (create)
- `deepiri-web-frontend/src/services/firebase.js` (create)

**Component Example:**
```jsx
// src/components/forms/FormValidation.jsx
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
```

---

### deepiri-web-frontend Engineer 2 (Melvin) - AI/Visualization Dashboards

**Additional Setup:**
```bash
cd deepiri-web-frontend

# Install charting and visualization libraries
npm install recharts d3
npm install @influxdata/influxdb-client  # For time-series data
npm install react-query  # For data fetching
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-platform-analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series
2. Review `platform-services/backend/deepiri-platform-analytics-service/src/behavioralClustering.js` - NEW: Clustering
3. Review `platform-services/backend/deepiri-platform-analytics-service/src/predictiveModeling.js` - NEW: Predictive models
4. Create AI visualization dashboards
5. Implement time-series charts (InfluxDB integration)
6. Create clustering visualizations
7. Create predictive model visualizations
8. Build real-time analytics displays

**Key Files:**
- `platform-services/backend/deepiri-platform-analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series analytics
- `platform-services/backend/deepiri-platform-analytics-service/src/behavioralClustering.js` - NEW: Behavioral clustering
- `platform-services/backend/deepiri-platform-analytics-service/src/predictiveModeling.js` - NEW: Predictive modeling
- `deepiri-web-frontend/src/pages/analytics/` - Analytics pages
- `deepiri-web-frontend/src/components/charts/` - Chart components

---

### deepiri-web-frontend Engineer 2 (Melvin) - AI/Visualization Dashboards (Updated)

**Additional Setup:**
```bash
cd deepiri-web-frontend

# Install charting libraries
npm install recharts
npm install d3
npm install chart.js react-chartjs-2
npm install date-fns
```

**First Tasks:**
1. Review `deepiri-web-frontend/src/pages/analytics/`
2. Create productivity charts
3. Create AI insights visualization
4. Build analytics dashboard
5. Implement real-time data updates

**Key Files:**
- `deepiri-web-frontend/src/pages/analytics/Dashboard.jsx` (create)
- `deepiri-web-frontend/src/components/charts/` (create)
- `deepiri-web-frontend/src/pages/ProductivityChat.jsx` (existing)

**Chart Example:**
```jsx
// src/components/charts/ProductivityChart.jsx
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts';
```

---

### deepiri-web-frontend Engineer 3 - Gamification Visuals

**Additional Setup:**
```bash
cd deepiri-web-frontend

# Install animation libraries
npm install framer-motion
npm install react-spring
npm install lottie-react  # for Lottie animations
```

**First Tasks:**
1. Review `platform-services/backend/deepiri-engagement-service/server.js` - Gamification service (port 5003)
2. Review `platform-services/backend/deepiri-engagement-service/src/multiCurrencyService.js` - Multi-currency
3. Review `platform-services/backend/deepiri-engagement-service/src/eloLeaderboardService.js` - ELO ranking
4. Review `platform-services/backend/deepiri-engagement-service/src/badgeSystemService.js` - Badge system (500+ badges)
5. Test API calls through API Gateway: `http://localhost:5000/api/gamification/*`
6. Create badge components with animations (support 500+ badges)
7. Create progress bar components
8. Create avatar components
9. Implement achievement animations
10. Create multi-currency display components
11. Create ELO leaderboard UI

**Key Files:**
- `platform-services/backend/deepiri-engagement-service/server.js` - Service server (port 5003)
- `platform-services/backend/deepiri-engagement-service/src/index.js` - Route handlers
- `platform-services/backend/deepiri-engagement-service/src/multiCurrencyService.js` - Multi-currency
- `platform-services/backend/deepiri-engagement-service/src/eloLeaderboardService.js` - ELO leaderboard
- `platform-services/backend/deepiri-engagement-service/src/badgeSystemService.js` - Badge system
- `deepiri-web-frontend/src/components/gamification/` - deepiri-web-frontend components

**Animation Example:**
```jsx
// src/components/gamification/Badge.jsx
import { motion } from 'framer-motion';

const Badge = ({ badge }) => (
  <motion.div
    initial={{ scale: 0 }}
    animate={{ scale: 1 }}
    whileHover={{ scale: 1.1 }}
  >
    {badge.emoji}
  </motion.div>
);
```

---

### deepiri-web-frontend Engineer 4 - SPA Optimization & PWA

**Additional Setup:**
```bash
cd deepiri-web-frontend

# Install PWA tools
npm install vite-plugin-pwa
npm install workbox-window
```

**First Tasks:**
1. Review `deepiri-web-frontend/vite.config.ts`
2. Optimize bundle size
3. Implement code splitting
4. Set up service worker
5. Create PWA manifest

**Key Files:**
- `deepiri-web-frontend/vite.config.ts`
- `deepiri-web-frontend/public/service-worker.js` (create)
- `deepiri-web-frontend/public/manifest.json` (create)
- `deepiri-web-frontend/src/utils/performance.js` (create)

**PWA Setup:**
```javascript
// vite.config.ts
import { VitePWA } from 'vite-plugin-pwa';

export default {
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}']
      }
    })
  ]
}
```

---

### deepiri-web-frontend Intern 1 (Suzzane Michelle Sellers Damons)

**Additional Setup:**
```bash
cd deepiri-web-frontend

# Install testing libraries
npm install --save-dev @testing-library/react
npm install --save-dev @testing-library/jest-dom
npm install --save-dev jest
```

**First Tasks:**
1. Review existing components
2. Write component tests
3. Fix UI bugs
4. Create small reusable components
5. Test component functionality

**Key Files:**
- `deepiri-web-frontend/src/components/common/` (create)
- `deepiri-web-frontend/tests/components/` (create)

**Test Example:**
```javascript
// tests/components/Button.test.jsx
import { render, screen } from '@testing-library/react';
import Button from '../src/components/common/Button';

test('renders button', () => {
  render(<Button>Click me</Button>);
  expect(screen.getByText('Click me')).toBeInTheDocument();
});
```

## Development Workflow

### 1. Component Development

```bash
# Create new component
cd deepiri-web-frontend/src/components
mkdir new-component
cd new-component
touch NewComponent.jsx NewComponent.css
```

### 2. Styling

We use **Tailwind CSS** for styling:

```jsx
// Example component
<div className="bg-gray-800 text-white p-4 rounded-lg">
  Content
</div>
```

### 3. State Management

We use **React Context** and **local state**:

```jsx
// For global state, use Context
// For component state, use useState/useReducer
```

### 4. API Integration

```jsx
// Use fetch or axios
import axios from 'axios';

const response = await axios.get('/api/tasks');
```

### 5. Testing

```bash
# Run tests
npm test

# Run tests in watch mode
npm test -- --watch
```

### 6. Build for Production

```bash
npm run build
```

## Key Resources

### Documentation

- **deepiri-web-frontend Team README:** `README_deepiri-web-frontend_TEAM.md`
- **FIND_YOUR_TASKS:** `FIND_YOUR_TASKS.md`
- **Getting Started:** `GETTING_STARTED.md`
- **Environment Variables:** `ENVIRONMENT_VARIABLES.md`

### Important Directories

- `deepiri-web-frontend/src/components/` - Reusable components
- `deepiri-web-frontend/src/pages/` - Page components
- `deepiri-web-frontend/src/services/` - API services
- `deepiri-web-frontend/src/styles/` - Global styles
- `deepiri-web-frontend/public/` - Static assets

### Design Resources

- Figma design files (if available)
- Brand guidelines
- Component library documentation

## Getting Help

1. Check `FIND_YOUR_TASKS.md` for your role
2. Review `README_deepiri-web-frontend_TEAM.md`
3. Ask in team channels
4. Contact deepiri-web-frontend Lead
5. Review existing component examples

---

**Welcome to the deepiri-web-frontend Team! Let's create amazing user experiences.**




