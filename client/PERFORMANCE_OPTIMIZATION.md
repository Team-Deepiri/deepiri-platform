# ⚡ Frontend Performance Optimization Guide

## 🎯 Current Performance Status

### Bundle Analysis
```bash
# Analyze current bundle size
npm run build
npx vite-bundle-analyzer dist
```

### Key Metrics to Monitor
- **First Contentful Paint (FCP)**: < 1.8s
- **Largest Contentful Paint (LCP)**: < 2.5s  
- **Cumulative Layout Shift (CLS)**: < 0.1
- **First Input Delay (FID)**: < 100ms
- **Bundle Size**: Target < 500KB gzipped

## 🚀 Optimization Strategies Implemented

### 1. **Code Splitting & Lazy Loading**
```javascript
// Lazy load pages
const Dashboard = lazy(() => import('./pages/Dashboard'));
const AdventureGenerator = lazy(() => import('./pages/AdventureGenerator'));

// Wrap in Suspense
<Suspense fallback={<LoadingSpinner />}>
  <Dashboard />
</Suspense>
```

### 2. **React Query Optimization**
```javascript
// Optimized query client configuration
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
    },
  },
});
```

### 3. **Image Optimization**
```javascript
// Use WebP format with fallbacks
<picture>
  <source srcSet="image.webp" type="image/webp" />
  <img src="image.jpg" alt="Description" loading="lazy" />
</picture>

// Implement image lazy loading
const LazyImage = ({ src, alt, className }) => {
  const [isLoaded, setIsLoaded] = useState(false);
  const [isInView, setIsInView] = useState(false);
  const imgRef = useRef();

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsInView(true);
          observer.disconnect();
        }
      },
      { threshold: 0.1 }
    );

    if (imgRef.current) {
      observer.observe(imgRef.current);
    }

    return () => observer.disconnect();
  }, []);

  return (
    <div ref={imgRef} className={className}>
      {isInView && (
        <img
          src={src}
          alt={alt}
          onLoad={() => setIsLoaded(true)}
          style={{ opacity: isLoaded ? 1 : 0 }}
        />
      )}
    </div>
  );
};
```

### 4. **Memoization Strategies**
```javascript
// Memoize expensive calculations
const ExpensiveComponent = memo(({ data }) => {
  const processedData = useMemo(() => {
    return data.map(item => ({
      ...item,
      processed: heavyCalculation(item)
    }));
  }, [data]);

  return <div>{/* Render processed data */}</div>;
});

// Memoize callbacks
const ParentComponent = () => {
  const handleClick = useCallback((id) => {
    // Handle click logic
  }, []);

  return <ChildComponent onClick={handleClick} />;
};
```

### 5. **Virtual Scrolling for Large Lists**
```javascript
import { FixedSizeList as List } from 'react-window';

const VirtualizedList = ({ items }) => {
  const Row = ({ index, style }) => (
    <div style={style}>
      {items[index]}
    </div>
  );

  return (
    <List
      height={600}
      itemCount={items.length}
      itemSize={50}
      width="100%"
    >
      {Row}
    </List>
  );
};
```

## 🔧 Vite Optimizations

### Build Configuration
```javascript
// vite.config.js optimizations
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          ui: ['framer-motion', 'react-hot-toast'],
          maps: ['leaflet', 'react-leaflet'],
        }
      }
    },
    chunkSizeWarningLimit: 1000,
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    }
  },
  optimizeDeps: {
    include: ['react', 'react-dom', 'react-router-dom'],
    exclude: ['@vite/client', '@vite/env']
  }
});
```

### Development Optimizations
```javascript
// Disable source maps in production
build: {
  sourcemap: process.env.NODE_ENV === 'development'
}
```

## 📊 Performance Monitoring

### Core Web Vitals Tracking
```javascript
// utils/performance.js
export const trackWebVitals = (onPerfEntry) => {
  if (onPerfEntry && onPerfEntry instanceof Function) {
    import('web-vitals').then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => {
      getCLS(onPerfEntry);
      getFID(onPerfEntry);
      getFCP(onPerfEntry);
      getLCP(onPerfEntry);
      getTTFB(onPerfEntry);
    });
  }
};

// In main.jsx
trackWebVitals((metric) => {
  console.log(metric);
  // Send to analytics service
});
```

### Bundle Size Monitoring
```javascript
// Check bundle size in CI/CD
const fs = require('fs');
const path = require('path');

const distPath = path.join(__dirname, 'dist');
const stats = fs.statSync(path.join(distPath, 'assets'));

if (stats.size > 500 * 1024) { // 500KB limit
  console.error('Bundle size exceeds limit!');
  process.exit(1);
}
```

## 🎨 CSS Optimizations

### Critical CSS Inlining
```javascript
// Extract critical CSS for above-the-fold content
const criticalCSS = `
  .navbar { /* Critical navbar styles */ }
  .hero { /* Critical hero styles */ }
  .loading { /* Critical loading styles */ }
`;
```

### CSS-in-JS Optimization
```javascript
// Use CSS variables for dynamic theming
const theme = {
  primary: 'var(--primary)',
  secondary: 'var(--secondary)',
  // Reduces runtime CSS generation
};
```

## 🌐 Network Optimizations

### API Request Optimization
```javascript
// Implement request deduplication
const requestCache = new Map();

const deduplicatedFetch = async (url, options) => {
  const key = `${url}-${JSON.stringify(options)}`;
  
  if (requestCache.has(key)) {
    return requestCache.get(key);
  }
  
  const promise = fetch(url, options);
  requestCache.set(key, promise);
  
  // Clean up after request completes
  promise.finally(() => {
    setTimeout(() => requestCache.delete(key), 1000);
  });
  
  return promise;
};
```

### Preloading Critical Resources
```javascript
// Preload critical resources
useEffect(() => {
  // Preload critical API endpoints
  const link = document.createElement('link');
  link.rel = 'preload';
  link.href = '/api/user/profile';
  link.as = 'fetch';
  document.head.appendChild(link);
}, []);
```

## 🧪 Performance Testing

### Lighthouse CI Integration
```yaml
# .github/workflows/lighthouse.yml
name: Lighthouse CI
on: [push]
jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Lighthouse CI
        run: |
          npm install -g @lhci/cli@0.8.x
          lhci autorun
```

### Performance Budget
```json
{
  "budget": [
    {
      "path": "/*",
      "timings": [
        {
          "metric": "first-contentful-paint",
          "budget": 2000
        },
        {
          "metric": "largest-contentful-paint", 
          "budget": 2500
        }
      ],
      "resourceSizes": [
        {
          "resourceType": "script",
          "budget": 400
        },
        {
          "resourceType": "total",
          "budget": 500
        }
      ]
    }
  ]
}
```

## 🔍 Performance Debugging Tools

### React DevTools Profiler
```javascript
// Wrap components for profiling
import { Profiler } from 'react';

const onRenderCallback = (id, phase, actualDuration, baseDuration, startTime, commitTime) => {
  if (actualDuration > 16) { // Slower than 60fps
    console.warn(`Slow render detected: ${id}`, {
      phase,
      actualDuration,
      baseDuration
    });
  }
};

<Profiler id="App" onRender={onRenderCallback}>
  <App />
</Profiler>
```

### Memory Leak Detection
```javascript
// Monitor memory usage
const monitorMemory = () => {
  if (performance.memory) {
    const memory = performance.memory;
    console.log('Memory usage:', {
      used: `${Math.round(memory.usedJSHeapSize / 1024 / 1024)}MB`,
      total: `${Math.round(memory.totalJSHeapSize / 1024 / 1024)}MB`,
      limit: `${Math.round(memory.jsHeapSizeLimit / 1024 / 1024)}MB`
    });
  }
};

// Run every 30 seconds in development
if (process.env.NODE_ENV === 'development') {
  setInterval(monitorMemory, 30000);
}
```

## 📱 Mobile Performance

### Touch Optimization
```css
/* Improve touch responsiveness */
.interactive-element {
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
}
```

### Viewport Optimization
```html
<!-- Optimized viewport meta tag -->
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
```

## 🎯 Performance Checklist

### Before Deployment
- [ ] Run Lighthouse audit (score > 90)
- [ ] Check bundle size (< 500KB gzipped)
- [ ] Test on slow 3G network
- [ ] Verify lazy loading works
- [ ] Check for memory leaks
- [ ] Test on low-end devices
- [ ] Verify critical CSS is inlined
- [ ] Check image optimization
- [ ] Test offline functionality
- [ ] Verify service worker caching

### Ongoing Monitoring
- [ ] Set up performance monitoring
- [ ] Track Core Web Vitals
- [ ] Monitor bundle size changes
- [ ] Regular Lighthouse audits
- [ ] User experience metrics
- [ ] Error rate monitoring

---

## 🚀 Quick Performance Wins

1. **Enable gzip compression** on server
2. **Use CDN** for static assets
3. **Implement service worker** for caching
4. **Optimize images** (WebP, lazy loading)
5. **Code splitting** for routes
6. **Tree shaking** unused code
7. **Preload critical resources**
8. **Minimize render blocking resources**
9. **Use React.memo** for expensive components
10. **Implement virtual scrolling** for large lists

Remember: **Measure first, optimize second!** 📊
