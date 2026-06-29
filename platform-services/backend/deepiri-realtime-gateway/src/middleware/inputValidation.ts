/* Input validation middleware - length limits and consistent validation patterns */

import { Request, Response, NextFunction } from 'express';
import { body, validationResult, ValidationChain } from 'express-validator';
import { createLogger } from '@team-deepiri/shared-utils';

type BodyValidator = (body: Record<string, unknown>) => string | null;
type QueryValidator = (query: Record<string, unknown>) => string | null;
type HeaderValidator = (headers: Record<string, unknown>) => string | null;

interface BodyValidationOptions {
  required?: boolean;
  allowedFields?: string[];
  validators?: BodyValidator[];
  sanitizeBody?: boolean;
}

interface QueryValidationOptions {
  required?: boolean;
  allowedFields?: string[];
  validators?: QueryValidator[];
  sanitizeQuery?: boolean;
}

interface HeaderValidationOptions {
  allowedFields?: string[];
  validators?: HeaderValidator[];
  sanitizeHeaders?: boolean;
}

const logger = createLogger('realtime-gateway');

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

export const validateBody = (options: BodyValidationOptions = {}) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const errors: Array<{ field: string; message: string; value?: unknown }> = [];

    if (options.required && (req.body === undefined || req.body === null)) {
      errors.push({
        field: 'body',
        message: 'Request body is required',
      });
    }

    if (req.body !== undefined && req.body !== null) {
      if (typeof req.body !== 'object' || Array.isArray(req.body)) {
        errors.push({
          field: 'body',
          message: 'Request body must be a JSON object',
          value: req.body,
        });
      } else {
        if (options.allowedFields) {
          const unknownFields = Object.keys(req.body).filter(
            (field) => !options.allowedFields?.includes(field),
          );

          if (unknownFields.length > 0) {
            errors.push({
              field: 'body',
              message: `Unknown body fields provided: ${unknownFields.join(', ')}`,
              value: unknownFields,
            });
          }
        }

        if (options.validators) {
          for (const validator of options.validators) {
            const message = validator(req.body as Record<string, unknown>);
            if (message) {
              errors.push({
                field: 'body',
                message,
              });
            }
          }
        }

        if (options.sanitizeBody !== false) {
          req.body = sanitizeValue(req.body);
        }
      }
    }

    if (errors.length > 0) {
      respondValidationError(req, res, errors);
      return;
    }

    next();
  };
};

export const validateQuery = (options: QueryValidationOptions = {}) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const errors: Array<{ field: string; message: string; value?: unknown }> = [];
    const queryAsObject = req.query as unknown as Record<string, unknown>;
    const queryKeys = Object.keys(queryAsObject);

    if (options.required && queryKeys.length === 0) {
      errors.push({
        field: 'query',
        message: 'Query parameters are required',
      });
    }

    if (queryKeys.length > 0) {
      if (options.allowedFields) {
        const unknownFields = queryKeys.filter((field) => !options.allowedFields?.includes(field));
        if (unknownFields.length > 0) {
          errors.push({
            field: 'query',
            message: `Unknown query fields provided: ${unknownFields.join(', ')}`,
            value: unknownFields,
          });
        }
      }

      if (options.validators) {
        for (const validator of options.validators) {
          const message = validator(queryAsObject);
          if (message) {
            errors.push({
              field: 'query',
              message,
            });
          }
        }
      }

      if (options.sanitizeQuery !== false) {
        req.query = sanitizeValue(queryAsObject) as Request['query'];
      }
    }

    if (errors.length > 0) {
      respondValidationError(req, res, errors);
      return;
    }

    next();
  };
};

export const validateHeaders = (options: HeaderValidationOptions = {}) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const errors: Array<{ field: string; message: string; value?: unknown }> = [];
    const appHeaders = getAppHeaders(req.headers as unknown as Record<string, unknown>);

    if (options.allowedFields) {
      const unknownFields = Object.keys(appHeaders).filter((field) => !options.allowedFields?.includes(field));
      if (unknownFields.length > 0) {
        errors.push({
          field: 'headers',
          message: `Unknown headers provided: ${unknownFields.join(', ')}`,
          value: unknownFields,
        });
      }
    }

    if (options.validators) {
      for (const validator of options.validators) {
        const message = validator(appHeaders);
        if (message) {
          errors.push({
            field: 'headers',
            message,
          });
        }
      }
    }

    if (options.sanitizeHeaders !== false) {
      for (const [key, value] of Object.entries(appHeaders)) {
        (req.headers as Record<string, unknown>)[key] = sanitizeValue(value);
      }
    }

    if (errors.length > 0) {
      respondValidationError(req, res, errors);
      return;
    }

    next();
  };
};

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
