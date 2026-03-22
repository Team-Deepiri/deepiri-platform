#!/usr/bin/env node

/**
 * Enhanced Development Server Starter
 * Ensures optimal real-time updates for both frontend and backend
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

console.log(' Starting Deepiri Development Environment with Real-time Updates...\n');

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

// Function to log with colors and timestamps
function log(message, color = colors.reset) {
  const timestamp = new Date().toLocaleTimeString();
  console.log(`${color}[${timestamp}] ${message}${colors.reset}`);
}

// Check if required directories exist
const frontendDir = path.join(__dirname, 'deepiri-web-frontend');
const apiServerDir = path.join(__dirname, 'deepiri-core-api');

if (!fs.existsSync(frontendDir)) {
  log('Frontend directory not found!', colors.red);
  process.exit(1);
}

if (!fs.existsSync(apiServerDir)) {
  log('API Server directory not found!', colors.red);
  process.exit(1);
}

// Start API server
log('Starting API Server...', colors.blue);
const serverProcess = spawn('node', ['server.js'], {
  cwd: apiServerDir,
  stdio: 'inherit',
  shell: true,
  env: {
    ...process.env,
    NODE_ENV: 'development',
    CHOKIDAR_USEPOLLING: 'true', // For better file watching
    VITE_HMR: 'true'
  }
});

// Wait a moment for server to start
setTimeout(() => {
  // Start frontend with enhanced settings
  log('Starting Frontend with Hot Module Replacement...', colors.cyan);
  const clientProcess = spawn('npm', ['run', 'dev'], {
    cwd: frontendDir,
    stdio: 'inherit',
    shell: true,
    env: {
      ...process.env,
      NODE_ENV: 'development',
      CHOKIDAR_USEPOLLING: 'true',
      FAST_REFRESH: 'true',
      GENERATE_SOURCEMAP: 'true'
    }
  });

  // Handle frontend process events
  clientProcess.on('error', (error) => {
    log(`Frontend Error: ${error.message}`, colors.red);
  });

  clientProcess.on('exit', (code) => {
    if (code !== 0) {
      log(`Frontend exited with code ${code}`, colors.red);
    }
    serverProcess.kill();
    process.exit(code);
  });
}, 2000);

// Handle API server process events
serverProcess.on('error', (error) => {
  log(`API Server Error: ${error.message}`, colors.red);
});

serverProcess.on('exit', (code) => {
  if (code !== 0) {
    log(`Backend exited with code ${code}`, colors.red);
  }
  process.exit(code);
});

// Handle process termination
process.on('SIGINT', () => {
  log('\nShutting down development servers...', colors.yellow);
  serverProcess.kill('SIGINT');
  process.exit(0);
});

process.on('SIGTERM', () => {
  log('\nShutting down development servers...', colors.yellow);
  serverProcess.kill('SIGTERM');
  process.exit(0);
});

// Success message
setTimeout(() => {
  log('Development environment is starting up!', colors.green);
  log('Frontend: http://localhost:5173', colors.green);
  log('Backend API: http://localhost:5000', colors.green);
  log(' Real-time updates are enabled!', colors.green);
  log('Use Ctrl+C to stop both servers', colors.yellow);
}, 3000);
