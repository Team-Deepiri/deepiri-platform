/* Input validation middleware - length limits and consistent validation patterns */

import { Request, Response, NextFunction } from 'express';
import { body, validationResult, ValidationChain } from 'express-validator';
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })],
});

const MAX_BODY_KEYS = 50;
const MAX_STRING_VALUE_LENGTH = 10000;
const APP_HEADER_PREFIX = 'x-';

const getAppHeaders = (headers: Record<string, unknown>): Record<string, unknown> => {
  const appHeaders: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(headers)) {
    const normalized = key.toLowerCase();
    if (normalized === 'authorization' || normalized.startsWith(APP_HEADER_PREFIX)) {
      appHeaders[normalized] = value;
    }
  }

  return appHeaders;
};

const sanitizeValue = (value: unknown): unknown => {
  if (typeof value === 'string') {
    return value.trim();
  }

  if (Array.isArray(value)) {
    return value.map((item) => sanitizeValue(item));
  }

  if (value && typeof value === 'object') {
    const sanitizedRecord: Record<string, unknown> = {};
    for (const [key, nestedValue] of Object.entries(value as Record<string, unknown>)) {
      sanitizedRecord[key] = sanitizeValue(nestedValue);
    }
    return sanitizedRecord;
  }

  return value;
};

const respondValidationError = (
  req: Request,
  res: Response,
  errors: Array<{ field: string; message: string; value?: unknown }>,
): void => {
  const requestId = (req.headers['x-request-id'] as string) || 'unknown';

  logger.warn('Body validation failed', {
    requestId,
    path: req.path,
    method: req.method,
    errors,
  });

  res.status(400).json({
    success: false,
    message: 'Validation failed',
    requestId,
    timestamp: new Date().toISOString(),
    errors,
  });
};

export const validate = (validations: ValidationChain[]) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    await Promise.all(validations.map((v) => v.run(req)));
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      const requestId = (req as any).requestId || 'unknown';
      logger.warn('Validation failed', {
        requestId,
        path: req.path,
        method: req.method,
        errors: errors.array(),
      });
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        requestId,
        timestamp: new Date().toISOString(),
        errors: errors.array().map((err: any) => ({
          field: err.path || err.param || err.type || 'unknown',
          message: err.msg,
          value: err.value,
        })),
      });
    }
    next();
  };
};

export const generateBodyValidations = () => [
  body()
    .isObject()
    .withMessage('Body must be a JSON object')
    .custom((val: Record<string, unknown>) => {
      const keys = Object.keys(val || {});
      if (keys.length > MAX_BODY_KEYS) {
        throw new Error(`Body must have at most ${MAX_BODY_KEYS} keys`);
      }
      for (const k of keys) {
        if (k.length > 500) throw new Error('Body key names must be at most 500 characters');
        const v = (val as Record<string, unknown>)[k];
        if (typeof v === 'string' && v.length > MAX_STRING_VALUE_LENGTH) {
          throw new Error(`Body string values must be at most ${MAX_STRING_VALUE_LENGTH} characters`);
        }
      }
      return true;
    }),
];

/** Run body validation only when request has a JSON body. */
export const validateBodyIfPresent = () => {
  const validations = generateBodyValidations();
  return async (req: Request, res: Response, next: NextFunction) => {
    if (req.body && typeof req.body === 'object' && Object.keys(req.body).length > 0) {
      return validate(validations)(req, res, next);
    }
    next();
  };
};
