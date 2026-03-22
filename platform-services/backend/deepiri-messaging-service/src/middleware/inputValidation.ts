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
