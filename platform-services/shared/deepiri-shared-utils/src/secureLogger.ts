import winston from 'winston';

export const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

// List of sensitive field names
const SENSITIVE_FIELDS = [
  'password',
  'secret',
  'token',
  'key',
  'credential',
  'auth',
  'jwt',
  'api_key',
  'apiKey',
  'access_token',
  'refresh_token',
];

function sanitizeObject(obj: any, depth: number = 0): any {
  if (depth > 10) return '[Max Depth Reached]';
  
  if (obj === null || obj === undefined) {
    return obj;
  }

  if (typeof obj === 'string') {
    // Check if string looks like a secret (long random string)
    if (obj.length > 20 && /^[a-zA-Z0-9+/=_-]+$/.test(obj)) {
      return '[REDACTED]';
    }
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map(item => sanitizeObject(item, depth + 1));
  }

  if (typeof obj === 'object') {
    const sanitized: any = {};
    for (const [key, value] of Object.entries(obj)) {
      const lowerKey = key.toLowerCase();
      const isSensitive = SENSITIVE_FIELDS.some(field => lowerKey.includes(field));
      
      if (isSensitive) {
        sanitized[key] = '[REDACTED]';
      } else {
        sanitized[key] = sanitizeObject(value, depth + 1);
      }
    }
    return sanitized;
  }

  return obj;
}

export function secureLog(level: 'info' | 'warn' | 'error', message: string, data?: any): void {
  const sanitizedData = data ? sanitizeObject(data) : undefined;
  logger[level](message, sanitizedData);
}