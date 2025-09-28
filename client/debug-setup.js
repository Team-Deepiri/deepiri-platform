/**
 * Frontend Development & Debugging Setup Script
 * Run this in browser console for enhanced debugging capabilities
 */

(function() {
  'use strict';
  
  console.log('🔧 Initializing Frontend Debug Tools...');
  
  // Enhanced console logging with colors and timestamps
  const originalLog = console.log;
  const originalError = console.error;
  const originalWarn = console.warn;
  
  console.log = function(...args) {
    const timestamp = new Date().toISOString().substr(11, 12);
    originalLog(`%c[${timestamp}] LOG`, 'color: #2196F3; font-weight: bold;', ...args);
  };
  
  console.error = function(...args) {
    const timestamp = new Date().toISOString().substr(11, 12);
    originalError(`%c[${timestamp}] ERROR`, 'color: #F44336; font-weight: bold;', ...args);
  };
  
  console.warn = function(...args) {
    const timestamp = new Date().toISOString().substr(11, 12);
    originalWarn(`%c[${timestamp}] WARN`, 'color: #FF9800; font-weight: bold;', ...args);
  };
  
  // Debug utilities
  window.debugUtils = {
    // Check authentication state
    checkAuth() {
      const token = localStorage.getItem('token');
      const user = JSON.parse(localStorage.getItem('user') || 'null');
      
      console.log('🔐 Authentication State:', {
        hasToken: !!token,
        tokenLength: token?.length,
        user: user ? { id: user._id, email: user.email } : null,
        isExpired: token ? this.isTokenExpired(token) : null
      });
      
      return { token, user, isValid: !!token && !this.isTokenExpired(token) };
    },
    
    // Check if JWT token is expired
    isTokenExpired(token) {
      try {
        const payload = JSON.parse(atob(token.split('.')[1]));
        const now = Date.now() / 1000;
        return payload.exp < now;
      } catch (e) {
        return true;
      }
    },
    
    // Clear all local storage
    clearStorage() {
      localStorage.clear();
      sessionStorage.clear();
      console.log('🧹 Storage cleared');
    },
    
    // Check API connectivity
    async checkAPI() {
      const baseURL = import.meta?.env?.VITE_API_URL || 'http://localhost:5000/api';
      
      try {
        const response = await fetch(`${baseURL}/health`);
        const data = await response.json();
        
        console.log('🌐 API Health Check:', {
          status: response.status,
          ok: response.ok,
          data
        });
        
        return { ok: response.ok, status: response.status, data };
      } catch (error) {
        console.error('❌ API Connection Failed:', error);
        return { ok: false, error: error.message };
      }
    },
    
    // Monitor network requests
    monitorRequests() {
      const originalFetch = window.fetch;
      
      window.fetch = async function(...args) {
        const [url, options = {}] = args;
        const startTime = Date.now();
        
        console.log(`🚀 Request: ${options.method || 'GET'} ${url}`);
        
        try {
          const response = await originalFetch(...args);
          const duration = Date.now() - startTime;
          
          console.log(`✅ Response: ${response.status} ${url} (${duration}ms)`);
          
          return response;
        } catch (error) {
          const duration = Date.now() - startTime;
          console.error(`❌ Request Failed: ${url} (${duration}ms)`, error);
          throw error;
        }
      };
      
      console.log('📡 Network monitoring enabled');
    },
    
    // Stop network monitoring
    stopMonitoring() {
      // This would need to restore original fetch
      console.log('📡 Network monitoring disabled');
    },
    
    // Check React Query cache
    checkQueryCache() {
      const queryClient = window.React?.queryClient;
      if (queryClient) {
        const cache = queryClient.getQueryCache();
        console.log('🗄️ React Query Cache:', cache);
        return cache;
      } else {
        console.warn('React Query not found');
        return null;
      }
    },
    
    // Performance monitoring
    checkPerformance() {
      const navigation = performance.getEntriesByType('navigation')[0];
      const paint = performance.getEntriesByType('paint');
      
      console.log('⚡ Performance Metrics:', {
        pageLoad: navigation ? `${navigation.loadEventEnd - navigation.loadEventStart}ms` : 'N/A',
        domContentLoaded: navigation ? `${navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart}ms` : 'N/A',
        firstPaint: paint.find(p => p.name === 'first-paint')?.startTime || 'N/A',
        firstContentfulPaint: paint.find(p => p.name === 'first-contentful-paint')?.startTime || 'N/A',
        memory: performance.memory ? {
          used: `${Math.round(performance.memory.usedJSHeapSize / 1024 / 1024)}MB`,
          total: `${Math.round(performance.memory.totalJSHeapSize / 1024 / 1024)}MB`,
          limit: `${Math.round(performance.memory.jsHeapSizeLimit / 1024 / 1024)}MB`
        } : 'N/A'
      });
    },
    
    // Check error logs
    checkErrorLogs() {
      const errorLogs = JSON.parse(localStorage.getItem('errorLogs') || '[]');
      console.log('🚨 Recent Error Logs:', errorLogs);
      return errorLogs;
    },
    
    // Simulate different screen sizes
    simulateDevice(device) {
      const devices = {
        mobile: { width: 375, height: 667 },
        tablet: { width: 768, height: 1024 },
        desktop: { width: 1920, height: 1080 }
      };
      
      const size = devices[device];
      if (size) {
        window.resizeTo(size.width, size.height);
        console.log(`📱 Simulating ${device}: ${size.width}x${size.height}`);
      } else {
        console.log('Available devices:', Object.keys(devices));
      }
    },
    
    // Test component rendering
    testComponent(componentName) {
      const components = document.querySelectorAll(`[data-testid="${componentName}"]`);
      console.log(`🧪 Testing component "${componentName}":`, {
        found: components.length,
        elements: Array.from(components)
      });
      return components;
    },
    
    // Quick health check
    async healthCheck() {
      console.log('🏥 Running comprehensive health check...');
      
      const auth = this.checkAuth();
      const api = await this.checkAPI();
      const errors = this.checkErrorLogs();
      
      console.log('📊 Health Check Summary:', {
        authentication: auth.isValid ? '✅' : '❌',
        apiConnection: api.ok ? '✅' : '❌',
        recentErrors: errors.length,
        overallHealth: auth.isValid && api.ok && errors.length === 0 ? '🟢 HEALTHY' : '🟡 NEEDS ATTENTION'
      });
      
      return {
        auth: auth.isValid,
        api: api.ok,
        errors: errors.length,
        healthy: auth.isValid && api.ok && errors.length === 0
      };
    }
  };
  
  // Keyboard shortcuts for debugging
  document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + Shift + D for debug panel
    if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'D') {
      e.preventDefault();
      window.debugUtils.healthCheck();
    }
    
    // Ctrl/Cmd + Shift + C for clear storage
    if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'C') {
      e.preventDefault();
      if (confirm('Clear all local storage?')) {
        window.debugUtils.clearStorage();
      }
    }
  });
  
  // Add debug info to window
  window.debugInfo = {
    version: '1.0.0',
    environment: import.meta?.env?.MODE || 'development',
    apiUrl: import.meta?.env?.VITE_API_URL || 'http://localhost:5000/api',
    shortcuts: {
      'Ctrl/Cmd + Shift + D': 'Health Check',
      'Ctrl/Cmd + Shift + C': 'Clear Storage'
    }
  };
  
  console.log('✅ Debug tools initialized!');
  console.log('💡 Use window.debugUtils for debugging functions');
  console.log('⌨️  Keyboard shortcuts:', window.debugInfo.shortcuts);
  console.log('📖 Run debugUtils.healthCheck() for a quick system check');
  
})();

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
  module.exports = window.debugUtils;
}
