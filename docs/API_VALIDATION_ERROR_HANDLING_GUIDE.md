# Comprehensive API Validation, Error Handling, and Logging Guide

This guide provides step-by-step instructions for implementing comprehensive input validation, sanitization, error handling, and logging middleware across all API endpoints in the Deepiri platform.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Node.js/Express Services (TypeScript)](#nodejsexpress-services-typescript)
4. [Python/FastAPI Services](#pythonfastapi-services)
5. [Implementation Checklist](#implementation-checklist)
6. [Testing](#testing)
7. [Best Practices](#best-practices)

---

## Overview

This guide covers implementing:

- **Input Validation**: Validate all incoming request data (body, query params, headers)
- **Input Sanitization**: Clean and sanitize user inputs to prevent injection attacks
- **Error Handling**: Centralized error handling middleware with proper HTTP status codes
- **Logging Middleware**: Request/response logging with correlation IDs and structured logging

### Services Affected

- **Node.js/Express Services**:
  - `deepiri-core-api`
  - `deepiri-api-gateway`
  - `deepiri-auth-service`
  - `deepiri-task-orchestrator`
  - `deepiri-engagement-service`
  - `deepiri-platform-analytics-service`
  - `deepiri-notification-service`
  - `deepiri-external-bridge-service`
  - `deepiri-challenge-service`
  - `deepiri-realtime-gateway`

- **Python/FastAPI Services**:
  - `diri-cyrex`

---

## Architecture

### Middleware Stack Order

```
1. Request ID Generation
2. Request Logging (incoming)
3. Security Headers (Helmet)
4. CORS
5. Body Parsing
6. Input Validation
7. Input Sanitization
8. Route Handlers
9. Response Logging
10. Error Handling
```

### Error Response Format

All errors should follow this consistent format:

```json
{
  "success": false,
  "message": "Human-readable error message",
  "requestId": "uuid-request-id",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "errors": {
    "fieldName": ["Error message for this field"]
  }
}
```

---

## Node.js/Express Services (TypeScript)

### Step 1: Install Required Dependencies

For each Node.js service, install the following packages:

```bash
npm install express-validator express-rate-limit express-mongo-sanitize helmet cors winston uuid
npm install --save-dev @types/express-validator @types/express-mongo-sanitize
```

### Step 2: Create Validation Utilities

Create `src/utils/validators.ts`:

```typescript
import { body, query, param, ValidationChain, ValidationError } from 'express-validator';
import { Request, Response, NextFunction } from 'express';

// Common validation rules
export const commonValidators = {
  // String validations
  string: (field: string, minLength: number = 1, maxLength: number = 1000) =>
    body(field)
      .trim()
      .isLength({ min: minLength, max: maxLength })
      .withMessage(`${field} must be between ${minLength} and ${maxLength} characters`),

  // Email validation
  email: (field: string = 'email') =>
    body(field)
      .trim()
      .isEmail()
      .normalizeEmail()
      .withMessage('Invalid email address'),

  // UUID validation
  uuid: (field: string) =>
    param(field)
      .isUUID()
      .withMessage(`${field} must be a valid UUID`),

  // Integer validation
  integer: (field: string, min?: number, max?: number) => {
    let validator = body(field).isInt({ min, max });
    if (min !== undefined && max !== undefined) {
      validator = validator.withMessage(`${field} must be between ${min} and ${max}`);
    } else if (min !== undefined) {
      validator = validator.withMessage(`${field} must be at least ${min}`);
    } else if (max !== undefined) {
      validator = validator.withMessage(`${field} must be at most ${max}`);
    }
    return validator;
  },

  // Array validation
  array: (field: string, minItems?: number, maxItems?: number) => {
    let validator = body(field).isArray();
    if (minItems !== undefined) {
      validator = validator.isLength({ min: minItems });
    }
    if (maxItems !== undefined) {
      validator = validator.isLength({ max: maxItems });
    }
    return validator;
  },

  // Enum validation
  enum: (field: string, allowedValues: string[]) =>
    body(field)
      .isIn(allowedValues)
      .withMessage(`${field} must be one of: ${allowedValues.join(', ')}`),

  // Optional field
  optional: (validator: ValidationChain) => validator.optional(),

  // Date validation
  date: (field: string) =>
    body(field)
      .isISO8601()
      .withMessage(`${field} must be a valid ISO 8601 date`),

  // URL validation
  url: (field: string) =>
    body(field)
      .isURL()
      .withMessage(`${field} must be a valid URL`),
};

// Validation error formatter
export const formatValidationErrors = (errors: ValidationError[]) => {
  const formatted: Record<string, string[]> = {};
  errors.forEach((error) => {
    const field = error.param || 'unknown';
    if (!formatted[field]) {
      formatted[field] = [];
    }
    formatted[field].push(error.msg);
  });
  return formatted;
};

// Validation middleware
export const validate = (validations: ValidationChain[]) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    await Promise.all(validations.map(validation => validation.run(req)));

    const errors = require('express-validator').validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        requestId: (req as any).requestId || 'unknown',
        timestamp: new Date().toISOString(),
        errors: formatValidationErrors(errors.array())
      });
    }

    next();
  };
};
```

### Step 3: Create Sanitization Utilities

Create `src/utils/sanitizers.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import mongoSanitize from 'express-mongo-sanitize';
import { sanitize } from 'express-validator';

// HTML/script tag removal
export const sanitizeHtml = (text: string): string => {
  if (typeof text !== 'string') return text;
  
  return text
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    .replace(/<[^>]+>/g, '')
    .trim();
};

// SQL injection prevention (basic)
export const sanitizeSql = (text: string): string => {
  if (typeof text !== 'string') return text;
  
  const dangerous = [';', '--', '/*', '*/', 'xp_', 'sp_', 'exec', 'execute', 'union', 'select', 'insert', 'update', 'delete', 'drop', 'create', 'alter'];
  let sanitized = text;
  
  dangerous.forEach(pattern => {
    const regex = new RegExp(pattern, 'gi');
    sanitized = sanitized.replace(regex, '');
  });
  
  return sanitized;
};

// Sanitize request body
export const sanitizeBody = (req: Request, res: Response, next: NextFunction) => {
  if (req.body && typeof req.body === 'object') {
    const sanitizeObject = (obj: any): any => {
      if (Array.isArray(obj)) {
        return obj.map(sanitizeObject);
      } else if (obj !== null && typeof obj === 'object') {
        const sanitized: any = {};
        for (const key in obj) {
          if (typeof obj[key] === 'string') {
            sanitized[key] = sanitizeHtml(sanitizeSql(obj[key]));
          } else {
            sanitized[key] = sanitizeObject(obj[key]);
          }
        }
        return sanitized;
      } else if (typeof obj === 'string') {
        return sanitizeHtml(sanitizeSql(obj));
      }
      return obj;
    };
    
    req.body = sanitizeObject(req.body);
  }
  next();
};

// MongoDB injection prevention
export const mongoSanitizeMiddleware = mongoSanitize({
  replaceWith: '_',
  onSanitize: ({ req, key }) => {
    // Log sanitization attempts
    const logger = require('./logger').default;
    logger.warn('MongoDB injection attempt detected', {
      requestId: (req as any).requestId,
      key,
      path: req.path,
      method: req.method
    });
  }
});
```

### Step 4: Create Enhanced Error Handler

Update `src/middleware/errorHandler.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger';
import { Server as HttpServer } from 'http';
import { ValidationError } from 'express-validator';

interface CustomError extends Error {
  statusCode?: number;
  code?: number;
  errors?: Record<string, { message: string }>;
  isOperational?: boolean;
}

export class AppError extends Error {
  statusCode: number;
  isOperational: boolean;
  errors?: Record<string, string[]>;

  constructor(
    message: string,
    statusCode: number = 500,
    errors?: Record<string, string[]>,
    isOperational: boolean = true
  ) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.errors = errors;
    Error.captureStackTrace(this, this.constructor);
  }
}

export const errorHandler = (
  err: CustomError | AppError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const requestId = (req as any).requestId || 'unknown';
  
  // Log error with full context
  const logLevel = (err as AppError).isOperational === false ? 'error' : 'warn';
  logger[logLevel]('Request error occurred', {
    requestId,
    method: req.method,
    url: req.url,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
    userId: (req as any).user?.userId,
    error: {
      name: err.name,
      message: err.message,
      statusCode: (err as AppError).statusCode || err.statusCode,
      stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
      errors: (err as AppError).errors
    }
  });

  let error: AppError;

  // Handle specific error types
  if (err instanceof AppError) {
    error = err;
  } else if (err.name === 'CastError') {
    error = new AppError('Resource not found', 404);
  } else if (err.code === 11000) {
    error = new AppError('Duplicate field value entered', 400);
  } else if (err.name === 'ValidationError') {
    const message = Object.values(err.errors || {})
      .map((val: any) => val.message)
      .join(', ');
    error = new AppError(message, 400);
  } else if (err.name === 'JsonWebTokenError') {
    error = new AppError('Invalid token', 401);
  } else if (err.name === 'TokenExpiredError') {
    error = new AppError('Token expired', 401);
  } else if (err.statusCode === 429) {
    error = new AppError('Too many requests, please try again later', 429);
  } else {
    // Unknown error - don't expose internal details in production
    error = new AppError(
      process.env.NODE_ENV === 'production' 
        ? 'Internal server error' 
        : err.message,
      500,
      undefined,
      false
    );
  }

  const statusCode = error.statusCode || 500;
  const errorResponse: any = {
    success: false,
    message: error.message,
    requestId,
    timestamp: new Date().toISOString()
  };

  // Add validation errors if present
  if (error.errors) {
    errorResponse.errors = error.errors;
  }

  // Add stack trace in development
  if (process.env.NODE_ENV === 'development') {
    errorResponse.stack = err.stack;
    errorResponse.context = {
      method: req.method,
      url: req.url,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    };
  }

  res.status(statusCode).json(errorResponse);
};

export const asyncHandler = (fn: Function) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

export const notFoundHandler = (req: Request, res: Response): void => {
  const requestId = (req as any).requestId || 'unknown';
  
  logger.warn('Route not found', {
    requestId,
    method: req.method,
    url: req.url,
    userAgent: req.get('User-Agent'),
    ip: req.ip
  });

  res.status(404).json({
    success: false,
    message: 'Route not found',
    requestId,
    timestamp: new Date().toISOString(),
    path: req.url
  });
};

export const gracefulShutdown = (server: HttpServer) => {
  return (signal: string) => {
    logger.info(`Received ${signal}, shutting down gracefully`);
    
    server.close((err?: Error) => {
      if (err) {
        logger.error('Error during server shutdown:', err);
        process.exit(1);
      }
      
      logger.info('Server closed successfully');
      process.exit(0);
    });

    setTimeout(() => {
      logger.error('Forced shutdown after timeout');
      process.exit(1);
    }, 10000);
  };
};
```

### Step 5: Create Request Logging Middleware

Create `src/middleware/requestLogger.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';
import logger from '../utils/logger';

export interface RequestWithId extends Request {
  requestId?: string;
  startTime?: number;
}

export const requestLogger = (
  req: RequestWithId,
  res: Response,
  next: NextFunction
): void => {
  // Generate request ID
  req.requestId = req.headers['x-request-id'] as string || uuidv4();
  req.startTime = Date.now();

  // Add request ID to response headers
  res.setHeader('X-Request-ID', req.requestId);

  // Log incoming request
  logger.info('Incoming request', {
    requestId: req.requestId,
    method: req.method,
    url: req.originalUrl || req.url,
    path: req.path,
    query: req.query,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    userId: (req as any).user?.userId,
    contentType: req.get('Content-Type'),
    contentLength: req.get('Content-Length')
  });

  // Log response when finished
  res.on('finish', () => {
    const duration = Date.now() - (req.startTime || 0);
    const logData = {
      requestId: req.requestId,
      method: req.method,
      url: req.originalUrl || req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userId: (req as any).user?.userId,
      ip: req.ip
    };

    if (res.statusCode >= 500) {
      logger.error('Request completed with server error', logData);
    } else if (res.statusCode >= 400) {
      logger.warn('Request completed with client error', logData);
    } else {
      logger.info('Request completed', logData);
    }
  });

  next();
};
```

### Step 6: Update Server Configuration

Update `src/server.ts` for each service:

```typescript
import express, { Express } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { requestLogger } from './middleware/requestLogger';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import { sanitizeBody, mongoSanitizeMiddleware } from './utils/sanitizers';
import logger from './utils/logger';

const app: Express = express();

// 1. Request ID and Logging (first)
app.use(requestLogger);

// 2. Security Headers
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// 3. CORS
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:5173'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-api-key', 'x-request-id'],
}));

// 4. Body Parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 5. Sanitization (after body parsing)
app.use(mongoSanitizeMiddleware);
app.use(sanitizeBody);

// 6. Routes
app.use('/api', routes);

// 7. Error Handling (must be last)
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
```

### Step 7: Apply Validation to Routes

Example route with validation:

```typescript
import { Router } from 'express';
import { validate, commonValidators } from '../utils/validators';
import { asyncHandler } from '../middleware/errorHandler';

const router = Router();

router.post(
  '/users',
  validate([
    commonValidators.string('name', 2, 100),
    commonValidators.email('email'),
    commonValidators.string('password', 8, 128),
    commonValidators.optional(commonValidators.string('bio', 0, 500))
  ]),
  asyncHandler(async (req, res) => {
    // Validation passed, safe to use req.body
    const { name, email, password, bio } = req.body;
    
    // Business logic here
    const user = await createUser({ name, email, password, bio });
    
    res.status(201).json({
      success: true,
      data: user,
      requestId: (req as any).requestId
    });
  })
);

export default router;
```

---

## Python/FastAPI Services

### Step 1: Install Required Dependencies

For `diri-cyrex`, update `requirements.txt`:

```txt
pydantic>=2.0.0
pydantic-settings>=2.0.0
python-multipart>=0.0.6
email-validator>=2.0.0
bleach>=6.0.0
```

### Step 2: Create Validation Models

Create `app/schemas/validation.py`:

```python
from pydantic import BaseModel, Field, EmailStr, validator, HttpUrl
from typing import Optional, List
from datetime import datetime
import re

class BaseRequestModel(BaseModel):
    """Base model with common validation."""
    
    class Config:
        # Validate on assignment
        validate_assignment = True
        # Use enum values
        use_enum_values = True
        # Extra fields not allowed
        extra = 'forbid'

class UserCreateRequest(BaseRequestModel):
    name: str = Field(..., min_length=2, max_length=100, description="User name")
    email: EmailStr = Field(..., description="User email")
    password: str = Field(..., min_length=8, max_length=128, description="User password")
    bio: Optional[str] = Field(None, max_length=500, description="User bio")
    
    @validator('name')
    def validate_name(cls, v):
        # Remove HTML tags
        v = re.sub(r'<[^>]+>', '', v)
        # Remove script tags
        v = re.sub(r'<script[^>]*>.*?</script>', '', v, flags=re.IGNORECASE | re.DOTALL)
        return v.strip()
    
    @validator('password')
    def validate_password_strength(cls, v):
        if not re.search(r'[A-Z]', v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not re.search(r'[a-z]', v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not re.search(r'\d', v):
            raise ValueError('Password must contain at least one digit')
        return v

class TaskCreateRequest(BaseRequestModel):
    title: str = Field(..., min_length=3, max_length=200)
    description: Optional[str] = Field(None, max_length=5000)
    task_type: str = Field(..., description="Task type")
    priority: Optional[int] = Field(None, ge=1, le=5)
    
    @validator('task_type')
    def validate_task_type(cls, v):
        valid_types = ['study', 'code', 'creative', 'manual', 'meeting', 'research', 'admin']
        if v not in valid_types:
            raise ValueError(f'Task type must be one of: {", ".join(valid_types)}')
        return v
    
    @validator('title', 'description')
    def sanitize_text(cls, v):
        if v is None:
            return v
        # Remove HTML/script tags
        v = re.sub(r'<script[^>]*>.*?</script>', '', v, flags=re.IGNORECASE | re.DOTALL)
        v = re.sub(r'<[^>]+>', '', v)
        return v.strip()
```

### Step 3: Create Sanitization Utilities

Create `app/utils/sanitizers.py`:

```python
"""
Input sanitization utilities.
"""
import re
import bleach
from typing import Any, Dict, List

class InputSanitizer:
    """Sanitize user inputs to prevent injection attacks."""
    
    # Allowed HTML tags (if any)
    ALLOWED_TAGS = []
    ALLOWED_ATTRIBUTES = {}
    
    @staticmethod
    def sanitize_html(text: str) -> str:
        """Remove HTML and script tags."""
        if not text or not isinstance(text, str):
            return text
        
        # Remove script tags
        text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.IGNORECASE | re.DOTALL)
        # Remove all HTML tags
        text = re.sub(r'<[^>]+>', '', text)
        # Use bleach for additional sanitization
        text = bleach.clean(text, tags=InputSanitizer.ALLOWED_TAGS, attributes=InputSanitizer.ALLOWED_ATTRIBUTES)
        
        return text.strip()
    
    @staticmethod
    def sanitize_sql(text: str) -> str:
        """Basic SQL injection prevention."""
        if not text or not isinstance(text, str):
            return text
        
        dangerous_patterns = [
            r';\s*--',
            r'/\*.*?\*/',
            r'\b(exec|execute|xp_|sp_)\b',
            r'\b(union|select|insert|update|delete|drop|create|alter)\b.*\b(from|into|table|database)\b'
        ]
        
        sanitized = text
        for pattern in dangerous_patterns:
            sanitized = re.sub(pattern, '', sanitized, flags=re.IGNORECASE)
        
        return sanitized
    
    @staticmethod
    def sanitize_mongo(text: str) -> str:
        """MongoDB injection prevention."""
        if not text or not isinstance(text, str):
            return text
        
        # Remove MongoDB operators
        dangerous = ['$where', '$ne', '$gt', '$lt', '$gte', '$lte', '$in', '$nin', '$regex']
        sanitized = text
        
        for op in dangerous:
            sanitized = sanitized.replace(f'${op}', '')
        
        return sanitized
    
    @staticmethod
    def sanitize_object(obj: Any) -> Any:
        """Recursively sanitize objects."""
        if isinstance(obj, str):
            return InputSanitizer.sanitize_html(
                InputSanitizer.sanitize_sql(
                    InputSanitizer.sanitize_mongo(obj)
                )
            )
        elif isinstance(obj, dict):
            return {k: InputSanitizer.sanitize_object(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [InputSanitizer.sanitize_object(item) for item in obj]
        else:
            return obj
```

### Step 4: Create Error Handler

Create `app/middleware/error_handler.py`:

```python
"""
Error handling middleware for FastAPI.
"""
from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from pydantic import ValidationError
import traceback
from ..logging_config import get_logger

logger = get_logger("middleware.error_handler")

class AppError(Exception):
    """Custom application error."""
    def __init__(
        self,
        message: str,
        status_code: int = 500,
        errors: dict = None,
        is_operational: bool = True
    ):
        self.message = message
        self.status_code = status_code
        self.errors = errors or {}
        self.is_operational = is_operational
        super().__init__(self.message)

async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle Pydantic validation errors."""
    request_id = request.state.request_id if hasattr(request.state, 'request_id') else 'unknown'
    
    errors = {}
    for error in exc.errors():
        field = '.'.join(str(loc) for loc in error['loc'][1:])  # Skip 'body'
        if field not in errors:
            errors[field] = []
        errors[field].append(error['msg'])
    
    logger.warning('Validation error', {
        'request_id': request_id,
        'path': request.url.path,
        'method': request.method,
        'errors': errors
    })
    
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={
            'success': False,
            'message': 'Validation failed',
            'request_id': request_id,
            'timestamp': datetime.utcnow().isoformat(),
            'errors': errors
        }
    )

async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    """Handle HTTP exceptions."""
    request_id = request.state.request_id if hasattr(request.state, 'request_id') else 'unknown'
    
    logger.warning('HTTP exception', {
        'request_id': request_id,
        'path': request.url.path,
        'method': request.method,
        'status_code': exc.status_code,
        'detail': exc.detail
    })
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            'success': False,
            'message': exc.detail,
            'request_id': request_id,
            'timestamp': datetime.utcnow().isoformat()
        }
    )

async def app_error_handler(request: Request, exc: AppError):
    """Handle custom application errors."""
    request_id = request.state.request_id if hasattr(request.state, 'request_id') else 'unknown'
    
    log_level = 'error' if not exc.is_operational else 'warning'
    getattr(logger, log_level)('Application error', {
        'request_id': request_id,
        'path': request.url.path,
        'method': request.method,
        'status_code': exc.status_code,
        'message': exc.message,
        'errors': exc.errors
    })
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            'success': False,
            'message': exc.message,
            'request_id': request_id,
            'timestamp': datetime.utcnow().isoformat(),
            'errors': exc.errors if exc.errors else None
        }
    )

async def general_exception_handler(request: Request, exc: Exception):
    """Handle all other exceptions."""
    request_id = request.state.request_id if hasattr(request.state, 'request_id') else 'unknown'
    
    logger.error('Unhandled exception', {
        'request_id': request_id,
        'path': request.url.path,
        'method': request.method,
        'error_type': type(exc).__name__,
        'error_message': str(exc),
        'traceback': traceback.format_exc()
    })
    
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            'success': False,
            'message': 'Internal server error' if os.getenv('ENV') == 'production' else str(exc),
            'request_id': request_id,
            'timestamp': datetime.utcnow().isoformat()
        }
    )
```

### Step 5: Create Request Logging Middleware

Update `app/main.py` or create `app/middleware/request_logger.py`:

```python
"""
Request logging middleware.
"""
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
import time
import uuid
from datetime import datetime
from ..logging_config import get_logger

logger = get_logger("middleware.request_logger")

class RequestLoggerMiddleware(BaseHTTPMiddleware):
    """Middleware for request logging with correlation IDs."""
    
    async def dispatch(self, request: Request, call_next):
        # Generate or use existing request ID
        request_id = request.headers.get('x-request-id') or str(uuid.uuid4())
        request.state.request_id = request_id
        
        # Start time
        start_time = time.time()
        
        # Log incoming request
        logger.info('Incoming request', {
            'request_id': request_id,
            'method': request.method,
            'url': str(request.url),
            'path': request.url.path,
            'query_params': dict(request.query_params),
            'client_host': request.client.host if request.client else None,
            'user_agent': request.headers.get('user-agent'),
            'content_type': request.headers.get('content-type'),
            'content_length': request.headers.get('content-length')
        })
        
        # Process request
        try:
            response = await call_next(request)
            
            # Calculate duration
            duration = time.time() - start_time
            duration_ms = duration * 1000
            
            # Add request ID to response headers
            response.headers['X-Request-ID'] = request_id
            
            # Log response
            log_data = {
                'request_id': request_id,
                'method': request.method,
                'path': request.url.path,
                'status_code': response.status_code,
                'duration_ms': f'{duration_ms:.2f}ms',
                'client_host': request.client.host if request.client else None
            }
            
            if response.status_code >= 500:
                logger.error('Request completed with server error', log_data)
            elif response.status_code >= 400:
                logger.warning('Request completed with client error', log_data)
            else:
                logger.info('Request completed', log_data)
            
            return response
            
        except Exception as e:
            duration = time.time() - start_time
            logger.error('Request failed with exception', {
                'request_id': request_id,
                'method': request.method,
                'path': request.url.path,
                'duration_ms': f'{duration * 1000:.2f}ms',
                'error_type': type(e).__name__,
                'error_message': str(e)
            })
            raise
```

### Step 6: Update FastAPI Application

Update `app/main.py`:

```python
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from .middleware.error_handler import (
    validation_exception_handler,
    http_exception_handler,
    app_error_handler,
    general_exception_handler,
    AppError
)
from .middleware.request_logger import RequestLoggerMiddleware
from .routes import router
import os

app = FastAPI(
    title="Cyrex API",
    version="1.0.0",
    docs_url="/docs" if os.getenv('ENV') != 'production' else None
)

# 1. Request Logging (first)
app.add_middleware(RequestLoggerMiddleware)

# 2. CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv('ALLOWED_ORIGINS', 'http://localhost:5173').split(','),
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

# 3. Routes
app.include_router(router)

# 4. Error Handlers (must be last)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(StarletteHTTPException, http_exception_handler)
app.add_exception_handler(AppError, app_error_handler)
app.add_exception_handler(Exception, general_exception_handler)
```

### Step 7: Apply Validation to Routes

Example route with validation:

```python
from fastapi import APIRouter, Depends, HTTPException
from ..schemas.validation import UserCreateRequest
from ..utils.sanitizers import InputSanitizer
from ..middleware.error_handler import AppError

router = APIRouter()

@router.post("/users")
async def create_user(user_data: UserCreateRequest):
    """Create a new user with validation."""
    try:
        # Pydantic already validates and sanitizes
        # Additional sanitization if needed
        sanitized_data = InputSanitizer.sanitize_object(user_data.dict())
        
        # Business logic here
        user = await create_user_service(sanitized_data)
        
        return {
            'success': True,
            'data': user,
            'request_id': request.state.request_id
        }
    except ValueError as e:
        raise AppError(str(e), status_code=400)
    except Exception as e:
        raise AppError('Failed to create user', status_code=500)
```

---

## Implementation Checklist

### For Each Node.js/Express Service

- [ ] Install required dependencies
- [ ] Create `src/utils/validators.ts`
- [ ] Create `src/utils/sanitizers.ts`
- [ ] Update `src/middleware/errorHandler.ts`
- [ ] Create `src/middleware/requestLogger.ts`
- [ ] Update `src/server.ts` with middleware stack
- [ ] Apply validation to all route handlers
- [ ] Test all endpoints with invalid inputs
- [ ] Verify error responses follow standard format
- [ ] Check logs for proper request/response logging

### For Python/FastAPI Service (diri-cyrex)

- [ ] Update `requirements.txt` with dependencies
- [ ] Create `app/schemas/validation.py`
- [ ] Create `app/utils/sanitizers.py`
- [ ] Create `app/middleware/error_handler.py`
- [ ] Create/update `app/middleware/request_logger.py`
- [ ] Update `app/main.py` with middleware and error handlers
- [ ] Apply Pydantic models to all route handlers
- [ ] Test all endpoints with invalid inputs
- [ ] Verify error responses follow standard format
- [ ] Check logs for proper request/response logging

---

## Testing

### Test Cases for Validation

1. **Missing Required Fields**
   ```bash
   curl -X POST http://localhost:5001/api/users \
     -H "Content-Type: application/json" \
     -d '{}'
   ```
   Expected: 400 with validation errors

2. **Invalid Data Types**
   ```bash
   curl -X POST http://localhost:5001/api/users \
     -H "Content-Type: application/json" \
     -d '{"name": 123, "email": "invalid-email"}'
   ```
   Expected: 400 with validation errors

3. **SQL Injection Attempt**
   ```bash
   curl -X POST http://localhost:5001/api/users \
     -H "Content-Type: application/json" \
     -d '{"name": "test\"; DROP TABLE users; --"}'
   ```
   Expected: 200/201 with sanitized input

4. **XSS Attempt**
   ```bash
   curl -X POST http://localhost:5001/api/users \
     -H "Content-Type: application/json" \
     -d '{"name": "<script>alert(\"XSS\")</script>"}'
   ```
   Expected: 200/201 with sanitized input

5. **MongoDB Injection Attempt**
   ```bash
   curl -X POST http://localhost:5001/api/users \
     -H "Content-Type: application/json" \
     -d '{"name": {"$ne": null}}'
   ```
   Expected: 400 or sanitized input

### Test Error Handling

1. **404 Not Found**
   ```bash
   curl http://localhost:5001/api/nonexistent
   ```
   Expected: 404 with standard error format

2. **500 Internal Server Error** (simulate with test endpoint)
   Expected: 500 with standard error format (no stack trace in production)

3. **Request ID Propagation**
   - Check that `X-Request-ID` header is present in all responses
   - Verify request ID appears in logs

---

## Best Practices

### Validation

1. **Validate Early**: Validate input as soon as it enters the system
2. **Fail Fast**: Return validation errors immediately, don't process invalid data
3. **Be Specific**: Provide clear, actionable error messages
4. **Whitelist, Don't Blacklist**: Allow only known good values, reject everything else
5. **Validate on Both Client and Server**: Client-side validation is UX, server-side is security

### Sanitization

1. **Sanitize All User Input**: Never trust user input
2. **Context-Aware Sanitization**: Different contexts (HTML, SQL, URLs) need different sanitization
3. **Preserve Data Integrity**: Sanitize without losing legitimate data
4. **Log Sanitization Attempts**: Log when potentially malicious input is detected

### Error Handling

1. **Consistent Error Format**: All errors should follow the same structure
2. **Don't Expose Internals**: Never expose stack traces, database errors, or internal paths in production
3. **Log Everything**: Log all errors with full context for debugging
4. **Use Appropriate Status Codes**: 400 for client errors, 500 for server errors
5. **Handle Async Errors**: Use `asyncHandler` or try-catch in async functions

### Logging

1. **Structured Logging**: Use JSON format for logs
2. **Correlation IDs**: Include request ID in all log entries
3. **Log Levels**: Use appropriate levels (error, warn, info, debug)
4. **Sensitive Data**: Never log passwords, tokens, or PII
5. **Performance**: Log request duration for performance monitoring

### Security

1. **Rate Limiting**: Implement rate limiting to prevent abuse
2. **Input Size Limits**: Limit request body size
3. **Content-Type Validation**: Validate Content-Type headers
4. **CORS Configuration**: Properly configure CORS for your use case
5. **Security Headers**: Use Helmet.js for security headers

---

## Additional Resources

- [OWASP Input Validation Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
- [Express Validator Documentation](https://express-validator.github.io/docs/)
- [Pydantic Documentation](https://docs.pydantic.dev/)
- [FastAPI Error Handling](https://fastapi.tiangolo.com/tutorial/handling-errors/)

---

## Next Steps

After implementing validation and error handling:

1. **Set up monitoring**: Integrate with monitoring tools (Prometheus, Grafana)
2. **Add rate limiting**: Implement rate limiting middleware
3. **API documentation**: Update OpenAPI/Swagger docs with validation rules
4. **Security audit**: Perform security audit of all endpoints
5. **Performance testing**: Test error handling under load

---

*Last updated: 2024-01-01*

