import winston from 'winston';
import path from 'path';
import fs from 'fs';

/**
 * Shared Logger Utility for Deepiri Microservices
 * Provides consistent logging across all services
 */
export function createLogger(serviceName: string = 'service'): winston.Logger {
  // Determine logs directory based on environment
  const isDocker = process.env.NODE_ENV === 'production' || process.env.DOCKER === 'true' || fs.existsSync('/.dockerenv');
  const defaultLogsDir = isDocker ? '/app/logs' : path.join(process.cwd(), 'logs');
  const envLogsDir = process.env.LOG_DIR;
  let logsDir = defaultLogsDir;

  if (envLogsDir && typeof envLogsDir === 'string') {
    if (path.isAbsolute(envLogsDir)) {
      // In Docker, only allow absolute paths under /app
      if (isDocker && envLogsDir.startsWith('/app/')) {
        logsDir = envLogsDir;
      } else if (!isDocker) {
        // In local development, allow any absolute path
        logsDir = envLogsDir;
      }
    } else {
      // Resolve relative paths under the default directory
      logsDir = path.join(defaultLogsDir, envLogsDir);
    }
  }

  // Ensure logs directory exists
  if (!fs.existsSync(logsDir)) {
    try {
      fs.mkdirSync(logsDir, { recursive: true });
    } catch (error) {
      console.error(`Failed to create logs directory: ${logsDir}`, error);
      // Fallback to a relative path if absolute path fails
      logsDir = path.join(process.cwd(), 'logs');
      if (!fs.existsSync(logsDir)) {
        fs.mkdirSync(logsDir, { recursive: true });
      }
    }
  }

  // Define log format
  const logFormat = winston.format.combine(
    winston.format.timestamp({
      format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.prettyPrint()
  );

  // Create logger instance
  const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: logFormat,
    defaultMeta: { service: serviceName },
    transports: [
      // Write all logs with importance level of `error` or less to `error.log`
      new winston.transports.File({
        filename: path.join(logsDir, `${serviceName}-error.log`),
        level: 'error',
        maxsize: 5242880, // 5MB
        maxFiles: 5,
      }),
      // Write all logs with importance level of `info` or less to `combined.log`
      new winston.transports.File({
        filename: path.join(logsDir, `${serviceName}-combined.log`),
        maxsize: 5242880, // 5MB
        maxFiles: 5,
      }),
    ],
  });

  // If we're not in production, log to the console as well
  if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }));
  }

  return logger;
}

