const winston = require('winston');
const path = require('path');
const fs = require('fs');

/**
 * Logger Utility for Auth Service
 * Provides consistent logging for the auth service
 */
const isDocker = process.env.NODE_ENV === 'production' || process.env.DOCKER === 'true' || fs.existsSync('/.dockerenv');
const defaultLogsDir = isDocker ? '/app/logs' : path.join(process.cwd(), 'logs');
const envLogsDir = process.env.LOG_DIR;
let logsDir = defaultLogsDir;

if (envLogsDir && typeof envLogsDir === 'string') {
  if (path.isAbsolute(envLogsDir)) {
    if (isDocker && envLogsDir.startsWith('/app/')) {
      logsDir = envLogsDir;
    } else if (!isDocker) {
      logsDir = envLogsDir;
    }
  } else {
    logsDir = path.join(defaultLogsDir, envLogsDir);
  }
}

if (!fs.existsSync(logsDir)) {
  try {
    fs.mkdirSync(logsDir, { recursive: true });
  } catch (error) {
    console.error(`Failed to create logs directory: ${logsDir}`, error);
    logsDir = path.join(process.cwd(), 'logs');
    if (!fs.existsSync(logsDir)) {
      fs.mkdirSync(logsDir, { recursive: true });
    }
  }
}

const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.prettyPrint()
);

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  defaultMeta: { service: 'auth-service' },
  transports: [
    new winston.transports.File({
      filename: path.join(logsDir, 'auth-service-error.log'),
      level: 'error',
      maxsize: 5242880,
      maxFiles: 5,
    }),
    new winston.transports.File({
      filename: path.join(logsDir, 'auth-service-combined.log'),
      maxsize: 5242880,
      maxFiles: 5,
    }),
  ],
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

module.exports = logger;

