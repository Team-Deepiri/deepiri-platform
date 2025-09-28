# Frontend Debugging & Development Guide

## Quick Start Debugging

### Development Server
```bash
cd client
npm run dev
```

### Common Debug Commands
```bash
# Check for linting errors
npm run lint

# Run tests
npm run test

# Build and check for build errors
npm run build

# Preview production build
npm run preview
```

## Debugging Tools & Techniques

### 1. **React Developer Tools**
- Install React DevTools browser extension
- Use Components tab to inspect component state/props
- Use Profiler tab to identify performance bottlenecks

### 2. **Network Debugging**
- Open browser DevTools → Network tab
- Filter by XHR/Fetch to see API calls
- Check request/response headers and payloads
- Look for 401/403 errors (authentication issues)
- Check CORS errors

### 3. **Console Debugging**
Our app has comprehensive logging. Check console for:
```javascript
// Error logs (red)
[ERROR] Authentication error
[ERROR] API error

// Warning logs (yellow)  
[WARN] Token expired

// Info logs (blue)
[INFO] User login successful
[INFO] Adventure generated

// Debug logs (gray) - only in development
[DEBUG] Component render
[DEBUG] API response time
```

### 4. **Local Storage Debugging**
```javascript
// Check authentication token
localStorage.getItem('token')

// Check error logs
JSON.parse(localStorage.getItem('errorLogs') || '[]')

// Clear all data
localStorage.clear()
```

## Common Issues & Solutions

### Authentication Issues
```javascript
// Check if user is authenticated
const { user, isAuthenticated, loading } = useAuth();
console.log('Auth State:', { user, isAuthenticated, loading });

// Force logout and re-login
const { logout } = useAuth();
logout();
```

### API Connection Issues
1. **Check environment variables:**
   ```bash
   # Create .env.local file in client directory
   VITE_API_URL=http://localhost:5000/api
   VITE_PYAGENT_URL=http://localhost:8000
   ```

2. **Verify backend is running:**
   ```bash
   curl http://localhost:5000/api/health
   ```

3. **Check CORS configuration** in server

### Component Rendering Issues
```javascript
// Add debug logging to components
import logger from '../utils/logger';

const MyComponent = () => {
  useEffect(() => {
    logger.debug('MyComponent mounted');
    return () => logger.debug('MyComponent unmounted');
  }, []);
  
  // Component logic
};
```

### State Management Issues
```javascript
// Debug React Query cache
import { useQueryClient } from 'react-query';

const queryClient = useQueryClient();
console.log('Query Cache:', queryClient.getQueryCache());

// Invalidate specific queries
queryClient.invalidateQueries('adventures');
```

##Performance Debugging

### Bundle Analysis
```bash
# Analyze bundle size
npm run build
npx vite-bundle-analyzer dist
```

### Memory Leaks
```javascript
// Check memory usage (available in Chrome)
if (performance.memory) {
  console.log('Memory Usage:', {
    used: performance.memory.usedJSHeapSize,
    total: performance.memory.totalJSHeapSize,
    limit: performance.memory.jsHeapSizeLimit
  });
}
```

### Slow Renders
```javascript
// Use React Profiler
import { Profiler } from 'react';

const onRenderCallback = (id, phase, actualDuration) => {
  if (actualDuration > 16) { // Slower than 60fps
    console.warn(`Slow render: ${id} took ${actualDuration}ms`);
  }
};

<Profiler id="MyComponent" onRender={onRenderCallback}>
  <MyComponent />
</Profiler>
```

## Development Workflow

### 1. **Before Starting Development**
```bash
# Pull latest changes
git pull origin main

# Install dependencies
npm install

# Start development server
npm run dev
```

### 2. **During Development**
- Keep browser DevTools open
- Monitor console for errors/warnings
- Test in multiple browsers
- Check responsive design (mobile/tablet)

### 3. **Before Committing**
```bash
# Run linting
npm run lint

# Run tests
npm run test

# Build to check for build errors
npm run build
```

## Error Handling Patterns

### API Error Handling
```javascript
try {
  const response = await api.getData();
  if (response.success) {
    // Handle success
  } else {
    toast.error(response.message);
  }
} catch (error) {
  console.error('API Error:', error);
  toast.error('Something went wrong');
}
```

### Component Error Boundaries
```javascript
// Wrap components that might fail
<ErrorBoundary>
  <RiskyComponent />
</ErrorBoundary>
```

### Async Error Handling
```javascript
// Handle promise rejections
window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled Promise Rejection:', event.reason);
  // Optionally prevent default browser behavior
  event.preventDefault();
});
```

## Mobile Debugging

### Chrome DevTools Mobile Simulation
1. Open DevTools → Toggle device toolbar
2. Select device or set custom dimensions
3. Test touch interactions
4. Check viewport meta tag

### Real Device Testing
```bash
# Find your local IP
ipconfig getifaddr en0  # macOS
ipconfig | findstr IPv4  # Windows

# Access via IP (ensure firewall allows)
http://YOUR_IP:5173
```

## Advanced

### Redux DevTools (if using Redux)
```javascript
// Enable Redux DevTools
const store = createStore(
  reducer,
  window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
);
```

### React Query DevTools
```javascript
import { ReactQueryDevtools } from 'react-query/devtools';

function App() {
  return (
    <>
      <YourApp />
      <ReactQueryDevtools initialIsOpen={false} />
    </>
  );
}
```

### Custom Debug Hooks
```javascript
// Debug hook for tracking renders
const useRenderCount = (componentName) => {
  const renderCount = useRef(0);
  renderCount.current++;
  console.log(`${componentName} rendered ${renderCount.current} times`);
};

// Usage
const MyComponent = () => {
  useRenderCount('MyComponent');
  // Component logic
};
```

## Useful Browser Extensions

1. **React Developer Tools** - Component inspection
2. **Redux DevTools** - State management debugging  
3. **Lighthouse** - Performance auditing
4. **Web Vitals** - Core web vitals monitoring
5. **JSON Viewer** - Pretty print JSON responses

## Monitoring & Analytics

### Error Tracking
```javascript
// Custom error reporting
window.addEventListener('error', (event) => {
  // Send to error tracking service
  fetch('/api/errors', {
    method: 'POST',
    body: JSON.stringify({
      message: event.error.message,
      stack: event.error.stack,
      url: window.location.href
    })
  });
});
```

### Performance Monitoring
```javascript
// Track page load times
window.addEventListener('load', () => {
  const loadTime = performance.timing.loadEventEnd - performance.timing.navigationStart;
  console.log(`Page loaded in ${loadTime}ms`);
});
```

---

