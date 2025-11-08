# Frontend Team - Deepiri

## Team Overview
The Frontend Team develops React 18 + Tailwind UI, implements challenge delivery, timers, hints, real-time updates, and builds responsive/mobile-first views.

## Core Responsibilities

### Frontend Lead
- Oversee React/Vite web apps
- UX/UI consistency
- Component library standards
- Performance optimization

### Frontend Engineers
- **Web Pages & Forms**: Dashboard, forms, Firebase integration
- **AI/Visualization Dashboards**: Charting, data visualization
- **Gamification Visuals**: Badges, progress bars, avatars
- **SPA Optimization**: PWA support, performance tuning

### Graphic Designer
- Logo design
- Branding
- Visual identity

## Current Frontend Structure

### Technology Stack
- React 18
- Vite
- Tailwind CSS
- Socket.IO Client
- Firebase (authentication)

### Directory Structure
```
frontend/
├── src/
│   ├── components/     # Reusable components
│   ├── pages/          # Page components
│   ├── api/            # API client functions
│   ├── contexts/       # React contexts
│   ├── hooks/          # Custom hooks
│   ├── utils/          # Utilities
│   └── styles/         # CSS files
├── public/             # Static assets
└── dist/               # Build output
```

## Getting Started

### Prerequisites
- Node.js 18+
- npm or yarn

### Setup
```bash
cd frontend
npm install
cp env.example.client .env
# Configure environment variables
```

### Running Development Server
```bash
npm run dev
# Server runs on http://localhost:5173
```

### Building for Production
```bash
npm run build
npm run preview
```

## Key Features to Implement

### Challenge Delivery UI
- Challenge display component
- Timer component
- Progress tracking
- Hint system UI
- Completion animations

### Gamification UI
- Points display
- Badge showcase
- Leaderboard component
- Streak counter
- Level progression indicator
- Avatar customization

### Real-time Updates
- WebSocket connection management
- Live challenge updates
- Notification system
- Leaderboard real-time updates
- Multiplayer session UI

### Dashboard
- Task overview
- Challenge history
- Analytics visualization
- Productivity insights
- Integration status

## Component Library

### Core Components Needed
- `ChallengeCard` - Display challenge information
- `Timer` - Countdown timer for challenges
- `ProgressBar` - Progress visualization
- `Badge` - Badge display component
- `Leaderboard` - Leaderboard table/list
- `NotificationToast` - Notification display
- `TaskInput` - Task creation/editing form
- `IntegrationCard` - External service integration UI

### Gamification Components
- `PointsDisplay` - Points counter
- `StreakCounter` - Streak visualization
- `LevelIndicator` - Level and XP display
- `AchievementModal` - Achievement unlock animation
- `AvatarEditor` - Avatar customization

## API Integration

### API Client
Located in `src/api/`
- Authentication API
- Task API
- Challenge API
- Gamification API
- Analytics API
- Integration API

### WebSocket Integration
```javascript
import io from 'socket.io-client';

const socket = io('http://localhost:5000', {
  transports: ['websocket', 'polling']
});

socket.on('challenge-generated', (data) => {
  // Handle new challenge
});

socket.on('progress-update', (data) => {
  // Update challenge progress
});
```

## Styling Guidelines

### Tailwind CSS
- Use Tailwind utility classes
- Custom components in `src/styles/`
- Responsive design with mobile-first approach
- Dark mode support (if needed)

### Design System
- Consistent color palette
- Typography scale
- Spacing system
- Component variants

## State Management

### React Contexts
- `AuthContext` - User authentication state
- `ChallengeContext` - Active challenge state
- `GamificationContext` - Points, badges, leaderboard

### Custom Hooks
- `useWebSocket` - WebSocket connection management
- `useChallenge` - Challenge operations
- `useGamification` - Gamification data

## Performance Optimization

### Code Splitting
- Route-based code splitting
- Lazy loading for heavy components
- Dynamic imports

### Optimization Techniques
- React.memo for expensive components
- useMemo and useCallback for expensive computations
- Virtual scrolling for long lists
- Image optimization

## Mobile Responsiveness

### Breakpoints
- Mobile: < 640px
- Tablet: 640px - 1024px
- Desktop: > 1024px

### Mobile-First Features
- Touch-friendly interactions
- Swipe gestures
- Mobile navigation
- Responsive charts and visualizations

## Testing

### Testing Strategy
- Component testing with React Testing Library
- E2E testing (if needed)
- Visual regression testing
- Accessibility testing

## Next Steps
1. Build challenge delivery UI components
2. Implement real-time WebSocket integration
3. Create gamification visualization components
4. Build dashboard and analytics views
5. Implement mobile-responsive design
6. Add PWA support
7. Optimize performance
8. Create component library documentation

## Resources
- React Documentation
- Vite Documentation
- Tailwind CSS Documentation
- Socket.IO Client Documentation
- Firebase Documentation

