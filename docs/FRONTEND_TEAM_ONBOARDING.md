# Frontend Team Onboarding Guide

Welcome to the Deepiri Frontend Team! This guide will help you get set up and start building beautiful user interfaces.

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

### Required Accounts

- **Firebase Account** (for authentication)
- **GitHub Account** (for repository access)
- **Figma Access** (for design files, if available)

### System Requirements

- **RAM:** 8GB minimum, 16GB+ recommended
- **Storage:** 10GB+ free space
- **OS:** Windows 10+, macOS 10.15+, or Linux

## Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd Deepiri/deepiri
```

### 2. Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Copy environment file
cp env.example.client .env

# Edit .env with your configuration
# VITE_API_URL=http://localhost:5000
# VITE_AI_SERVICE_URL=http://localhost:8000
# VITE_FIREBASE_API_KEY=your-key
```

### 3. Start Development Server

```bash
npm run dev
```

Frontend runs on http://localhost:3000

### 4. Verify Setup

```bash
# Check if server is running
curl http://localhost:3000

# Check backend connection
# Open browser to http://localhost:3000
```

## Role-Specific Setup

### Frontend Lead

**Additional Setup:**
```bash
# Install design system tools
npm install storybook
npm install @storybook/react
```

**First Tasks:**
1. Review `frontend/src/App.jsx`
2. Review component structure
3. Establish design system
4. Set up component library
5. Review UX/UI consistency

**Key Files:**
- `frontend/src/App.jsx`
- `frontend/src/components/`
- `frontend/src/pages/`
- `frontend/vite.config.js`

---

### Graphic Designer

**Additional Setup:**
- **Figma** (design tool)
- **Adobe Creative Suite** (optional)
- **SVG optimization tools**

**First Tasks:**
1. Review existing assets in `frontend/public/`
2. Review `frontend/src/assets/`
3. Create logo and branding assets
4. Design system assets
5. Icon sets

**Key Files:**
- `frontend/public/` (favicon, logos)
- `frontend/src/assets/` (create branding assets)
- `frontend/src/styles/brand.css` (create)

**Asset Guidelines:**
- Logo: SVG format, multiple sizes
- Icons: SVG sprite or icon font
- Colors: Define in CSS variables
- Typography: Define font families

---

### Frontend Engineer 1 - Web Pages & Forms

**Additional Setup:**
```bash
cd frontend

# Install form libraries
npm install react-hook-form
npm install yup
npm install @hookform/resolvers

# Install Firebase
npm install firebase
```

**First Tasks:**
1. Review `frontend/src/pages/`
2. Review `frontend/src/components/`
3. Create dashboard pages
4. Implement form components
5. Integrate Firebase authentication

**Key Files:**
- `frontend/src/pages/Dashboard.jsx` (create)
- `frontend/src/components/forms/` (create)
- `frontend/src/services/firebase.js` (create)

**Component Example:**
```jsx
// src/components/forms/FormValidation.jsx
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
```

---

### Frontend Engineer 2 (Melvin) - AI/Visualization Dashboards

**Additional Setup:**
```bash
cd frontend

# Install charting and visualization libraries
npm install recharts d3
npm install @influxdata/influxdb-client  # For time-series data
npm install react-query  # For data fetching
```

**First Tasks:**
1. Review `services/analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series
2. Review `services/analytics-service/src/behavioralClustering.js` - NEW: Clustering
3. Review `services/analytics-service/src/predictiveModeling.js` - NEW: Predictive models
4. Create AI visualization dashboards
5. Implement time-series charts (InfluxDB integration)
6. Create clustering visualizations
7. Create predictive model visualizations
8. Build real-time analytics displays

**Key Files:**
- `services/analytics-service/src/timeSeriesAnalytics.js` - NEW: Time-series analytics
- `services/analytics-service/src/behavioralClustering.js` - NEW: Behavioral clustering
- `services/analytics-service/src/predictiveModeling.js` - NEW: Predictive modeling
- `frontend/src/pages/analytics/` - Analytics pages
- `frontend/src/components/charts/` - Chart components

---

### Frontend Engineer 2 (Melvin) - AI/Visualization Dashboards (Updated)

**Additional Setup:**
```bash
cd frontend

# Install charting libraries
npm install recharts
npm install d3
npm install chart.js react-chartjs-2
npm install date-fns
```

**First Tasks:**
1. Review `frontend/src/pages/analytics/`
2. Create productivity charts
3. Create AI insights visualization
4. Build analytics dashboard
5. Implement real-time data updates

**Key Files:**
- `frontend/src/pages/analytics/Dashboard.jsx` (create)
- `frontend/src/components/charts/` (create)
- `frontend/src/pages/ProductivityChat.jsx` (existing)

**Chart Example:**
```jsx
// src/components/charts/ProductivityChart.jsx
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts';
```

---

### Frontend Engineer 3 - Gamification Visuals

**Additional Setup:**
```bash
cd frontend

# Install animation libraries
npm install framer-motion
npm install react-spring
npm install lottie-react  # for Lottie animations
```

**First Tasks:**
1. Review `services/gamification-service/src/multiCurrencyService.js` - NEW: Multi-currency
2. Review `services/gamification-service/src/eloLeaderboardService.js` - NEW: ELO ranking
3. Review `services/gamification-service/src/badgeSystemService.js` - NEW: Badge system (500+ badges)
4. Review gamification components
5. Create badge components with animations (support 500+ badges)
6. Create progress bar components
7. Create avatar components
8. Implement achievement animations
9. Create multi-currency display components
10. Create ELO leaderboard UI

**Key Files:**
- `services/gamification-service/src/multiCurrencyService.js` - NEW: Multi-currency
- `services/gamification-service/src/eloLeaderboardService.js` - NEW: ELO leaderboard
- `services/gamification-service/src/badgeSystemService.js` - NEW: Badge system
- `frontend/src/components/gamification/` (create)
- `api-server/services/gamificationService.js` (review)

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

### Frontend Engineer 4 - SPA Optimization & PWA

**Additional Setup:**
```bash
cd frontend

# Install PWA tools
npm install vite-plugin-pwa
npm install workbox-window
```

**First Tasks:**
1. Review `frontend/vite.config.js`
2. Optimize bundle size
3. Implement code splitting
4. Set up service worker
5. Create PWA manifest

**Key Files:**
- `frontend/vite.config.js`
- `frontend/public/service-worker.js` (create)
- `frontend/public/manifest.json` (create)
- `frontend/src/utils/performance.js` (create)

**PWA Setup:**
```javascript
// vite.config.js
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

### Frontend Intern 1 (Suzzane Michelle Sellers Damons)

**Additional Setup:**
```bash
cd frontend

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
- `frontend/src/components/common/` (create)
- `frontend/tests/components/` (create)

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
cd frontend/src/components
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

- **Frontend Team README:** `README_FRONTEND_TEAM.md`
- **FIND_YOUR_TASKS:** `FIND_YOUR_TASKS.md`
- **Environment Setup:** `ENVIRONMENT_SETUP.md`

### Important Directories

- `frontend/src/components/` - Reusable components
- `frontend/src/pages/` - Page components
- `frontend/src/services/` - API services
- `frontend/src/styles/` - Global styles
- `frontend/public/` - Static assets

### Design Resources

- Figma design files (if available)
- Brand guidelines
- Component library documentation

## Getting Help

1. Check `FIND_YOUR_TASKS.md` for your role
2. Review `README_FRONTEND_TEAM.md`
3. Ask in team channels
4. Contact Frontend Lead
5. Review existing component examples

---

**Welcome to the Frontend Team! Let's create amazing user experiences.**

