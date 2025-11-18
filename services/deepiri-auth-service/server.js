const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const dotenv = require('dotenv');
const winston = require('winston');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5001;

// Logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console({ format: winston.format.simple() })
  ]
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// MongoDB connection
const MONGO_URI = process.env.MONGO_URI || 'mongodb://mongodb:27017/deepiri';
mongoose.connect(MONGO_URI)
  .then(() => logger.info('Auth Service: Connected to MongoDB'))
  .catch(err => logger.error('Auth Service: MongoDB connection error', err));

// Import routes
const routes = require('./src/index');

// Routes
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'auth-service', timestamp: new Date().toISOString() });
});

app.use('/', routes);

// Error handler
app.use((err, req, res, next) => {
  logger.error('Auth Service error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  logger.info(`Auth Service running on port ${PORT}`);
});

module.exports = app;

