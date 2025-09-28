#!/usr/bin/env node

console.log('🚀 Starting Tripblip Frontend with Super Fast HMR...\n');

// Clear any cached modules
delete require.cache;

// Set environment for optimal development
process.env.NODE_ENV = 'development';
process.env.FORCE_COLOR = '1'; // Enable colors in terminal

// Import and start Vite
import('vite').then(async ({ createServer }) => {
  try {
    const server = await createServer({
      configFile: './vite.config.js',
      server: {
        // Force immediate HMR updates
        hmr: {
          overlay: true,
          port: 5173
        }
      }
    });
    
    await server.listen();
    
    console.log('✅ Frontend started successfully!');
    console.log('🔥 Hot Module Replacement is ACTIVE');
    console.log('💾 Changes will update instantly when you save files');
    console.log('🌐 Open: http://localhost:5173\n');
    
    // Log HMR status
    server.ws.on('connection', () => {
      console.log('🔌 HMR WebSocket connected - Ready for instant updates!');
    });
    
  } catch (error) {
    console.error('❌ Failed to start development server:', error);
    process.exit(1);
  }
}).catch(console.error);
