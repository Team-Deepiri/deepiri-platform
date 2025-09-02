import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Optional: disable browser and Vite cache completely
const noCacheMiddleware = () => ({
  name: 'no-cache',
  configureServer(server) {
    server.middlewares.use((_, res, next) => {
      res.setHeader('Cache-Control', 'no-store');
      next();
    });
  }
});

export default defineConfig({
  plugins: [react(), noCacheMiddleware()],
  cacheDir: false, // Turn off Vite's local cache
  server: {
    host: '0.0.0.0', // Needed for Docker container access
    port: 5173,
    strictPort: true,
    watch: {
      usePolling: true,
    },
    hmr: {
      clientPort: 5173, // Required for HMR in Docker
    }
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true
  },
  optimizeDeps: {
    esbuildOptions: {
      loader: {
        '.js': 'jsx'
      }
    }
  }
})



// import { defineConfig } from 'vite';
// import react from '@vitejs/plugin-react';

// export default defineConfig({
//   plugins: [
//     react({
//       jsxRuntime: 'classic', // Explicitly use classic JSX runtime
//       babel: {
//         plugins: [
//           ['@babel/plugin-transform-react-jsx', {
//             runtime: 'classic'
//           }]
//         ]
//       }
//     })
//   ],
//   server: {
//     port: 5173,
//     hmr: {
//       overlay: true // Disable HMR error overlay // was false before
//     }
//   },
//   build: {
//     outDir: 'dist',
//     emptyOutDir: true
//   },
//   optimizeDeps: {
//     esbuildOptions: {
//       loader: {
//         '.js': 'jsx' // Enable JSX parsing in .js files
//       }
//     }
//   }
// });
