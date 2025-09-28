import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    react({
      // Enable React Fast Refresh for instant updates
      fastRefresh: true,
      include: "**/*.{jsx,tsx,js,ts}",
    })
  ],
  
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    open: false, // Disabled auto-open to prevent WSL errors
    
    // Optimized file watching for instant updates
    watch: {
      usePolling: true,
      interval: 50, // Check every 50ms for super fast updates
      binaryInterval: 100,
    },
    
    // Enhanced HMR for instant updates
    hmr: {
      port: 5173,
      overlay: true, // Show errors immediately
    },
    
    // API proxy
    proxy: {
      '/api': {
        target: 'http://localhost:5000',
        changeOrigin: true,
        secure: false,
      }
    }
  },
  
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: true, // Always enable for debugging
  },
  
  // Optimized dependency handling for HMR
  optimizeDeps: {
    include: ['react', 'react-dom', 'framer-motion'],
    esbuildOptions: {
      loader: {
        '.js': 'jsx'
      }
    }
  },
  
  // Enable CSS HMR
  css: {
    devSourcemap: true
  }
})