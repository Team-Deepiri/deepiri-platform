const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
const mongoose = require('mongoose');
const { createServer } = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

// Import services
const adventureService = require('./services/adventureService');
const userService = require('./services/userService');
const eventService = require('./services/eventService');
const notificationService = require('./services/notificationService');
const aiOrchestrator = require('./services/aiOrchestrator');
const cacheService = require('./services/cacheService');

// Import routes
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const adventureRoutes = require('./routes/adventureRoutes');
const agentRoutes = require('./routes/agentRoutes');
const eventRoutes = require('./routes/eventRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const externalRoutes = require('./routes/externalRoutes');

// Import middleware
const authenticateJWT = require('./middleware/authenticateJWT');
const { errorHandler, notFoundHandler, gracefulShutdown } = require('./middleware/errorHandler');
const logger = require('./utils/logger');
const promClient = require('prom-client');
const { v4: uuidv4 } = require('uuid');
const ipFilter = require('./middleware/ipFilter');
const sanitize = require('./middleware/sanitize');
const rateBot = require('./middleware/rateBot');
const auditLogger = require('./middleware/auditLogger');
const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');

const app = express();
const server = createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.CORS_ORIGIN || "http://localhost:5173",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 5000;

// Security middleware
app.use(helmet());
app.use(compression());
app.use(ipFilter());
app.use(sanitize());
app.use(rateBot());
app.use(auditLogger());

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Logging
app.use((req, res, next) => {
  req.requestId = uuidv4();
  res.setHeader('x-request-id', req.requestId);
  next();
});
app.use(morgan(':method :url :status :res[content-length] - :response-time ms :req[x-request-id]', {
  stream: { write: message => logger.info(message.trim()) }
}));

// Metrics
const collectDefaultMetrics = promClient.collectDefaultMetrics;
collectDefaultMetrics();
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'code']
});
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, code: res.statusCode });
  });
  next();
});

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || "http://localhost:5173",
  credentials: true
}));

// Body parsing middleware
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '10mb' }));

// OpenAPI docs (disabled by default in production)
const swaggerEnabled = process.env.SWAGGER_ENABLED === 'true' || process.env.NODE_ENV !== 'production';
if (swaggerEnabled) {
  const swaggerSpec = swaggerJsdoc({
    definition: {
      openapi: '3.0.0',
      info: { title: 'Trailblip API', version: '2.0.0' }
    },
    apis: []
  });
  app.use('/api-docs', (req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Cache-Control', 'no-store');
    next();
  }, swaggerUi.serve, swaggerUi.setup(swaggerSpec, { explorer: false }));
}

// Database connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/trailblip_mag', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => {
  logger.info('Connected to MongoDB');
})
.catch((error) => {
  logger.error('MongoDB connection error:', error);
  process.exit(1);
});

// Initialize services
cacheService.initialize();
aiOrchestrator.initialize();

// Socket.IO connection handling
io.on('connection', (socket) => {
  logger.info(`User connected: ${socket.id}`);
  
  socket.on('join_user_room', (userId) => {
    socket.join(`user_${userId}`);
    logger.info(`User ${userId} joined their room`);
  });
  
  socket.on('join_adventure_room', (adventureId) => {
    socket.join(`adventure_${adventureId}`);
    logger.info(`User joined adventure room: ${adventureId}`);
  });
  
  socket.on('disconnect', () => {
    logger.info(`User disconnected: ${socket.id}`);
  });
});

// Make io available to routes
app.use((req, res, next) => {
  req.io = io;
  next();
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', authenticateJWT, userRoutes);
app.use('/api/adventures', authenticateJWT, adventureRoutes);
app.use('/api/events', authenticateJWT, eventRoutes);
app.use('/api/notifications', authenticateJWT, notificationRoutes);
app.use('/api/external', externalRoutes);
app.use('/api/agent', authenticateJWT, agentRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '2.0.0',
    services: {
      database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
      cache: cacheService.isConnected() ? 'connected' : 'disconnected',
      ai: aiOrchestrator.isInitialized() ? 'ready' : 'initializing'
    }
  });
});

app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', promClient.register.contentType);
    res.end(await promClient.register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

// Serve static files from the React app in production
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, '../client/dist')));
  
  // Catch all handler: send back React's index.html file
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../client/dist/index.html'));
  });
}

// 404 handler for unmatched routes
app.use(notFoundHandler);

// Error handling middleware
app.use(errorHandler);

// Graceful shutdown handlers
process.on('SIGTERM', gracefulShutdown(server));
process.on('SIGINT', gracefulShutdown(server));

server.listen(PORT, () => {
  logger.info(`MAG 2.0 Server is running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = { app, server, io };