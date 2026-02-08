# Code Security Enhancements and Recommendations

## Document Purpose

This document provides comprehensive code-level security enhancements, vulnerabilities, and recommendations for the Deepiri platform. It focuses on actionable code improvements, security best practices, and implementation guidelines for developers.

**Target Audience**: Software/Infrastructure Security Engineers, Cloud/Resource Security Engineers, and Development Team

**Last Updated**: 2026
**Status**: Active Security Enhancement Guide

---

## Table of Contents

1. [Authentication and Authorization Enhancements](#authentication-and-authorization-enhancements)
2. [Secrets and Credentials Management](#secrets-and-credentials-management)
3. [Input Validation and Sanitization](#input-validation-and-sanitization)
4. [SQL Injection Prevention](#sql-injection-prevention)
5. [Cross-Site Scripting (XSS) Prevention](#cross-site-scripting-xss-prevention)
6. [CORS Configuration Security](#cors-configuration-security)
7. [Error Handling and Information Disclosure](#error-handling-and-information-disclosure)
8. [Security Headers Implementation](#security-headers-implementation)
9. [Rate Limiting Enhancements](#rate-limiting-enhancements)
10. [Session Management Security](#session-management-security)
11. [API Security Enhancements](#api-security-enhancements)
12. [Database Security](#database-security)
13. [Logging and Monitoring Security](#logging-and-monitoring-security)
14. [Dependency Security](#dependency-security)
15. [Container and Infrastructure Security](#container-and-infrastructure-security)

---

## Authentication and Authorization Enhancements

### Issue 1: JWT Secret Fallback to Empty String

**Location**: Multiple files
- `deepiri-core-api/src/middleware/authenticateJWT.ts:34`
- `deepiri-core-api/src/routes/authRoutes.ts:59,125,162,205`
- `deepiri-core-api/src/controllers/dataController.ts:43`

**Current Code**:
```typescript
const decoded = jwt.verify(token, process.env.JWT_SECRET || '') as JWTPayload;
```

**Security Risk**: 
- If `JWT_SECRET` is not set, the code falls back to an empty string
- This allows attackers to forge tokens if they know the secret is empty
- No validation that secret exists before use

**Recommended Fix**:

```typescript
// Create secure JWT configuration module
// File: src/config/jwtConfig.ts
import { config } from 'dotenv';

config();

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET || JWT_SECRET.length < 32) {
  throw new Error(
    'JWT_SECRET must be set and at least 32 characters long. ' +
    'Set JWT_SECRET in environment variables before starting the application.'
  );
}

export const jwtConfig = {
  secret: JWT_SECRET,
  expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  algorithm: 'HS256' as const,
  issuer: process.env.JWT_ISSUER || 'deepiri-api',
  audience: process.env.JWT_AUDIENCE || 'deepiri-client',
};

// Updated authenticateJWT.ts
import { jwtConfig } from '../config/jwtConfig';

const authenticateJWT = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const authHeader = req.header('Authorization');
    
    if (!authHeader) {
      res.status(401).json({
        success: false,
        message: 'Access denied. No token provided.'
      });
      return;
    }

    const token = authHeader.replace('Bearer ', '').trim();
    
    if (!token) {
      res.status(401).json({
        success: false,
        message: 'Access denied. No token provided.'
      });
      return;
    }

    // Verify token with proper configuration
    const decoded = jwt.verify(
      token, 
      jwtConfig.secret,
      {
        algorithms: [jwtConfig.algorithm],
        issuer: jwtConfig.issuer,
        audience: jwtConfig.audience,
      }
    ) as JWTPayload;
    
    // Additional validation
    if (!decoded.userId || !decoded.email) {
      res.status(401).json({
        success: false,
        message: 'Access denied. Invalid token payload.'
      });
      return;
    }

    const user = await User.findById(decoded.userId);
    if (!user) {
      res.status(401).json({
        success: false,
        message: 'Access denied. User not found.'
      });
      return;
    }

    if (!user.isActive) {
      res.status(401).json({
        success: false,
        message: 'Access denied. Account is deactivated.'
      });
      return;
    }

    // Set user context
    (req as any).user = {
      id: decoded.userId,
      userId: decoded.userId,
      email: decoded.email,
      roles: decoded.roles || ['user']
    };

    next();

  } catch (error: any) {
    logger.error('JWT authentication error:', {
      error: error.message,
      name: error.name,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });
    
    if (error.name === 'JsonWebTokenError') {
      res.status(401).json({
        success: false,
        message: 'Access denied. Invalid token.'
      });
      return;
    }
    
    if (error.name === 'TokenExpiredError') {
      res.status(401).json({
        success: false,
        message: 'Access denied. Token expired.'
      });
      return;
    }

    // Generic error - don't expose details
    res.status(500).json({
      success: false,
      message: 'Internal server error during authentication.'
    });
  }
};
```

**Python Equivalent** (for diri-cyrex):

```python
# File: app/config/jwt_config.py
import os
from typing import Optional
from ..settings import settings

def get_jwt_secret() -> str:
    """Get JWT secret with validation"""
    secret = getattr(settings, 'JWT_SECRET', None) or os.getenv('JWT_SECRET')
    
    if not secret:
        raise ValueError(
            'JWT_SECRET must be set in environment variables. '
            'Set JWT_SECRET before starting the application.'
        )
    
    if len(secret) < 32:
        raise ValueError(
            'JWT_SECRET must be at least 32 characters long for security. '
            f'Current length: {len(secret)}'
        )
    
    return secret

# Updated authentication.py
from ..config.jwt_config import get_jwt_secret

async def validate_jwt_token(self, token: str) -> Optional[AuthToken]:
    """Validate a JWT token with proper configuration"""
    try:
        secret = get_jwt_secret()
        
        payload = jwt.decode(
            token, 
            secret, 
            algorithms=["HS256"],
            options={
                "verify_signature": True,
                "verify_exp": True,
                "verify_iss": True,
                "verify_aud": True,
            },
            issuer=getattr(settings, 'JWT_ISSUER', 'deepiri-api'),
            audience=getattr(settings, 'JWT_AUDIENCE', 'deepiri-client'),
        )
        
        # Validate required fields
        if not payload.get('user_id') or not payload.get('email'):
            logger.warning("JWT token missing required fields")
            return None
        
        return AuthToken(
            token_id=payload.get("jti", "jwt"),
            user_id=payload.get("user_id"),
            agent_id=payload.get("agent_id"),
            token_type=AuthType.JWT,
            expires_at=datetime.fromtimestamp(payload.get("exp", 0)),
            scopes=payload.get("scopes", []),
            metadata=payload.get("metadata", {}),
        )
    except jwt.ExpiredSignatureError:
        logger.warning("JWT token expired")
        return None
    except jwt.InvalidTokenError as e:
        logger.warning(f"Invalid JWT token: {e}")
        return None
    except Exception as e:
        logger.error(f"JWT validation error: {e}")
        return None
```

### Issue 2: Missing Token Revocation Check

**Location**: `deepiri-core-api/src/middleware/authenticateJWT.ts`

**Security Risk**: 
- Tokens are validated but not checked against a revocation list
- Compromised tokens remain valid until expiration
- No way to invalidate tokens immediately

**Recommended Fix**:

```typescript
// Create token revocation service
// File: src/services/tokenRevocationService.ts
import Redis from 'ioredis';
import logger from '../utils/logger';

class TokenRevocationService {
  private redis: Redis;
  private prefix = 'revoked_token:';

  constructor() {
    this.redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');
  }

  async revokeToken(tokenId: string, expiresIn: number): Promise<void> {
    const key = `${this.prefix}${tokenId}`;
    await this.redis.setex(key, expiresIn, '1');
    logger.info(`Token revoked: ${tokenId}`);
  }

  async isTokenRevoked(tokenId: string): Promise<boolean> {
    const key = `${this.prefix}${tokenId}`;
    const result = await this.redis.get(key);
    return result === '1';
  }

  async revokeAllUserTokens(userId: string): Promise<void> {
    // Implementation for revoking all user tokens
    // This would require tracking token IDs per user
  }
}

export const tokenRevocationService = new TokenRevocationService();

// Updated authenticateJWT.ts
import { tokenRevocationService } from '../services/tokenRevocationService';

const authenticateJWT = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    // ... existing token extraction code ...

    const decoded = jwt.verify(token, jwtConfig.secret, {
      algorithms: [jwtConfig.algorithm],
    }) as JWTPayload & { jti?: string };

    // Check token revocation
    if (decoded.jti) {
      const isRevoked = await tokenRevocationService.isTokenRevoked(decoded.jti);
      if (isRevoked) {
        res.status(401).json({
          success: false,
          message: 'Access denied. Token has been revoked.'
        });
        return;
      }
    }

    // ... rest of authentication logic ...
  } catch (error: any) {
    // ... error handling ...
  }
};
```

### Issue 3: Weak Default JWT Secret in Python

**Location**: `diri-cyrex/app/core/authentication.py:60`

**Current Code**:
```python
self._jwt_secret = getattr(settings, 'JWT_SECRET', 'default-secret-change-in-production')
```

**Security Risk**: 
- Hardcoded default secret
- Weak secret if not changed
- No validation

**Recommended Fix**:

```python
def __init__(self):
    self.logger = logger
    jwt_secret = getattr(settings, 'JWT_SECRET', None) or os.getenv('JWT_SECRET')
    
    if not jwt_secret:
        raise ValueError(
            'JWT_SECRET must be set in environment variables. '
            'This is required for security. Set JWT_SECRET before starting the application.'
        )
    
    if len(jwt_secret) < 32:
        raise ValueError(
            f'JWT_SECRET must be at least 32 characters long. '
            f'Current length: {len(jwt_secret)}'
        )
    
    self._jwt_secret = jwt_secret
    self._api_key_header = 'x-api-key'
    self._auth_header = 'authorization'
    self._initialized = False
```

---

## Secrets and Credentials Management

### Issue 4: Default Passwords in Code

**Location**: Multiple files
- `diri-cyrex/app/settings.py:62` - `POSTGRES_PASSWORD: str = "deepiripassword"`
- `diri-cyrex/app/database/postgres.py:43` - Default password fallback
- `docker-compose.yml` - Default credentials

**Security Risk**: 
- Hardcoded default passwords
- Weak passwords if not changed
- Credentials exposed in code

**Recommended Fix**:

```python
# File: app/settings.py
from pydantic import BaseSettings, validator
import os

class Settings(BaseSettings):
    # ... other settings ...
    
    POSTGRES_PASSWORD: str
    
    @validator('POSTGRES_PASSWORD', pre=True)
    def validate_postgres_password(cls, v):
        if not v:
            raise ValueError('POSTGRES_PASSWORD must be set in environment variables')
        
        if len(v) < 16:
            raise ValueError(
                f'POSTGRES_PASSWORD must be at least 16 characters long. '
                f'Current length: {len(v)}'
            )
        
        # Check for common weak passwords
        weak_passwords = ['password', 'admin', '123456', 'deepiripassword']
        if v.lower() in weak_passwords:
            raise ValueError('POSTGRES_PASSWORD cannot be a common weak password')
        
        return v
    
    class Config:
        env_file = '.env'
        case_sensitive = True
```

**Docker Compose Fix**:

```yaml
# docker-compose.yml
services:
  postgres:
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set}
      # Use required variable syntax - will fail if not set
```

### Issue 5: Secrets in Environment Variables Without Validation

**Location**: All services using environment variables

**Security Risk**: 
- Secrets may be weak or missing
- No validation on startup
- Secrets may be logged accidentally

**Recommended Fix**:

```typescript
// File: src/config/secrets.ts
import { config } from 'dotenv';
import crypto from 'crypto';

config();

interface SecretsConfig {
  jwtSecret: string;
  databaseUrl: string;
  redisUrl: string;
  apiKeys: {
    openai?: string;
    [key: string]: string | undefined;
  };
}

function validateSecret(name: string, value: string | undefined, minLength: number = 32): string {
  if (!value) {
    throw new Error(
      `${name} must be set in environment variables. ` +
      'This is required for security.'
    );
  }

  if (value.length < minLength) {
    throw new Error(
      `${name} must be at least ${minLength} characters long. ` +
      `Current length: ${value.length}`
    );
  }

  // Check for common weak secrets
  const weakSecrets = ['secret', 'password', 'changeme', 'default'];
  if (weakSecrets.some(weak => value.toLowerCase().includes(weak))) {
    throw new Error(
      `${name} appears to be a weak secret. Please use a strong, randomly generated secret.`
    );
  }

  return value;
}

function validateDatabaseUrl(url: string | undefined): string {
  if (!url) {
    throw new Error('DATABASE_URL must be set in environment variables');
  }

  // Validate URL format
  try {
    const parsed = new URL(url);
    if (!parsed.protocol.startsWith('postgres')) {
      throw new Error('DATABASE_URL must be a PostgreSQL connection string');
    }
  } catch (error) {
    throw new Error(`Invalid DATABASE_URL format: ${error.message}`);
  }

  return url;
}

export const secrets: SecretsConfig = {
  jwtSecret: validateSecret('JWT_SECRET', process.env.JWT_SECRET, 32),
  databaseUrl: validateDatabaseUrl(process.env.DATABASE_URL),
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  apiKeys: {
    openai: process.env.OPENAI_API_KEY,
    // Add other API keys as needed
  },
};

// Log secret configuration status (without values)
console.log('Secrets configuration:');
console.log(`- JWT Secret: ${secrets.jwtSecret ? '✓ Set' : '✗ Missing'}`);
console.log(`- Database URL: ${secrets.databaseUrl ? '✓ Set' : '✗ Missing'}`);
console.log(`- Redis URL: ${secrets.redisUrl ? '✓ Set' : '✗ Missing'}`);
```

### Issue 6: Secrets Logging Risk

**Location**: All logging statements

**Security Risk**: 
- Secrets may be accidentally logged
- Error messages may expose secrets
- Debug logs may contain sensitive data

**Recommended Fix**:

```typescript
// File: src/utils/secureLogger.ts
import logger from './logger';

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

// Usage in code
import { secureLog } from '../utils/secureLogger';

// Instead of:
// logger.error('Auth error', { token, secret, user });

// Use:
secureLog('error', 'Auth error', { token, secret, user });
// Output: { token: '[REDACTED]', secret: '[REDACTED]', user: {...} }
```

---

## Input Validation and Sanitization

### Issue 7: Incomplete Input Validation

**Location**: Multiple API endpoints

**Security Risk**: 
- Missing validation on some endpoints
- Inconsistent validation patterns
- No length limits on inputs

**Recommended Fix**:

```typescript
// File: src/middleware/inputValidation.ts
import { Request, Response, NextFunction } from 'express';
import { body, validationResult, ValidationChain } from 'express-validator';
import logger from '../utils/logger';

// Common validation rules
export const commonValidations = {
  email: body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Invalid email format')
    .isLength({ max: 255 })
    .withMessage('Email must be less than 255 characters'),

  password: body('password')
    .isLength({ min: 8, max: 128 })
    .withMessage('Password must be between 8 and 128 characters')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .withMessage('Password must contain uppercase, lowercase, number, and special character'),

  userId: body('userId')
    .isMongoId()
    .withMessage('Invalid user ID format')
    .optional(),

  string: (field: string, maxLength: number = 1000) =>
    body(field)
      .trim()
      .isLength({ max: maxLength })
      .withMessage(`${field} must be less than ${maxLength} characters`)
      .escape(),

  url: (field: string) =>
    body(field)
      .isURL({ protocols: ['http', 'https'] })
      .withMessage('Invalid URL format')
      .isLength({ max: 2048 })
      .withMessage('URL must be less than 2048 characters'),

  integer: (field: string, min: number = 0, max: number = Number.MAX_SAFE_INTEGER) =>
    body(field)
      .isInt({ min, max })
      .withMessage(`${field} must be an integer between ${min} and ${max}`),

  array: (field: string, maxItems: number = 100) =>
    body(field)
      .isArray({ max: maxItems })
      .withMessage(`${field} must be an array with at most ${maxItems} items`),
};

// Validation middleware
export const validate = (validations: ValidationChain[]) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    // Run all validations
    await Promise.all(validations.map(validation => validation.run(req)));

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
        errors: errors.array().map(err => ({
          field: err.param || err.type,
          message: err.msg,
          value: err.value,
        })),
      });
    }

    next();
  };
};

// Usage example
import { validate, commonValidations } from '../middleware/inputValidation';

router.post('/users',
  validate([
    commonValidations.email,
    commonValidations.password,
    commonValidations.string('name', 100),
  ]),
  async (req, res) => {
    // Validated input available in req.body
  }
);
```

**Python Equivalent**:

```python
# File: app/middleware/input_validation.py
from fastapi import Request, HTTPException
from fastapi.security import HTTPBearer
from pydantic import BaseModel, EmailStr, validator, Field
from typing import Optional, List
import re

class EmailValidation(BaseModel):
    email: EmailStr = Field(..., max_length=255)

class PasswordValidation(BaseModel):
    password: str = Field(..., min_length=8, max_length=128)
    
    @validator('password')
    def validate_password_strength(cls, v):
        if not re.match(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])', v):
            raise ValueError(
                'Password must contain uppercase, lowercase, number, and special character'
            )
        return v

class StringValidation(BaseModel):
    value: str = Field(..., max_length=1000)
    
    @validator('value')
    def sanitize_string(cls, v):
        # Remove HTML tags
        import bleach
        return bleach.clean(v, tags=[], strip=True)

# Usage in FastAPI routes
from app.middleware.input_validation import EmailValidation, PasswordValidation

@app.post("/users")
async def create_user(user_data: EmailValidation):
    # Pydantic automatically validates
    pass
```

### Issue 8: Missing Request Size Limits

**Location**: Express and FastAPI applications

**Security Risk**: 
- No limits on request body size
- Potential for DoS via large payloads
- Memory exhaustion attacks

**Recommended Fix**:

```typescript
// File: src/middleware/requestLimits.ts
import express from 'express';

// Configure body parser limits
export const bodyParserConfig = {
  json: {
    limit: '1mb', // Maximum JSON payload size
    strict: true,
  },
  urlencoded: {
    limit: '1mb', // Maximum URL-encoded payload size
    extended: true,
    parameterLimit: 100, // Maximum number of parameters
  },
  raw: {
    limit: '5mb', // For file uploads
  },
};

// Apply in server.ts
import bodyParser from 'body-parser';

app.use(bodyParser.json(bodyParserConfig.json));
app.use(bodyParser.urlencoded(bodyParserConfig.urlencoded));

// Additional middleware for request size validation
export const requestSizeLimiter = (req: Request, res: Response, next: NextFunction) => {
  const contentLength = req.get('content-length');
  
  if (contentLength) {
    const size = parseInt(contentLength, 10);
    const maxSize = 1024 * 1024; // 1MB
    
    if (size > maxSize) {
      return res.status(413).json({
        success: false,
        message: 'Request entity too large',
        maxSize: `${maxSize / 1024}KB`,
      });
    }
  }
  
  next();
};

app.use(requestSizeLimiter);
```

**Python Equivalent**:

```python
# File: app/main.py
from fastapi import Request
from fastapi.middleware.trustedhost import TrustedHostMiddleware
import asyncio

# Configure request limits
MAX_REQUEST_SIZE = 1024 * 1024  # 1MB

@app.middleware("http")
async def limit_request_size(request: Request, call_next):
    content_length = request.headers.get("content-length")
    
    if content_length:
        size = int(content_length)
        if size > MAX_REQUEST_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"Request entity too large. Maximum size: {MAX_REQUEST_SIZE / 1024}KB"
            )
    
    response = await call_next(request)
    return response
```

---

## SQL Injection Prevention

### Issue 9: Dynamic SQL Query Building

**Location**: 
- `diri-cyrex/app/services/pricing_benchmark.py:265`
- `diri-cyrex/app/services/vendor_intelligence_service.py:543`
- `diri-cyrex/app/core/memory_manager.py:206`

**Security Risk**: 
- String concatenation in SQL queries
- Potential for SQL injection if parameters not properly escaped
- F-string usage in queries

**Current Code Example**:
```python
query += f" AND invoice_date >= ${len(params) + 1}"
query += " ORDER BY invoice_date DESC LIMIT 1000"
```

**Recommended Fix**:

```python
# File: app/database/query_builder.py
from typing import List, Optional, Any, Dict
from ..database.postgres import get_postgres_manager

class SafeQueryBuilder:
    """Build SQL queries safely with parameterized queries"""
    
    def __init__(self):
        self._conditions: List[str] = []
        self._params: List[Any] = []
        self._param_count = 0
    
    def add_condition(self, condition: str, value: Any) -> 'SafeQueryBuilder':
        """Add a condition with parameterized value"""
        self._param_count += 1
        self._conditions.append(f"{condition} ${self._param_count}")
        self._params.append(value)
        return self
    
    def add_condition_in(self, column: str, values: List[Any]) -> 'SafeQueryBuilder':
        """Add IN condition safely"""
        if not values:
            return self
        
        placeholders = []
        for value in values:
            self._param_count += 1
            placeholders.append(f"${self._param_count}")
            self._params.append(value)
        
        self._conditions.append(f"{column} IN ({', '.join(placeholders)})")
        return self
    
    def add_condition_like(self, column: str, pattern: str) -> 'SafeQueryBuilder':
        """Add LIKE condition safely"""
        self._param_count += 1
        self._conditions.append(f"{column} ILIKE ${self._param_count}")
        self._params.append(f"%{pattern}%")
        return self
    
    def build_where_clause(self) -> tuple[str, List[Any]]:
        """Build WHERE clause with parameters"""
        if not self._conditions:
            return "1=1", []
        
        where_clause = " AND ".join(self._conditions)
        return where_clause, self._params
    
    def reset(self):
        """Reset builder for reuse"""
        self._conditions = []
        self._params = []
        self._param_count = 0

# Updated pricing_benchmark.py
from ..database.query_builder import SafeQueryBuilder

async def _calculate_benchmark_from_db(
    self,
    service_category: str,
    industry: IndustryNiche,
    location: Optional[str] = None,
    invoice_date: Optional[datetime] = None
) -> Optional[PricingBenchmark]:
    """Calculate benchmark from database with safe queries"""
    try:
        builder = SafeQueryBuilder()
        
        # Add conditions safely
        builder.add_condition("metadata->>'service_category' =", service_category)
        builder.add_condition("metadata->>'industry' =", industry.value)
        builder.add_condition("metadata->>'total_amount' IS NOT NULL", True)
        
        if location:
            builder.add_condition("metadata->>'location' =", location)
        
        if invoice_date:
            date_start = invoice_date - timedelta(days=180)
            builder.add_condition("invoice_date >=", date_start)
        
        where_clause, params = builder.build_where_clause()
        
        # Build final query with parameterized values
        query = f"""
            SELECT 
                total_amount,
                invoice_date,
                location
            FROM agent_interactions
            WHERE {where_clause}
            ORDER BY invoice_date DESC
            LIMIT $1
        """
        params.append(1000)
        
        postgres = await get_postgres_manager()
        rows = await postgres.fetch(query, *params)
        
        # ... rest of processing ...
```

### Issue 10: Raw SQL Execution Without Validation

**Location**: `diri-cyrex/app/agents/tools/comprehensive_api_tools.py:485-528`

**Current Code**:
```python
async def _db_query(self, query: str, params: Optional[List[Any]] = None) -> ToolResult:
    if not query.strip().upper().startswith("SELECT"):
        return ToolResult(success=False, error="Only SELECT queries are allowed")
    
    postgres = await get_postgres_manager()
    rows = await postgres.fetch(query, *(params or []))
```

**Security Risk**: 
- Only checks for SELECT but doesn't validate query structure
- No validation of table names
- No validation of column names
- Potential for SQL injection in complex SELECT statements

**Recommended Fix**:

```python
# File: app/database/query_validator.py
import re
from typing import List, Optional, Set

class QueryValidator:
    """Validate and sanitize SQL queries"""
    
    # Allowed SQL keywords (read-only operations)
    ALLOWED_KEYWORDS = {
        'SELECT', 'FROM', 'WHERE', 'ORDER', 'BY', 'GROUP', 'HAVING',
        'LIMIT', 'OFFSET', 'JOIN', 'INNER', 'LEFT', 'RIGHT', 'ON',
        'AS', 'AND', 'OR', 'NOT', 'IN', 'LIKE', 'ILIKE', 'IS', 'NULL',
        'BETWEEN', 'EXISTS', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
        'DISTINCT', 'COUNT', 'SUM', 'AVG', 'MAX', 'MIN', 'COALESCE',
    }
    
    # Forbidden SQL keywords (write operations)
    FORBIDDEN_KEYWORDS = {
        'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE', 'ALTER',
        'TRUNCATE', 'GRANT', 'REVOKE', 'EXEC', 'EXECUTE', 'CALL',
        'DECLARE', 'BEGIN', 'COMMIT', 'ROLLBACK', 'TRANSACTION',
    }
    
    # Allowed table names (whitelist approach)
    ALLOWED_TABLES = {
        'agent_interactions',
        'memories',
        'cyrex_vendors',
        'auth_tokens',
        # Add other allowed tables
    }
    
    @staticmethod
    def validate_select_query(query: str) -> tuple[bool, Optional[str]]:
        """Validate SELECT query structure"""
        query_upper = query.upper().strip()
        
        # Must start with SELECT
        if not query_upper.startswith('SELECT'):
            return False, "Query must start with SELECT"
        
        # Check for forbidden keywords
        for keyword in QueryValidator.FORBIDDEN_KEYWORDS:
            if keyword in query_upper:
                return False, f"Forbidden keyword detected: {keyword}"
        
        # Extract table names from FROM clause
        from_match = re.search(r'FROM\s+(\w+)', query_upper)
        if from_match:
            table_name = from_match.group(1).lower()
            if table_name not in QueryValidator.ALLOWED_TABLES:
                return False, f"Table not allowed: {table_name}"
        
        # Check for multiple statements (SQL injection attempt)
        if ';' in query and query.count(';') > 1:
            return False, "Multiple statements not allowed"
        
        # Check for comments (potential SQL injection)
        if '--' in query or '/*' in query:
            return False, "Comments not allowed in queries"
        
        return True, None
    
    @staticmethod
    def sanitize_table_name(table_name: str) -> str:
        """Sanitize table name to prevent injection"""
        # Only allow alphanumeric and underscore
        sanitized = re.sub(r'[^a-zA-Z0-9_]', '', table_name)
        if sanitized not in QueryValidator.ALLOWED_TABLES:
            raise ValueError(f"Table not allowed: {table_name}")
        return sanitized
    
    @staticmethod
    def sanitize_column_name(column_name: str) -> str:
        """Sanitize column name to prevent injection"""
        # Only allow alphanumeric, underscore, and dot (for JSON paths)
        sanitized = re.sub(r'[^a-zA-Z0-9_.]', '', column_name)
        return sanitized

# Updated comprehensive_api_tools.py
from ..database.query_validator import QueryValidator

async def _db_query(
    self,
    query: str,
    params: Optional[List[Any]] = None,
) -> ToolResult:
    """Database SELECT query with validation"""
    start = datetime.utcnow()
    try:
        # Validate query structure
        is_valid, error_msg = QueryValidator.validate_select_query(query)
        if not is_valid:
            logger.warning(f"Invalid query rejected: {error_msg}")
            return ToolResult(success=False, error=error_msg)
        
        # Ensure params is a list
        if params is None:
            params = []
        
        # Additional validation: check params count matches placeholders
        placeholder_count = query.count('$')
        if placeholder_count != len(params):
            return ToolResult(
                success=False,
                error=f"Parameter count mismatch: {placeholder_count} placeholders, {len(params)} parameters"
            )
        
        postgres = await get_postgres_manager()
        rows = await postgres.fetch(query, *params)
        
        result = [dict(row) for row in rows]
        
        return ToolResult(
            success=True,
            result=result,
            execution_time_ms=(datetime.utcnow() - start).total_seconds() * 1000,
            metadata={"row_count": len(result)},
        )
    except Exception as e:
        logger.error(f"Database query error: {e}")
        return ToolResult(success=False, error="Database query failed")
```

---

## Cross-Site Scripting (XSS) Prevention

### Issue 11: Missing Output Encoding

**Location**: API responses, frontend rendering

**Security Risk**: 
- User input may be reflected in responses without encoding
- XSS attacks possible if frontend doesn't encode
- API responses may contain unencoded user data

**Recommended Fix**:

```typescript
// File: src/utils/outputEncoding.ts
import he from 'he'; // HTML entity encoding library

export function encodeHtml(text: string): string {
  if (typeof text !== 'string') {
    return String(text);
  }
  return he.encode(text, {
    useNamedReferences: true,
    allowUnsafeSymbols: false,
  });
}

export function encodeUrl(text: string): string {
  return encodeURIComponent(text);
}

export function encodeJson(text: string): string {
  return JSON.stringify(text);
}

// Middleware to automatically encode responses
export const xssProtection = (req: Request, res: Response, next: NextFunction) => {
  const originalJson = res.json;
  
  res.json = function(data: any) {
    // Recursively encode string values in response
    const encoded = encodeResponseData(data);
    return originalJson.call(this, encoded);
  };
  
  next();
};

function encodeResponseData(data: any): any {
  if (typeof data === 'string') {
    // Don't double-encode if already encoded
    return data;
  }
  
  if (Array.isArray(data)) {
    return data.map(encodeResponseData);
  }
  
  if (data !== null && typeof data === 'object') {
    const encoded: any = {};
    for (const [key, value] of Object.entries(data)) {
      // Skip encoding for known safe fields
      const safeFields = ['id', 'timestamp', 'status', 'success'];
      if (safeFields.includes(key.toLowerCase())) {
        encoded[key] = value;
      } else {
        encoded[key] = encodeResponseData(value);
      }
    }
    return encoded;
  }
  
  return data;
}
```

**Frontend React Fix**:

```typescript
// File: src/utils/xssProtection.tsx
import React from 'react';
import DOMPurify from 'dompurify';

export function SafeHtml({ html }: { html: string }) {
  const sanitized = DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
    ALLOWED_ATTR: ['href', 'target'],
  });
  
  return <div dangerouslySetInnerHTML={{ __html: sanitized }} />;
}

// Usage
function UserProfile({ user }: { user: User }) {
  return (
    <div>
      <h1>{user.name}</h1> {/* React automatically escapes */}
      <SafeHtml html={user.bio} /> {/* For HTML content */}
    </div>
  );
}
```

---

## CORS Configuration Security

### Issue 12: Overly Permissive CORS Configuration

**Location**: 
- `deepiri-core-api/src/server.ts:83-117`
- `diri-cyrex/app/main.py:88-105`

**Current Code**:
```typescript
const corsAllowedOrigins: string[] = [
  'http://localhost:5173',
  'http://localhost:3000',
  process.env.CORS_ORIGIN
].filter(Boolean) as string[];

app.use(cors({
  origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    if (!origin || corsAllowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  exposedHeaders: ['x-request-id']
}));
```

**Security Risk**: 
- Duplicate CORS configuration
- No environment-based restrictions
- Allows all methods
- Credentials enabled for all origins

**Recommended Fix**:

```typescript
// File: src/config/corsConfig.ts
import { config } from 'dotenv';

config();

const NODE_ENV = process.env.NODE_ENV || 'development';

// Production origins (strict)
const PRODUCTION_ORIGINS = [
  'https://deepiri.com',
  'https://www.deepiri.com',
  'https://app.deepiri.com',
].filter(Boolean);

// Development origins
const DEVELOPMENT_ORIGINS = [
  'http://localhost:5173',
  'http://localhost:3000',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:3000',
];

// Additional allowed origins from environment
const ADDITIONAL_ORIGINS = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map(o => o.trim())
  : [];

function getAllowedOrigins(): string[] {
  if (NODE_ENV === 'production') {
    return [...PRODUCTION_ORIGINS, ...ADDITIONAL_ORIGINS];
  }
  
  return [...DEVELOPMENT_ORIGINS, ...PRODUCTION_ORIGINS, ...ADDITIONAL_ORIGINS];
}

export const corsConfig = {
  origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    const allowedOrigins = getAllowedOrigins();
    
    // Allow requests with no origin (mobile apps, Postman, etc.) in development only
    if (!origin) {
      if (NODE_ENV === 'development') {
        return callback(null, true);
      }
      return callback(new Error('CORS: Origin required in production'));
    }
    
    // Check if origin is allowed
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    
    // Log blocked origin for security monitoring
    console.warn(`CORS: Blocked origin: ${origin}`);
    callback(new Error(`CORS: Origin ${origin} not allowed`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With',
    'X-Request-ID',
    'X-API-Key',
  ],
  exposedHeaders: ['x-request-id', 'x-rate-limit-remaining', 'x-rate-limit-reset'],
  maxAge: 86400, // 24 hours
  preflightContinue: false,
  optionsSuccessStatus: 204,
};

// Updated server.ts
import { corsConfig } from './config/corsConfig';
import cors from 'cors';

// Single CORS configuration
app.use(cors(corsConfig));
```

**Python Equivalent**:

```python
# File: app/config/cors_config.py
import os
from typing import List

NODE_ENV = os.getenv('NODE_ENV', 'development')

PRODUCTION_ORIGINS = [
    'https://deepiri.com',
    'https://www.deepiri.com',
    'https://app.deepiri.com',
]

DEVELOPMENT_ORIGINS = [
    'http://localhost:5173',
    'http://localhost:3000',
    'http://127.0.0.1:5173',
    'http://127.0.0.1:3000',
]

def get_allowed_origins() -> List[str]:
    additional = os.getenv('CORS_ORIGINS', '').split(',')
    additional = [o.strip() for o in additional if o.strip()]
    
    if NODE_ENV == 'production':
        return PRODUCTION_ORIGINS + additional
    return DEVELOPMENT_ORIGINS + PRODUCTION_ORIGINS + additional

# Updated main.py
from app.config.cors_config import get_allowed_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_allowed_origins(),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Content-Type", "Authorization", "X-Requested-With", "X-Request-ID", "X-API-Key"],
    expose_headers=["x-request-id", "x-rate-limit-remaining", "x-rate-limit-reset"],
    max_age=86400,
)
```

---

## Error Handling and Information Disclosure

### Issue 13: Stack Traces in Production

**Location**: 
- `deepiri-core-api/src/middleware/errorHandler.ts:71-79`
- `diri-cyrex/app/main.py:162-173`

**Current Code**:
```typescript
if (process.env.NODE_ENV === 'development') {
  errorResponse.stack = err.stack;
  errorResponse.context = {
    method: req.method,
    url: req.url,
    userAgent: req.get('User-Agent'),
    ip: req.ip
  };
}
```

**Security Risk**: 
- May accidentally expose stack traces
- Error messages may reveal system internals
- Database errors may leak schema information

**Recommended Fix**:

```typescript
// File: src/middleware/secureErrorHandler.ts
import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger';

interface AppError extends Error {
  statusCode?: number;
  isOperational?: boolean;
  code?: string;
}

// Error codes for client-facing messages
const ERROR_CODES = {
  AUTHENTICATION_FAILED: 'AUTH_001',
  AUTHORIZATION_FAILED: 'AUTH_002',
  VALIDATION_FAILED: 'VAL_001',
  NOT_FOUND: 'RES_001',
  RATE_LIMIT_EXCEEDED: 'RATE_001',
  INTERNAL_ERROR: 'SYS_001',
};

// Safe error messages (no internal details)
const SAFE_ERROR_MESSAGES: Record<string, string> = {
  'CastError': 'Invalid resource identifier',
  'ValidationError': 'Invalid input data',
  'JsonWebTokenError': 'Invalid authentication token',
  'TokenExpiredError': 'Authentication token expired',
  'MongoError': 'Database operation failed',
  'MongooseError': 'Database operation failed',
};

export const secureErrorHandler = (
  err: AppError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const requestId = (req as any).requestId || 'unknown';
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  // Log full error details (server-side only)
  logger.error('Request error', {
    requestId,
    method: req.method,
    path: req.url,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
    userId: (req as any).user?.userId,
    error: {
      name: err.name,
      message: err.message,
      stack: err.stack, // Full stack in logs
      code: err.code,
      statusCode: err.statusCode,
    },
  });

  // Determine status code
  let statusCode = err.statusCode || 500;
  let errorCode = ERROR_CODES.INTERNAL_ERROR;
  let message = 'An error occurred';

  // Map specific errors to safe messages
  if (err.name === 'CastError') {
    statusCode = 404;
    errorCode = ERROR_CODES.NOT_FOUND;
    message = SAFE_ERROR_MESSAGES['CastError'] || 'Resource not found';
  } else if (err.name === 'ValidationError') {
    statusCode = 400;
    errorCode = ERROR_CODES.VALIDATION_FAILED;
    message = SAFE_ERROR_MESSAGES['ValidationError'] || 'Invalid input data';
  } else if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
    statusCode = 401;
    errorCode = ERROR_CODES.AUTHENTICATION_FAILED;
    message = SAFE_ERROR_MESSAGES[err.name] || 'Authentication failed';
  } else if (err.statusCode === 429) {
    statusCode = 429;
    errorCode = ERROR_CODES.RATE_LIMIT_EXCEEDED;
    message = 'Too many requests. Please try again later.';
  } else if (err.statusCode) {
    statusCode = err.statusCode;
    message = err.message || 'An error occurred';
  }

  // Build response
  const errorResponse: any = {
    success: false,
    error: {
      code: errorCode,
      message: message,
      requestId: requestId,
      timestamp: new Date().toISOString(),
    },
  };

  // Only include additional details in development
  if (isDevelopment) {
    errorResponse.error.details = {
      name: err.name,
      originalMessage: err.message,
      stack: err.stack,
    };
  }

  // Never expose database errors, file paths, or internal details
  if (statusCode === 500 && !isDevelopment) {
    errorResponse.error.message = 'Internal server error. Please contact support if this persists.';
  }

  res.status(statusCode).json(errorResponse);
};
```

---

## Security Headers Implementation

### Issue 14: Missing Security Headers

**Location**: Express and FastAPI applications

**Security Risk**: 
- Missing security headers
- Vulnerable to clickjacking
- Missing HSTS
- No CSP policy

**Recommended Fix**:

```typescript
// File: src/middleware/securityHeaders.ts
import { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';

// Configure Helmet with security headers
export const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"], // Allow inline styles for React
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'", process.env.API_URL || 'http://localhost:5000'],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false, // May break some integrations
  crossOriginOpenerPolicy: { policy: 'same-origin' },
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  dnsPrefetchControl: true,
  frameguard: { action: 'deny' }, // Prevent clickjacking
  hidePoweredBy: true, // Remove X-Powered-By header
  hsts: {
    maxAge: 31536000, // 1 year
    includeSubDomains: true,
    preload: true,
  },
  ieNoOpen: true,
  noSniff: true, // Prevent MIME type sniffing
  originAgentCluster: true,
  permittedCrossDomainPolicies: false,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  xssFilter: true,
});

// Additional custom headers
export const customSecurityHeaders = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // X-Request-ID for request tracking
  if (!res.getHeader('X-Request-ID')) {
    const requestId = (req as any).requestId || 'unknown';
    res.setHeader('X-Request-ID', requestId);
  }

  // X-Content-Type-Options
  res.setHeader('X-Content-Type-Options', 'nosniff');

  // X-Frame-Options (redundant with Helmet but explicit)
  res.setHeader('X-Frame-Options', 'DENY');

  // Permissions-Policy (formerly Feature-Policy)
  res.setHeader(
    'Permissions-Policy',
    'geolocation=(), microphone=(), camera=()'
  );

  next();
};

// Apply in server.ts
import { securityHeaders, customSecurityHeaders } from './middleware/securityHeaders';

app.use(securityHeaders);
app.use(customSecurityHeaders);
```

**Python Equivalent**:

```python
# File: app/middleware/security_headers.py
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        
        # Security headers
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-XSS-Protection'] = '1; mode=block'
        response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
        response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
        response.headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'
        
        # Content Security Policy
        csp = (
            "default-src 'self'; "
            "script-src 'self'; "
            "style-src 'self' 'unsafe-inline'; "
            "img-src 'self' data: https:; "
            "connect-src 'self'; "
            "font-src 'self'; "
            "object-src 'none'; "
            "frame-src 'none';"
        )
        response.headers['Content-Security-Policy'] = csp
        
        return response

# Apply in main.py
from app.middleware.security_headers import SecurityHeadersMiddleware

app.add_middleware(SecurityHeadersMiddleware)
```

---

## Rate Limiting Enhancements

### Issue 15: Inconsistent Rate Limiting

**Location**: Rate limiting implementations

**Security Risk**: 
- Some endpoints may not have rate limiting
- Rate limits may be too permissive
- No differentiation between user types

**Recommended Fix**:

```typescript
// File: src/middleware/enhancedRateLimiter.ts
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import Redis from 'ioredis';
import { Request, Response } from 'express';

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

// Create rate limiters for different scenarios
export const rateLimiters = {
  // Strict limiter for authentication endpoints
  auth: rateLimit({
    store: new RedisStore({
      client: redis,
      prefix: 'rl:auth:',
    }),
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // 5 attempts per 15 minutes
    message: 'Too many authentication attempts. Please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: true, // Don't count successful requests
    keyGenerator: (req: Request) => {
      // Use email if available, otherwise IP
      const email = req.body?.email;
      return email ? `auth:${email}` : `auth:${req.ip}`;
    },
    handler: (req: Request, res: Response) => {
      logger.warn('Rate limit exceeded - auth', {
        ip: req.ip,
        email: req.body?.email,
        path: req.path,
      });
      res.status(429).json({
        success: false,
        message: 'Too many authentication attempts. Please try again later.',
        retryAfter: Math.ceil(15 * 60), // 15 minutes in seconds
      });
    },
  }),

  // Moderate limiter for write operations
  write: rateLimit({
    store: new RedisStore({
      client: redis,
      prefix: 'rl:write:',
    }),
    windowMs: 15 * 60 * 1000,
    max: 50,
    message: 'Too many write requests. Please slow down.',
    standardHeaders: true,
    keyGenerator: (req: Request) => {
      const user = (req as any).user;
      return user ? `write:user:${user.userId}` : `write:ip:${req.ip}`;
    },
  }),

  // Lenient limiter for read operations
  read: rateLimit({
    store: new RedisStore({
      client: redis,
      prefix: 'rl:read:',
    }),
    windowMs: 15 * 60 * 1000,
    max: 200,
    message: 'Too many read requests. Please try again later.',
    standardHeaders: true,
    keyGenerator: (req: Request) => {
      const user = (req as any).user;
      return user ? `read:user:${user.userId}` : `read:ip:${req.ip}`;
    },
  }),

  // Global limiter (applied to all routes)
  global: rateLimit({
    store: new RedisStore({
      client: redis,
      prefix: 'rl:global:',
    }),
    windowMs: 15 * 60 * 1000,
    max: 100,
    message: 'Too many requests. Please try again later.',
    standardHeaders: true,
    keyGenerator: (req: Request) => {
      return req.ip || 'unknown';
    },
  }),
};

// Usage
import { rateLimiters } from './middleware/enhancedRateLimiter';

// Apply to auth routes
router.post('/login', rateLimiters.auth, authController.login);
router.post('/register', rateLimiters.auth, authController.register);

// Apply to write routes
router.post('/items', rateLimiters.write, itemController.create);
router.put('/items/:id', rateLimiters.write, itemController.update);

// Apply to read routes
router.get('/items', rateLimiters.read, itemController.list);
```

---

## Session Management Security

### Issue 16: Missing Session Security Configuration

**Location**: Session management (if implemented)

**Security Risk**: 
- Sessions may not be properly secured
- No session timeout
- Weak session IDs

**Recommended Fix**:

```typescript
// File: src/config/sessionConfig.ts
import session from 'express-session';
import RedisStore from 'connect-redis';
import Redis from 'ioredis';
import crypto from 'crypto';

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

export const sessionConfig = {
  store: new RedisStore({
    client: redis,
    prefix: 'session:',
  }),
  secret: process.env.SESSION_SECRET || (() => {
    throw new Error('SESSION_SECRET must be set');
  })(),
  name: 'sessionId', // Don't use default 'connect.sid'
  resave: false,
  saveUninitialized: false, // Don't create session until something is stored
  rolling: true, // Reset expiration on activity
  cookie: {
    secure: process.env.NODE_ENV === 'production', // HTTPS only in production
    httpOnly: true, // Prevent XSS
    sameSite: 'strict' as const, // CSRF protection
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    domain: process.env.COOKIE_DOMAIN, // Set in production
    path: '/',
  },
  genid: () => {
    // Generate cryptographically secure session ID
    return crypto.randomBytes(32).toString('hex');
  },
};

// Apply in server.ts
import session from 'express-session';
import { sessionConfig } from './config/sessionConfig';

app.use(session(sessionConfig));
```

---

## API Security Enhancements

### Issue 17: Missing API Versioning Security

**Location**: API routes

**Security Risk**: 
- No API versioning
- Breaking changes affect all clients
- No deprecation strategy

**Recommended Fix**:

```typescript
// File: src/middleware/apiVersioning.ts
import { Request, Response, NextFunction } from 'express';

const SUPPORTED_VERSIONS = ['v1', 'v2'];
const CURRENT_VERSION = 'v2';
const DEPRECATED_VERSIONS = ['v1'];

export const apiVersioning = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Extract version from header or URL
  const version = 
    req.headers['api-version'] ||
    req.headers['x-api-version'] ||
    req.path.split('/')[2] || // /api/v1/...
    CURRENT_VERSION;

  // Validate version
  if (!SUPPORTED_VERSIONS.includes(version)) {
    return res.status(400).json({
      success: false,
      message: `Unsupported API version: ${version}. Supported versions: ${SUPPORTED_VERSIONS.join(', ')}`,
    });
  }

  // Check if deprecated
  if (DEPRECATED_VERSIONS.includes(version)) {
    res.setHeader('X-API-Deprecated', 'true');
    res.setHeader('X-API-Deprecation-Date', '2026-12-31');
    res.setHeader('X-API-Sunset-Date', '2027-06-30');
    res.setHeader('Link', '</api/v2>; rel="successor-version"');
  }

  // Set version in request
  (req as any).apiVersion = version;

  next();
};
```

---

## Database Security

### Issue 18: Database Connection Security

**Location**: Database connection configurations

**Security Risk**: 
- Connections may not use SSL
- Weak connection pooling
- No connection timeout

**Recommended Fix**:

```typescript
// File: src/config/databaseConfig.ts
import mongoose from 'mongoose';

export const databaseConfig = {
  // Connection options
  options: {
    // Use SSL in production
    ssl: process.env.NODE_ENV === 'production',
    sslValidate: process.env.NODE_ENV === 'production',
    
    // Connection pool settings
    maxPoolSize: 10,
    minPoolSize: 2,
    maxIdleTimeMS: 30000,
    
    // Timeouts
    connectTimeoutMS: 10000,
    socketTimeoutMS: 45000,
    serverSelectionTimeoutMS: 10000,
    
    // Retry settings
    retryWrites: true,
    retryReads: true,
    
    // Authentication
    authSource: 'admin',
    
    // Compression
    compressors: ['zlib'],
  },
  
  // Connection string validation
  validateConnectionString(url: string): boolean {
    try {
      const parsed = new URL(url);
      
      // Must use mongodb:// or mongodb+srv://
      if (!parsed.protocol.startsWith('mongodb')) {
        return false;
      }
      
      // Must have authentication in production
      if (process.env.NODE_ENV === 'production' && !parsed.username) {
        return false;
      }
      
      return true;
    } catch {
      return false;
    }
  },
};

// Usage
import mongoose from 'mongoose';
import { databaseConfig } from './config/databaseConfig';

const connectionString = process.env.DATABASE_URL || '';

if (!databaseConfig.validateConnectionString(connectionString)) {
  throw new Error('Invalid database connection string');
}

mongoose.connect(connectionString, databaseConfig.options);
```

**Python Equivalent**:

```python
# File: app/database/postgres_secure.py
import asyncpg
from ssl import create_default_context
import os

class SecurePostgreSQLManager:
    def __init__(self):
        self.ssl_context = None
        if os.getenv('NODE_ENV') == 'production':
            self.ssl_context = create_default_context()
    
    async def get_connection(self):
        connection_string = os.getenv('DATABASE_URL')
        
        if not connection_string:
            raise ValueError('DATABASE_URL must be set')
        
        # Parse and validate connection string
        # ... validation logic ...
        
        return await asyncpg.connect(
            connection_string,
            ssl=self.ssl_context,
            command_timeout=10,  # 10 second timeout
            server_settings={
                'application_name': 'deepiri-api',
            },
        )
```

---

## Logging and Monitoring Security

### Issue 19: Sensitive Data in Logs

**Location**: All logging statements

**Security Risk**: 
- Passwords, tokens, secrets may be logged
- PII in logs
- Stack traces in logs

**Recommended Fix**:

```typescript
// File: src/utils/secureLogger.ts (enhanced)
import logger from './logger';

const SENSITIVE_PATTERNS = [
  /password["\s]*[:=]["\s]*([^"}\s,]+)/gi,
  /secret["\s]*[:=]["\s]*([^"}\s,]+)/gi,
  /token["\s]*[:=]["\s]*([^"}\s,]+)/gi,
  /api[_-]?key["\s]*[:=]["\s]*([^"}\s,]+)/gi,
  /authorization["\s]*[:=]["\s]*([^"}\s,]+)/gi,
  /bearer\s+([a-zA-Z0-9._-]+)/gi,
];

function sanitizeLogMessage(message: string): string {
  let sanitized = message;
  
  SENSITIVE_PATTERNS.forEach(pattern => {
    sanitized = sanitized.replace(pattern, (match, value) => {
      return match.replace(value, '[REDACTED]');
    });
  });
  
  return sanitized;
}

export function secureLog(
  level: 'info' | 'warn' | 'error',
  message: string,
  data?: any
): void {
  const sanitizedMessage = sanitizeLogMessage(message);
  const sanitizedData = data ? sanitizeObject(data) : undefined;
  
  logger[level](sanitizedMessage, sanitizedData);
}
```

---

## Dependency Security

### Issue 20: Outdated Dependencies

**Location**: package.json, requirements.txt

**Security Risk**: 
- Vulnerable dependencies
- No automated scanning
- No dependency update strategy

**Recommended Fix**:

```bash
# Add to package.json scripts
{
  "scripts": {
    "security:audit": "npm audit --audit-level=moderate",
    "security:fix": "npm audit fix",
    "security:check": "npm audit && npm outdated"
  }
}

# Add to CI/CD pipeline
# .github/workflows/security.yml
name: Security Audit
on:
  schedule:
    - cron: '0 0 * * 1' # Weekly
  push:
    branches: [main]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm ci
      - run: npm audit --audit-level=moderate
      - run: npm outdated
```

---

## Implementation Priority

### Critical (Implement Immediately)
1. JWT Secret Validation (Issue 1, 3)
2. Secrets Management (Issue 4, 5)
3. SQL Injection Prevention (Issue 9, 10)
4. Error Handling (Issue 13)
5. Security Headers (Issue 14)

### High (Implement Within 1 Week)
6. Input Validation (Issue 7, 8)
7. CORS Configuration (Issue 12)
8. Rate Limiting (Issue 15)
9. XSS Prevention (Issue 11)

### Medium (Implement Within 1 Month)
10. Token Revocation (Issue 2)
11. Session Management (Issue 16)
12. API Versioning (Issue 17)
13. Database Security (Issue 18)
14. Logging Security (Issue 19)
15. Dependency Security (Issue 20)

---

## Testing Security Enhancements

### Security Testing Checklist

```typescript
// File: tests/security/security.test.ts
import request from 'supertest';
import app from '../../src/server';

describe('Security Tests', () => {
  describe('Authentication', () => {
    it('should reject requests without JWT secret', async () => {
      // Test that app fails to start without JWT_SECRET
    });

    it('should reject weak JWT secrets', async () => {
      // Test validation
    });
  });

  describe('Input Validation', () => {
    it('should reject SQL injection attempts', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({ name: "'; DROP TABLE users; --" });
      
      expect(response.status).toBe(400);
    });

    it('should reject XSS attempts', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({ name: '<script>alert("XSS")</script>' });
      
      expect(response.status).toBe(400);
    });
  });

  describe('Rate Limiting', () => {
    it('should enforce rate limits', async () => {
      // Make 6 requests rapidly
      for (let i = 0; i < 6; i++) {
        await request(app).post('/api/auth/login');
      }
      
      const response = await request(app).post('/api/auth/login');
      expect(response.status).toBe(429);
    });
  });

  describe('CORS', () => {
    it('should reject unauthorized origins', async () => {
      const response = await request(app)
        .get('/api/users')
        .set('Origin', 'https://evil.com');
      
      expect(response.status).toBe(403);
    });
  });

  describe('Error Handling', () => {
    it('should not expose stack traces in production', async () => {
      process.env.NODE_ENV = 'production';
      // Trigger error
      const response = await request(app).get('/api/error');
      
      expect(response.body).not.toHaveProperty('stack');
    });
  });
});
```

---

## Conclusion

This document provides comprehensive code-level security enhancements for the Deepiri platform. All issues should be addressed according to the implementation priority, with critical issues resolved immediately.

**Next Steps**:
1. Review and prioritize issues based on your risk assessment
2. Create implementation tickets for each issue
3. Implement fixes following the recommended patterns
4. Test all security enhancements
5. Update security documentation
6. Conduct security code review
7. Schedule regular security audits

**Maintenance**:
- Review this document quarterly
- Update as new security issues are discovered
- Keep security dependencies updated
- Regular security testing
- Threat modeling updates

---

## Additional Security Enhancements

### Issue 21: File Upload Security

**Location**: File upload endpoints (if any)

**Security Risk**: 
- No file type validation
- No file size limits
- Malicious file uploads possible
- Path traversal vulnerabilities

**Recommended Fix**:

```typescript
// File: src/middleware/fileUploadSecurity.ts
import multer from 'multer';
import { Request } from 'express';
import crypto from 'crypto';
import path from 'path';
import fs from 'fs';

// Allowed MIME types
const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'application/pdf',
  'text/plain',
];

// Allowed file extensions
const ALLOWED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.pdf', '.txt'];

// Maximum file size (5MB)
const MAX_FILE_SIZE = 5 * 1024 * 1024;

// Storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(process.cwd(), 'uploads');
    
    // Create directory if it doesn't exist
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Generate secure filename
    const ext = path.extname(file.originalname);
    const randomName = crypto.randomBytes(16).toString('hex');
    const sanitizedName = file.originalname
      .replace(/[^a-zA-Z0-9.-]/g, '_')
      .substring(0, 100);
    
    cb(null, `${randomName}_${sanitizedName}${ext}`);
  },
});

// File filter
const fileFilter = (req: Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  // Check MIME type
  if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    return cb(new Error(`File type not allowed: ${file.mimetype}`));
  }
  
  // Check file extension
  const ext = path.extname(file.originalname).toLowerCase();
  if (!ALLOWED_EXTENSIONS.includes(ext)) {
    return cb(new Error(`File extension not allowed: ${ext}`));
  }
  
  // Check for path traversal
  if (file.originalname.includes('..') || file.originalname.includes('/') || file.originalname.includes('\\')) {
    return cb(new Error('Invalid filename: path traversal detected'));
  }
  
  cb(null, true);
};

export const fileUpload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 5, // Maximum 5 files per request
  },
});

// Additional virus scanning (if available)
export const scanFile = async (filePath: string): Promise<boolean> => {
  // Integrate with ClamAV or similar antivirus
  // For now, return true (no scanning)
  return true;
};

// Usage in routes
import { fileUpload, scanFile } from '../middleware/fileUploadSecurity';

router.post('/upload',
  fileUpload.array('files', 5),
  async (req: Request, res: Response) => {
    const files = req.files as Express.Multer.File[];
    
    // Scan files for viruses
    for (const file of files) {
      const isSafe = await scanFile(file.path);
      if (!isSafe) {
        // Delete malicious file
        fs.unlinkSync(file.path);
        return res.status(400).json({
          success: false,
          message: 'File failed security scan',
        });
      }
    }
    
    // Process files
    res.json({ success: true, files: files.map(f => f.filename) });
  }
);
```

### Issue 22: Command Injection Prevention

**Location**: Code that executes system commands

**Security Risk**: 
- Command injection vulnerabilities
- Unsanitized user input in commands
- Arbitrary command execution

**Recommended Fix**:

```typescript
// File: src/utils/commandExecutor.ts
import { exec, spawn } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Whitelist of allowed commands
const ALLOWED_COMMANDS = [
  'git',
  'npm',
  'node',
  // Add other safe commands
];

// Allowed command arguments patterns
const ALLOWED_ARG_PATTERNS = [
  /^--version$/,
  /^--help$/,
  /^status$/,
  /^log$/,
  // Add safe argument patterns
];

export class SecureCommandExecutor {
  /**
   * Execute command safely with validation
   */
  static async execute(
    command: string,
    args: string[] = [],
    options: { timeout?: number } = {}
  ): Promise<{ stdout: string; stderr: string }> {
    // Validate command
    if (!ALLOWED_COMMANDS.includes(command)) {
      throw new Error(`Command not allowed: ${command}`);
    }
    
    // Validate arguments
    for (const arg of args) {
      // Check for command injection attempts
      if (arg.includes(';') || arg.includes('|') || arg.includes('&') || arg.includes('$')) {
        throw new Error(`Invalid argument: potential command injection detected`);
      }
      
      // Check against whitelist patterns
      const isAllowed = ALLOWED_ARG_PATTERNS.some(pattern => pattern.test(arg));
      if (!isAllowed) {
        throw new Error(`Argument not allowed: ${arg}`);
      }
    }
    
    // Build command with arguments
    const fullCommand = `${command} ${args.join(' ')}`;
    
    // Execute with timeout
    const timeout = options.timeout || 30000; // 30 seconds default
    
    try {
      const { stdout, stderr } = await Promise.race([
        execAsync(fullCommand, {
          timeout,
          maxBuffer: 1024 * 1024, // 1MB max output
        }),
        new Promise<never>((_, reject) => {
          setTimeout(() => reject(new Error('Command timeout')), timeout);
        }),
      ]);
      
      return { stdout, stderr };
    } catch (error: any) {
      throw new Error(`Command execution failed: ${error.message}`);
    }
  }
  
  /**
   * Execute command using spawn (more secure)
   */
  static async spawn(
    command: string,
    args: string[] = [],
    options: { timeout?: number } = {}
  ): Promise<{ stdout: string; stderr: string }> {
    // Validate command and arguments (same as above)
    if (!ALLOWED_COMMANDS.includes(command)) {
      throw new Error(`Command not allowed: ${command}`);
    }
    
    return new Promise((resolve, reject) => {
      const process = spawn(command, args, {
        stdio: ['pipe', 'pipe', 'pipe'],
      });
      
      let stdout = '';
      let stderr = '';
      
      process.stdout.on('data', (data) => {
        stdout += data.toString();
      });
      
      process.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      process.on('close', (code) => {
        if (code === 0) {
          resolve({ stdout, stderr });
        } else {
          reject(new Error(`Command failed with code ${code}: ${stderr}`));
        }
      });
      
      process.on('error', (error) => {
        reject(new Error(`Command execution error: ${error.message}`));
      });
      
      // Timeout
      const timeout = options.timeout || 30000;
      setTimeout(() => {
        process.kill();
        reject(new Error('Command timeout'));
      }, timeout);
    });
  }
}

// Usage
import { SecureCommandExecutor } from '../utils/commandExecutor';

try {
  const result = await SecureCommandExecutor.execute('git', ['status']);
  console.log(result.stdout);
} catch (error) {
  console.error('Command execution failed:', error);
}
```

### Issue 23: XML External Entity (XXE) Prevention

**Location**: XML parsing code

**Security Risk**: 
- XXE attacks
- External entity injection
- Local file disclosure

**Recommended Fix**:

```typescript
// File: src/utils/xmlParser.ts
import { parseString } from 'xml2js';
import { ParserOptions } from 'xml2js';

// Secure XML parser configuration
const secureParserOptions: ParserOptions = {
  explicitArray: false,
  mergeAttrs: true,
  explicitRoot: true,
  // Disable external entities
  explicitCharkey: false,
  trim: true,
  // Security options
  xmldec: {
    version: '1.0',
    encoding: 'UTF-8',
    standalone: false,
  },
  // Disable DOCTYPE processing
  ignoreAttrs: false,
  // Prevent XXE
  async: false,
};

// Additional XXE prevention
function sanitizeXml(xml: string): string {
  // Remove DOCTYPE declarations
  xml = xml.replace(/<!DOCTYPE[^>]*>/gi, '');
  
  // Remove external entity references
  xml = xml.replace(/<!ENTITY[^>]*>/gi, '');
  
  // Remove processing instructions that might be dangerous
  xml = xml.replace(/<\?[^>]*\?>/g, '');
  
  return xml;
}

export async function parseXmlSafely(xml: string): Promise<any> {
  // Sanitize XML first
  const sanitized = sanitizeXml(xml);
  
  return new Promise((resolve, reject) => {
    parseString(sanitized, secureParserOptions, (err, result) => {
      if (err) {
        reject(new Error(`XML parsing failed: ${err.message}`));
      } else {
        resolve(result);
      }
    });
  });
}

// Usage
import { parseXmlSafely } from '../utils/xmlParser';

try {
  const parsed = await parseXmlSafely(xmlString);
  // Process parsed XML
} catch (error) {
  // Handle error
}
```

### Issue 24: Insecure Direct Object References (IDOR)

**Location**: API endpoints accessing user resources

**Security Risk**: 
- Users can access other users' resources
- Missing authorization checks
- Predictable resource IDs

**Recommended Fix**:

```typescript
// File: src/middleware/authorization.ts
import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger';

/**
 * Verify user owns the resource they're accessing
 */
export const verifyOwnership = (resourceModel: any, resourceIdParam: string = 'id') => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const user = (req as any).user;
      if (!user) {
        return res.status(401).json({
          success: false,
          message: 'Authentication required',
        });
      }
      
      const resourceId = req.params[resourceIdParam];
      if (!resourceId) {
        return res.status(400).json({
          success: false,
          message: 'Resource ID required',
        });
      }
      
      // Find resource
      const resource = await resourceModel.findById(resourceId);
      if (!resource) {
        return res.status(404).json({
          success: false,
          message: 'Resource not found',
        });
      }
      
      // Check ownership
      const ownerId = resource.userId || resource.user || resource.owner;
      if (ownerId.toString() !== user.userId.toString()) {
        logger.warn('Unauthorized resource access attempt', {
          userId: user.userId,
          resourceId,
          resourceType: resourceModel.modelName,
          ownerId,
        });
        
        return res.status(403).json({
          success: false,
          message: 'Access denied. You do not have permission to access this resource.',
        });
      }
      
      // Attach resource to request
      (req as any).resource = resource;
      next();
    } catch (error: any) {
      logger.error('Ownership verification error', { error: error.message });
      res.status(500).json({
        success: false,
        message: 'Internal server error',
      });
    }
  };
};

/**
 * Verify user has required role
 */
export const requireRole = (...roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const user = (req as any).user;
    
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }
    
    const userRoles = user.roles || [];
    const hasRole = roles.some(role => userRoles.includes(role));
    
    if (!hasRole) {
      logger.warn('Insufficient permissions', {
        userId: user.userId,
        requiredRoles: roles,
        userRoles,
      });
      
      return res.status(403).json({
        success: false,
        message: 'Insufficient permissions',
      });
    }
    
    next();
  };
};

// Usage
import { verifyOwnership, requireRole } from '../middleware/authorization';
import Item from '../models/Item';

// Protect route with ownership check
router.get('/items/:id',
  authenticateJWT,
  verifyOwnership(Item),
  async (req, res) => {
    const item = (req as any).resource;
    res.json({ success: true, data: item });
  }
);

// Protect route with role check
router.delete('/items/:id',
  authenticateJWT,
  requireRole('admin', 'moderator'),
  verifyOwnership(Item),
  async (req, res) => {
    // Delete item
  }
);
```

### Issue 25: Insecure Deserialization

**Location**: Code that deserializes user input

**Security Risk**: 
- Remote code execution
- Object injection attacks
- Data tampering

**Recommended Fix**:

```typescript
// File: src/utils/safeDeserialization.ts
import { parse } from 'json5';

// Whitelist of allowed classes/types for deserialization
const ALLOWED_TYPES = [
  'string',
  'number',
  'boolean',
  'object',
  'array',
];

/**
 * Safely deserialize JSON data
 */
export function safeDeserialize<T>(json: string): T {
  try {
    // Parse JSON
    const parsed = JSON.parse(json);
    
    // Validate structure
    validateStructure(parsed);
    
    return parsed as T;
  } catch (error: any) {
    throw new Error(`Deserialization failed: ${error.message}`);
  }
}

/**
 * Validate object structure to prevent prototype pollution
 */
function validateStructure(obj: any, depth: number = 0): void {
  if (depth > 10) {
    throw new Error('Maximum nesting depth exceeded');
  }
  
  if (obj === null || obj === undefined) {
    return;
  }
  
  const type = typeof obj;
  
  if (!ALLOWED_TYPES.includes(type)) {
    throw new Error(`Invalid type: ${type}`);
  }
  
  // Check for prototype pollution
  if (type === 'object' && !Array.isArray(obj)) {
    // Reject __proto__ and constructor
    if ('__proto__' in obj || 'constructor' in obj) {
      throw new Error('Prototype pollution detected');
    }
    
    // Validate all properties
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        // Validate key
        if (key.startsWith('__') || key === 'constructor' || key === 'prototype') {
          throw new Error(`Invalid property name: ${key}`);
        }
        
        // Recursively validate value
        validateStructure(obj[key], depth + 1);
      }
    }
  } else if (Array.isArray(obj)) {
    // Validate array elements
    for (const item of obj) {
      validateStructure(item, depth + 1);
    }
  }
}

// Usage
import { safeDeserialize } from '../utils/safeDeserialization';

try {
  const data = safeDeserialize<MyType>(jsonString);
  // Use data safely
} catch (error) {
  // Handle deserialization error
}
```

### Issue 26: Server-Side Request Forgery (SSRF)

**Location**: Code that makes HTTP requests based on user input

**Security Risk**: 
- SSRF attacks
- Internal network access
- Information disclosure

**Recommended Fix**:

```typescript
// File: src/utils/secureHttpClient.ts
import axios, { AxiosRequestConfig } from 'axios';
import { URL } from 'url';

// Blocked IP ranges (internal networks)
const BLOCKED_IP_RANGES = [
  '127.0.0.0/8',      // localhost
  '10.0.0.0/8',       // private
  '172.16.0.0/12',    // private
  '192.168.0.0/16',   // private
  '169.254.0.0/16',   // link-local
  '::1',               // IPv6 localhost
  'fc00::/7',         // IPv6 private
];

// Allowed domains (whitelist approach)
const ALLOWED_DOMAINS = [
  'api.openai.com',
  'api.deepinfra.com',
  // Add other trusted domains
];

/**
 * Check if IP is in blocked range
 */
function isBlockedIP(ip: string): boolean {
  // Implement IP range checking logic
  // For simplicity, checking common patterns
  if (ip.startsWith('127.') || 
      ip.startsWith('10.') || 
      ip.startsWith('192.168.') ||
      ip.startsWith('172.16.') ||
      ip.startsWith('172.17.') ||
      ip.startsWith('172.18.') ||
      ip.startsWith('172.19.') ||
      ip.startsWith('172.20.') ||
      ip.startsWith('172.21.') ||
      ip.startsWith('172.22.') ||
      ip.startsWith('172.23.') ||
      ip.startsWith('172.24.') ||
      ip.startsWith('172.25.') ||
      ip.startsWith('172.26.') ||
      ip.startsWith('172.27.') ||
      ip.startsWith('172.28.') ||
      ip.startsWith('172.29.') ||
      ip.startsWith('172.30.') ||
      ip.startsWith('172.31.') ||
      ip === 'localhost' ||
      ip === '::1') {
    return true;
  }
  return false;
}

/**
 * Validate URL for SSRF prevention
 */
export function validateUrl(url: string): { valid: boolean; error?: string } {
  try {
    const parsed = new URL(url);
    
    // Only allow HTTP and HTTPS
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return { valid: false, error: 'Only HTTP and HTTPS protocols are allowed' };
    }
    
    // Check if domain is in whitelist
    if (ALLOWED_DOMAINS.length > 0 && !ALLOWED_DOMAINS.includes(parsed.hostname)) {
      return { valid: false, error: 'Domain not in whitelist' };
    }
    
    // Resolve hostname to IP and check
    // Note: In production, use DNS lookup
    const hostname = parsed.hostname;
    if (isBlockedIP(hostname)) {
      return { valid: false, error: 'Blocked IP range' };
    }
    
    return { valid: true };
  } catch (error: any) {
    return { valid: false, error: `Invalid URL: ${error.message}` };
  }
}

/**
 * Make secure HTTP request
 */
export async function secureHttpRequest(
  url: string,
  config: AxiosRequestConfig = {}
): Promise<any> {
  // Validate URL
  const validation = validateUrl(url);
  if (!validation.valid) {
    throw new Error(`URL validation failed: ${validation.error}`);
  }
  
  // Configure request
  const requestConfig: AxiosRequestConfig = {
    ...config,
    url,
    timeout: config.timeout || 10000, // 10 second timeout
    maxRedirects: 5,
    validateStatus: (status) => status < 500, // Don't throw on 4xx
    // Prevent following redirects to internal networks
    maxContentLength: 10 * 1024 * 1024, // 10MB max
  };
  
  try {
    const response = await axios(requestConfig);
    return response.data;
  } catch (error: any) {
    if (error.response) {
      throw new Error(`HTTP ${error.response.status}: ${error.response.statusText}`);
    } else if (error.request) {
      throw new Error('Request failed: no response received');
    } else {
      throw new Error(`Request error: ${error.message}`);
    }
  }
}

// Usage
import { secureHttpRequest } from '../utils/secureHttpClient';

try {
  const data = await secureHttpRequest('https://api.example.com/data');
  // Process data
} catch (error) {
  // Handle error
}
```

### Issue 27: Missing HTTPS Enforcement

**Location**: Server configuration

**Security Risk**: 
- Data transmitted in plaintext
- Man-in-the-middle attacks
- Credential theft

**Recommended Fix**:

```typescript
// File: src/middleware/httpsEnforcement.ts
import { Request, Response, NextFunction } from 'express';

/**
 * Enforce HTTPS in production
 */
export const enforceHttps = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (process.env.NODE_ENV === 'production') {
    // Check if request is over HTTPS
    const isHttps = 
      req.secure || // Express trust proxy
      req.headers['x-forwarded-proto'] === 'https' ||
      req.protocol === 'https';
    
    if (!isHttps) {
      // Redirect to HTTPS
      const httpsUrl = `https://${req.get('host')}${req.originalUrl}`;
      return res.redirect(301, httpsUrl);
    }
  }
  
  next();
};

// Apply in server.ts
import { enforceHttps } from './middleware/httpsEnforcement';

// Apply before other middleware
app.use(enforceHttps);
```

### Issue 28: Weak Cryptography

**Location**: Code using cryptographic functions

**Security Risk**: 
- Weak encryption algorithms
- Insecure random number generation
- Weak hashing algorithms

**Recommended Fix**:

```typescript
// File: src/utils/cryptography.ts
import crypto from 'crypto';

/**
 * Generate cryptographically secure random string
 */
export function generateSecureRandom(length: number = 32): string {
  return crypto.randomBytes(length).toString('hex');
}

/**
 * Hash password securely using bcrypt
 */
import bcrypt from 'bcrypt';

export async function hashPassword(password: string): Promise<string> {
  const saltRounds = 12; // High cost factor
  return await bcrypt.hash(password, saltRounds);
}

export async function verifyPassword(
  password: string,
  hash: string
): Promise<boolean> {
  return await bcrypt.compare(password, hash);
}

/**
 * Encrypt data using AES-256-GCM
 */
export function encryptData(
  data: string,
  key: string
): { encrypted: string; iv: string; tag: string } {
  const algorithm = 'aes-256-gcm';
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(algorithm, Buffer.from(key, 'hex'), iv);
  
  let encrypted = cipher.update(data, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  const tag = cipher.getAuthTag();
  
  return {
    encrypted,
    iv: iv.toString('hex'),
    tag: tag.toString('hex'),
  };
}

/**
 * Decrypt data using AES-256-GCM
 */
export function decryptData(
  encrypted: string,
  key: string,
  iv: string,
  tag: string
): string {
  const algorithm = 'aes-256-gcm';
  const decipher = crypto.createDecipheriv(
    algorithm,
    Buffer.from(key, 'hex'),
    Buffer.from(iv, 'hex')
  );
  
  decipher.setAuthTag(Buffer.from(tag, 'hex'));
  
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}

/**
 * Generate secure token
 */
export function generateSecureToken(length: number = 32): string {
  return crypto.randomBytes(length).toString('base64url');
}
```

### Issue 29: Missing Security Testing

**Location**: Test suite

**Security Risk**: 
- Security vulnerabilities not caught
- No automated security testing
- Manual testing gaps

**Recommended Fix**:

```typescript
// File: tests/security/security.test.ts (expanded)
import request from 'supertest';
import app from '../../src/server';

describe('Security Test Suite', () => {
  describe('Authentication Security', () => {
    it('should reject weak JWT secrets', () => {
      // Test implementation
    });
    
    it('should enforce token expiration', async () => {
      // Test implementation
    });
    
    it('should prevent token reuse after logout', async () => {
      // Test implementation
    });
  });
  
  describe('Input Validation Security', () => {
    it('should prevent SQL injection', async () => {
      const payloads = [
        "'; DROP TABLE users; --",
        "' OR '1'='1",
        "'; EXEC xp_cmdshell('dir'); --",
      ];
      
      for (const payload of payloads) {
        const response = await request(app)
          .post('/api/users')
          .send({ name: payload });
        
        expect(response.status).not.toBe(200);
      }
    });
    
    it('should prevent XSS attacks', async () => {
      const payloads = [
        '<script>alert("XSS")</script>',
        '<img src=x onerror=alert("XSS")>',
        'javascript:alert("XSS")',
      ];
      
      for (const payload of payloads) {
        const response = await request(app)
          .post('/api/users')
          .send({ name: payload });
        
        // Check response doesn't contain unencoded payload
        expect(response.body.data?.name).not.toContain('<script>');
      }
    });
    
    it('should prevent command injection', async () => {
      const payloads = [
        '; ls -la',
        '| cat /etc/passwd',
        '& rm -rf /',
      ];
      
      for (const payload of payloads) {
        const response = await request(app)
          .post('/api/execute')
          .send({ command: payload });
        
        expect(response.status).toBe(400);
      }
    });
  });
  
  describe('Authorization Security', () => {
    it('should prevent IDOR attacks', async () => {
      // Create user A and user B
      // Try to access user B's resource as user A
      // Should be denied
    });
    
    it('should enforce role-based access control', async () => {
      // Test that users can only access resources they have permission for
    });
  });
  
  describe('Rate Limiting Security', () => {
    it('should enforce rate limits', async () => {
      // Make requests exceeding rate limit
      // Verify 429 response
    });
  });
  
  describe('CORS Security', () => {
    it('should reject unauthorized origins', async () => {
      const response = await request(app)
        .get('/api/users')
        .set('Origin', 'https://evil.com');
      
      expect(response.status).toBe(403);
    });
  });
});
```

### Issue 30: Security Headers Validation

**Location**: Response headers

**Security Risk**: 
- Missing security headers
- Incorrect header values
- Headers not applied consistently

**Recommended Fix**:

```typescript
// File: tests/security/headers.test.ts
import request from 'supertest';
import app from '../../src/server';

describe('Security Headers', () => {
  it('should include all required security headers', async () => {
    const response = await request(app).get('/api/health');
    
    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['x-frame-options']).toBe('DENY');
    expect(response.headers['x-xss-protection']).toBe('1; mode=block');
    expect(response.headers['strict-transport-security']).toContain('max-age');
    expect(response.headers['content-security-policy']).toBeDefined();
  });
  
  it('should not expose server information', async () => {
    const response = await request(app).get('/api/health');
    
    expect(response.headers['x-powered-by']).toBeUndefined();
    expect(response.headers['server']).toBeUndefined();
  });
});
```

---

## Security Code Review Checklist

### Authentication and Authorization
- [ ] JWT secrets are validated and meet minimum length requirements
- [ ] Token expiration is properly enforced
- [ ] Token revocation is implemented
- [ ] Password hashing uses bcrypt with appropriate cost factor
- [ ] Multi-factor authentication is implemented for sensitive operations
- [ ] Session management is secure
- [ ] Authorization checks are performed on all protected resources
- [ ] Role-based access control is properly implemented

### Input Validation
- [ ] All user input is validated
- [ ] Input length limits are enforced
- [ ] Input type validation is performed
- [ ] SQL injection prevention is implemented
- [ ] XSS prevention is implemented
- [ ] Command injection prevention is implemented
- [ ] Path traversal prevention is implemented
- [ ] File upload validation is implemented

### Secrets Management
- [ ] No hardcoded secrets in code
- [ ] Secrets are stored securely
- [ ] Secrets are rotated regularly
- [ ] Default passwords are not used
- [ ] Secrets are not logged
- [ ] Environment variables are validated

### Error Handling
- [ ] Stack traces are not exposed in production
- [ ] Error messages don't reveal system internals
- [ ] Database errors are sanitized
- [ ] Generic error messages for users
- [ ] Detailed errors logged server-side only

### Security Headers
- [ ] Content-Security-Policy is set
- [ ] X-Frame-Options is set
- [ ] X-Content-Type-Options is set
- [ ] Strict-Transport-Security is set
- [ ] X-XSS-Protection is set
- [ ] Referrer-Policy is set

### Network Security
- [ ] HTTPS is enforced in production
- [ ] CORS is properly configured
- [ ] Rate limiting is implemented
- [ ] Request size limits are enforced
- [ ] Timeouts are configured

### Database Security
- [ ] Parameterized queries are used
- [ ] Database connections use SSL in production
- [ ] Database credentials are secure
- [ ] Connection pooling is configured
- [ ] Database errors are handled securely

### Logging and Monitoring
- [ ] Sensitive data is not logged
- [ ] Security events are logged
- [ ] Failed authentication attempts are logged
- [ ] Unusual activity is detected and logged
- [ ] Logs are stored securely

---

## Continuous Security Improvement

### Regular Security Activities

**Weekly**:
- Review security logs
- Check for new vulnerabilities in dependencies
- Review failed authentication attempts
- Monitor rate limit violations

**Monthly**:
- Security code review
- Dependency updates
- Security configuration review
- Penetration testing (if applicable)

**Quarterly**:
- Comprehensive security audit
- Threat modeling update
- Security training
- Incident response drill

### Security Metrics to Track

1. **Vulnerability Metrics**:
   - Number of critical vulnerabilities
   - Time to fix vulnerabilities
   - Dependency vulnerability count

2. **Authentication Metrics**:
   - Failed login attempts
   - Account lockouts
   - Token revocation rate

3. **Authorization Metrics**:
   - Unauthorized access attempts
   - IDOR attempts blocked
   - Permission denied events

4. **Input Validation Metrics**:
   - Injection attempts blocked
   - XSS attempts blocked
   - Invalid input rejections

5. **Rate Limiting Metrics**:
   - Rate limit violations
   - DDoS attempts blocked
   - API abuse incidents

---

## Conclusion

This comprehensive code security enhancement document provides actionable recommendations for improving the security posture of the Deepiri platform. All issues should be addressed according to priority, with critical security vulnerabilities resolved immediately.

**Key Takeaways**:

1. **Authentication**: Always validate secrets, enforce token expiration, implement revocation
2. **Input Validation**: Never trust user input, validate and sanitize everything
3. **Secrets Management**: Never hardcode secrets, use secure storage, validate on startup
4. **Error Handling**: Don't expose internal details, log securely, provide generic messages
5. **Security Headers**: Implement all recommended headers, enforce HTTPS
6. **Rate Limiting**: Protect all endpoints, differentiate by user type
7. **Authorization**: Always verify ownership and permissions
8. **Testing**: Implement comprehensive security testing
9. **Monitoring**: Track security metrics, log security events
10. **Continuous Improvement**: Regular reviews, updates, and training

**Next Steps**:

1. Prioritize issues based on risk assessment
2. Create implementation tickets
3. Implement fixes following recommended patterns
4. Test all security enhancements
5. Conduct security code review
6. Update documentation
7. Schedule regular security audits

**Maintenance**:

- Review this document quarterly
- Update as new security issues are discovered
- Keep security dependencies updated
- Regular security testing
- Threat modeling updates
- Security training for developers

---

END OF DOCUMENT

