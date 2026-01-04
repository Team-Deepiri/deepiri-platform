# API Request/Response Logging and Audit Trails

**Version:** 1.0  
**Date:** 2025-01-27  
**Status:** Comprehensive Implementation Guide  
**Target:** All API Services in Deepiri Platform

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Understanding the Fundamentals](#understanding-the-fundamentals)
3. [Why Logging Matters](#why-logging-matters)
4. [Basic Logging Implementation](#basic-logging-implementation)
5. [Intermediate Logging Patterns](#intermediate-logging-patterns)
6. [Advanced Audit Trail Systems](#advanced-audit-trail-systems)
7. [Production-Ready Implementation](#production-ready-implementation)
8. [Testing and Validation](#testing-and-validation)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices and Patterns](#best-practices-and-patterns)

---

## Prerequisites

Before diving into API logging and audit trails, you need to understand several fundamental concepts. This section will build your foundation from the ground up.

### 1. HTTP Request-Response Cycle

#### What Happens When a Request is Made?

When a client makes an API request, a complex sequence of events occurs:

```
Client Request
    ↓
Network Layer (TCP/IP)
    ↓
Server Receives Request
    ↓
Middleware Stack (Authentication, Validation, Logging)
    ↓
Route Handler (Your Business Logic)
    ↓
Database/External Service Calls
    ↓
Response Generation
    ↓
Middleware Stack (Logging, Headers)
    ↓
Network Layer
    ↓
Client Receives Response
```

**Key Points:**
- Every request has a **start time** and **end time**
- Requests can **succeed** (200-299), **redirect** (300-399), **fail client-side** (400-499), or **fail server-side** (500-599)
- Each request has **metadata**: method (GET, POST, etc.), path, headers, query parameters, body
- Responses have **status codes**, **headers**, and **body content**

#### Why This Matters for Logging

To log effectively, you need to capture:
- **When** the request started and ended
- **Who** made the request (user, IP, API key)
- **What** was requested (method, path, parameters)
- **How long** it took (duration/latency)
- **What happened** (success, error, status code)
- **What data** was sent/received (request body, response body)

### 2. Middleware Concepts

#### What is Middleware?

Middleware is code that runs **between** receiving a request and sending a response. Think of it as a series of checkpoints:

```
Request → Middleware 1 → Middleware 2 → Middleware 3 → Handler → Response
```

#### Express.js Middleware Pattern

```typescript
// Basic middleware structure
app.use((req, res, next) => {
  // 1. Do something BEFORE the handler
  console.log('Request received');
  
  // 2. Call next() to continue to next middleware/handler
  next();
  
  // 3. Code here runs AFTER the handler (if response hasn't been sent)
});
```

#### Capturing Response Data

The challenge: responses are sent **after** the handler completes. Solution: use response event listeners:

```typescript
app.use((req, res, next) => {
  const start = Date.now();
  
  // Capture response when it's finished
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} - ${res.statusCode} - ${duration}ms`);
  });
  
  next();
});
```

### 3. Request Identification

#### Why Request IDs Matter

In a distributed system, a single user action might trigger multiple API calls across different services. You need a way to **trace** all related requests.

```
User Action: "Create Order"
    ↓
Frontend → API Gateway (request-id: abc-123)
    ↓
API Gateway → Auth Service (request-id: abc-123)
    ↓
API Gateway → Order Service (request-id: abc-123)
    ↓
Order Service → Payment Service (request-id: abc-123)
```

All these logs share the same `request-id`, making it easy to trace the entire flow.

#### Generating Request IDs

```typescript
import { v4 as uuidv4 } from 'uuid';

// Generate unique ID for each request
const requestId = uuidv4();

// Add to request object for later use
req.requestId = requestId;

// Add to response headers so client can reference it
res.setHeader('X-Request-ID', requestId);
```

### 4. Structured Logging

#### What is Structured Logging?

Instead of plain text logs like:
```
"User john logged in at 2025-01-27 10:30:45"
```

Structured logging uses JSON:
```json
{
  "timestamp": "2025-01-27T10:30:45.123Z",
  "level": "info",
  "event": "user_login",
  "userId": "user-123",
  "ip": "192.168.1.1",
  "requestId": "abc-123"
}
```

**Benefits:**
- Easy to parse and search
- Can filter by specific fields
- Works well with log aggregation tools (ELK, Splunk, Datadog)
- Machine-readable format

### 5. Log Levels

Understanding when to use each log level:

- **DEBUG**: Detailed information for diagnosing problems (request/response bodies, intermediate values)
- **INFO**: General informational messages (request received, successful operation)
- **WARN**: Warning messages (deprecated API usage, slow requests)
- **ERROR**: Error conditions (exceptions, failed operations)
- **FATAL**: Critical errors that might cause the application to abort

**Rule of thumb:**
- Production: INFO, WARN, ERROR, FATAL
- Development: All levels including DEBUG

---

## Understanding the Fundamentals

### What is API Logging?

API logging is the practice of **recording information** about every API request and response. This includes:
- Request metadata (method, URL, headers, body)
- Response metadata (status code, headers, body)
- Timing information (duration, latency)
- User context (who made the request)
- Error information (if something went wrong)

### What is an Audit Trail?

An audit trail is a **secure, tamper-proof record** of all actions performed in a system. Unlike regular logs, audit trails:
- Are **immutable** (cannot be modified after creation)
- Include **who** did **what**, **when**, and **where**
- Are stored **separately** from application logs
- Are **retained** for compliance and security purposes
- Can be used for **forensic analysis**

### Key Differences: Logging vs Audit Trails

| Aspect | Logging | Audit Trail |
|--------|---------|-------------|
| Purpose | Debugging, monitoring, performance | Compliance, security, forensics |
| Retention | Short-term (days/weeks) | Long-term (years) |
| Mutability | Can be rotated/deleted | Immutable |
| Detail Level | Verbose (includes bodies) | Focused (actions only) |
| Storage | Application logs | Separate audit database |
| Access | Developers, DevOps | Security, Compliance teams |

### The Request-Response Lifecycle

Understanding the complete lifecycle helps you know **where** to add logging:

```
┌─────────────────────────────────────────────────────────────┐
│                    REQUEST LIFECYCLE                         │
└─────────────────────────────────────────────────────────────┘

1. REQUEST ARRIVES
   ├─ Generate Request ID
   ├─ Log: Request received
   └─ Extract: IP, User-Agent, Headers

2. AUTHENTICATION
   ├─ Validate token/credentials
   ├─ Log: Auth attempt (success/failure)
   └─ Extract: User ID, Permissions

3. AUTHORIZATION
   ├─ Check permissions
   ├─ Log: Permission check
   └─ Extract: Allowed/Denied

4. VALIDATION
   ├─ Validate request body/params
   ├─ Log: Validation errors (if any)
   └─ Extract: Validated data

5. BUSINESS LOGIC
   ├─ Execute handler
   ├─ Log: Business events
   └─ Extract: Operation results

6. DATABASE/EXTERNAL CALLS
   ├─ Query database
   ├─ Call external APIs
   ├─ Log: External calls
   └─ Extract: Query results

7. RESPONSE GENERATION
   ├─ Format response
   ├─ Set status code
   └─ Add headers

8. RESPONSE SENT
   ├─ Log: Response sent
   ├─ Calculate duration
   └─ Record: Status, Size, Duration

9. AUDIT TRAIL
   └─ Record: Action to audit database
```

---

## Why Logging Matters

### 1. Debugging Production Issues

**Scenario:** User reports "I can't create an order"

**Without Logging:**
- No way to see what happened
- Can't reproduce the issue
- Takes hours/days to debug

**With Logging:**
```json
{
  "requestId": "req-123",
  "timestamp": "2025-01-27T10:30:45Z",
  "method": "POST",
  "path": "/api/orders",
  "userId": "user-456",
  "status": 500,
  "error": "Database connection timeout",
  "duration": 30000
}
```

You can immediately see:
- What endpoint was called
- Who called it
- What error occurred
- How long it took

### 2. Performance Monitoring

Track slow requests to identify bottlenecks:

```json
{
  "path": "/api/reports/generate",
  "duration": 5000,
  "status": 200
}
```

If many requests to this endpoint take >5 seconds, you know it needs optimization.

### 3. Security and Compliance

**Security:**
- Detect suspicious patterns (brute force, unusual access)
- Track failed authentication attempts
- Monitor for injection attacks

**Compliance:**
- GDPR: Track data access
- HIPAA: Audit patient data access
- SOX: Financial transaction logging

### 4. Business Analytics

Understand how your API is used:
- Most popular endpoints
- Peak usage times
- User behavior patterns
- Error rates by endpoint

### 5. Troubleshooting User Issues

When a user reports a problem, you can:
1. Search logs by their user ID
2. Find all their recent requests
3. Identify the exact request that failed
4. See the error message and stack trace

---

## Basic Logging Implementation

### Level 1: Console Logging (Beginner)

**Goal:** Get basic request/response information to console

#### Step 1: Simple Request Logger

```typescript
// Basic middleware
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});
```

**What this does:**
- Logs every request method and path
- Runs before your route handlers

**Output:**
```
GET /api/users
POST /api/orders
```

#### Step 2: Add Response Status

```typescript
app.use((req, res, next) => {
  const start = Date.now();
  
  // Log when response finishes
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} - ${res.statusCode} - ${duration}ms`);
  });
  
  next();
});
```

**Output:**
```
GET /api/users - 200 - 45ms
POST /api/orders - 201 - 120ms
GET /api/users/999 - 404 - 12ms
```

#### Step 3: Add Request ID

```typescript
import { v4 as uuidv4 } from 'uuid';

app.use((req, res, next) => {
  // Generate unique ID
  const requestId = uuidv4();
  
  // Store in request for use in handlers
  (req as any).requestId = requestId;
  
  // Add to response header
  res.setHeader('X-Request-ID', requestId);
  
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[${requestId}] ${req.method} ${req.path} - ${res.statusCode} - ${duration}ms`);
  });
  
  next();
});
```

**Output:**
```
[abc-123-def] GET /api/users - 200 - 45ms
[xyz-789-ghi] POST /api/orders - 201 - 120ms
```

**Why Request IDs Matter:**
- Each request has a unique identifier
- You can trace a request across multiple services
- Makes debugging much easier

### Level 2: File Logging (Intermediate Beginner)

**Goal:** Save logs to files instead of just console

#### Step 1: Install Winston

```bash
npm install winston
```

#### Step 2: Create Logger Utility

```typescript
// src/utils/logger.ts
import winston from 'winston';
import path from 'path';
import fs from 'fs';

// Create logs directory if it doesn't exist
const logsDir = path.join(process.cwd(), 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Create Winston logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    // Write all logs to combined.log
    new winston.transports.File({
      filename: path.join(logsDir, 'combined.log')
    }),
    // Write errors to error.log
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error'
    })
  ]
});

// In development, also log to console
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple()
  }));
}

export default logger;
```

#### Step 3: Use Logger in Middleware

```typescript
import logger from './utils/logger';

app.use((req, res, next) => {
  const requestId = uuidv4();
  (req as any).requestId = requestId;
  res.setHeader('X-Request-ID', requestId);
  
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    
    logger.info('API Request', {
      requestId,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userAgent: req.get('user-agent')
    });
  });
  
  next();
});
```

**What this gives you:**
- Logs saved to `logs/combined.log`
- Errors saved to `logs/error.log`
- Structured JSON format
- Timestamps on every log entry

**Log File Example:**
```json
{"level":"info","message":"API Request","requestId":"abc-123","method":"GET","path":"/api/users","statusCode":200,"duration":"45ms","ip":"192.168.1.1","userAgent":"Mozilla/5.0...","timestamp":"2025-01-27T10:30:45.123Z"}
```

### Level 3: Structured Logging with Context (Advanced Beginner)

**Goal:** Add user context and request/response bodies

#### Enhanced Logger Middleware

```typescript
app.use((req, res, next) => {
  const requestId = uuidv4();
  (req as any).requestId = requestId;
  res.setHeader('X-Request-ID', requestId);
  
  const start = Date.now();
  
  // Log request (be careful with sensitive data)
  logger.info('Request received', {
    requestId,
    method: req.method,
    path: req.path,
    query: req.query,
    ip: req.ip,
    userAgent: req.get('user-agent'),
    // Only log body for non-sensitive endpoints
    body: req.path.includes('/auth') ? '[REDACTED]' : req.body
  });
  
  // Capture original response methods
  const originalSend = res.send;
  const originalJson = res.json;
  
  let responseBody: any = null;
  
  // Override res.json to capture response
  res.json = function(body: any) {
    responseBody = body;
    return originalJson.call(this, body);
  };
  
  // Override res.send to capture response
  res.send = function(body: any) {
    responseBody = body;
    return originalSend.call(this, body);
  };
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    
    // Determine log level based on status code
    const logLevel = res.statusCode >= 500 ? 'error' : 
                     res.statusCode >= 400 ? 'warn' : 'info';
    
    logger.log(logLevel, 'Request completed', {
      requestId,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      // Only log response body for errors (helps debugging)
      responseBody: res.statusCode >= 400 ? responseBody : undefined,
      userId: (req as any).user?.id // If you have auth middleware
    });
  });
  
  next();
});
```

**Key Features:**
- Logs request and response
- Redacts sensitive data (auth endpoints)
- Different log levels for different status codes
- Includes user ID if authenticated

---

## Intermediate Logging Patterns

### Pattern 1: Request ID Propagation

**Problem:** In microservices, a single user action triggers multiple API calls. You need to trace them all.

**Solution:** Propagate request ID across services.

#### Frontend → API Gateway

```typescript
// Frontend: Generate or use existing request ID
const requestId = generateRequestId(); // or get from previous response

fetch('/api/users', {
  headers: {
    'X-Request-ID': requestId
  }
});
```

#### API Gateway → Backend Services

```typescript
// API Gateway middleware
app.use((req, res, next) => {
  // Use existing request ID or generate new one
  const requestId = req.get('X-Request-ID') || uuidv4();
  (req as any).requestId = requestId;
  res.setHeader('X-Request-ID', requestId);
  next();
});

// When proxying to backend services
app.use('/api/*', (req, res, next) => {
  // Forward request ID to backend
  req.headers['x-request-id'] = (req as any).requestId;
  next();
}, proxyMiddleware);
```

#### Backend Service Receives Request ID

```typescript
// Backend service middleware
app.use((req, res, next) => {
  // Extract request ID from header or generate new
  const requestId = req.get('X-Request-ID') || uuidv4();
  (req as any).requestId = requestId;
  res.setHeader('X-Request-ID', requestId);
  next();
});
```

**Result:** All logs across all services share the same request ID.

### Pattern 2: Correlation IDs

**Problem:** A single user action might trigger multiple independent operations. You need to group them.

**Solution:** Use correlation IDs.

```
User Action: "Place Order"
├─ Correlation ID: corr-order-123
│
├─ Request 1: Create Order (request-id: req-1, correlation-id: corr-order-123)
├─ Request 2: Process Payment (request-id: req-2, correlation-id: corr-order-123)
├─ Request 3: Send Notification (request-id: req-3, correlation-id: corr-order-123)
└─ Request 4: Update Inventory (request-id: req-4, correlation-id: corr-order-123)
```

**Implementation:**

```typescript
// Generate correlation ID for business operations
const correlationId = `order-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

// Store in request context
(req as any).correlationId = correlationId;

// Log with both request ID and correlation ID
logger.info('Order created', {
  requestId: req.requestId,
  correlationId: req.correlationId,
  orderId: order.id
});
```

### Pattern 3: Logging Levels by Environment

**Problem:** You want detailed logs in development but minimal logs in production.

**Solution:** Environment-based logging configuration.

```typescript
// src/utils/logger.ts
const logLevel = process.env.LOG_LEVEL || 
  (process.env.NODE_ENV === 'production' ? 'info' : 'debug');

const logger = winston.createLogger({
  level: logLevel,
  // ... rest of config
});

// In middleware, conditionally log based on level
if (logger.level === 'debug') {
  logger.debug('Full request details', {
    headers: req.headers,
    body: req.body,
    query: req.query
  });
} else {
  logger.info('Request summary', {
    method: req.method,
    path: req.path
  });
}
```

### Pattern 4: Sensitive Data Redaction

**Problem:** Logs might contain passwords, tokens, credit cards. You need to redact them.

**Solution:** Create a redaction utility.

```typescript
// src/utils/redaction.ts
const SENSITIVE_FIELDS = [
  'password',
  'token',
  'apiKey',
  'secret',
  'creditCard',
  'ssn',
  'cvv'
];

export function redactSensitiveData(obj: any): any {
  if (!obj || typeof obj !== 'object') {
    return obj;
  }
  
  if (Array.isArray(obj)) {
    return obj.map(item => redactSensitiveData(item));
  }
  
  const redacted: any = {};
  
  for (const [key, value] of Object.entries(obj)) {
    const lowerKey = key.toLowerCase();
    
    // Check if field name contains sensitive keywords
    if (SENSITIVE_FIELDS.some(field => lowerKey.includes(field))) {
      redacted[key] = '[REDACTED]';
    } else if (typeof value === 'object' && value !== null) {
      redacted[key] = redactSensitiveData(value);
    } else {
      redacted[key] = value;
    }
  }
  
  return redacted;
}

// Use in logging
logger.info('Request received', {
  ...redactSensitiveData({
    body: req.body,
    headers: req.headers
  })
});
```

### Pattern 5: Performance Logging

**Goal:** Track slow requests and identify bottlenecks.

```typescript
app.use((req, res, next) => {
  const start = Date.now();
  const startCpu = process.cpuUsage();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const cpuUsage = process.cpuUsage(startCpu);
    
    // Log performance metrics
    logger.info('Request performance', {
      requestId: req.requestId,
      method: req.method,
      path: req.path,
      duration: `${duration}ms`,
      cpuUser: `${cpuUsage.user / 1000}ms`,
      cpuSystem: `${cpuUsage.system / 1000}ms`,
      memoryUsage: process.memoryUsage()
    });
    
    // Warn on slow requests
    if (duration > 1000) {
      logger.warn('Slow request detected', {
        requestId: req.requestId,
        path: req.path,
        duration: `${duration}ms`
      });
    }
  });
  
  next();
});
```

### Pattern 6: Error Context Logging

**Goal:** Capture full context when errors occur.

```typescript
// Error handling middleware
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  const requestId = (req as any).requestId || 'unknown';
  
  // Log full error context
  logger.error('Request error', {
    requestId,
    error: {
      message: err.message,
      stack: err.stack,
      name: err.name
    },
    request: {
      method: req.method,
      path: req.path,
      query: req.query,
      body: redactSensitiveData(req.body),
      headers: redactSensitiveData(req.headers)
    },
    user: {
      id: (req as any).user?.id,
      ip: req.ip
    }
  });
  
  // Send error response
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    requestId
  });
});
```

---

## Advanced Audit Trail Systems

### What Makes an Audit Trail Different?

Audit trails are **immutable, secure records** of actions. Key requirements:

1. **Immutable**: Cannot be modified or deleted
2. **Tamper-proof**: Cryptographic signatures or hashes
3. **Complete**: Records who, what, when, where, why
4. **Retained**: Stored for compliance periods (years)
5. **Searchable**: Can query by user, action, time range
6. **Separate**: Stored separately from application logs

### Architecture: Audit Trail System

```
┌─────────────────────────────────────────────────────────────┐
│                    AUDIT TRAIL ARCHITECTURE                  │
└─────────────────────────────────────────────────────────────┘

Application
    ↓
Audit Middleware (captures action)
    ↓
Audit Service (validates, enriches)
    ↓
Audit Database (immutable storage)
    ↓
Audit Query API (compliance reporting)
```

### Implementation: Audit Trail Database Schema

#### PostgreSQL Schema

```sql
-- Audit trail table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Who
    user_id VARCHAR(255),
    user_email VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    
    -- What
    action VARCHAR(255) NOT NULL,  -- e.g., "user.created", "order.deleted"
    resource_type VARCHAR(100),     -- e.g., "user", "order"
    resource_id VARCHAR(255),       -- ID of the affected resource
    
    -- Where
    service_name VARCHAR(100) NOT NULL,
    endpoint VARCHAR(500),
    method VARCHAR(10),
    
    -- Context
    request_id VARCHAR(255),
    correlation_id VARCHAR(255),
    
    -- Changes (for update/delete operations)
    old_values JSONB,
    new_values JSONB,
    
    -- Result
    status_code INTEGER,
    success BOOLEAN NOT NULL,
    error_message TEXT,
    
    -- Security
    checksum VARCHAR(64),  -- SHA-256 hash of record for tamper detection
    
    -- Metadata
    metadata JSONB
);

-- Indexes for common queries
CREATE INDEX idx_audit_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_request_id ON audit_logs(request_id);

-- Partition by month for performance (optional, for high-volume systems)
-- CREATE TABLE audit_logs_2025_01 PARTITION OF audit_logs
--     FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
```

### Implementation: Audit Service

#### Step 1: Audit Model

```typescript
// src/models/AuditLog.ts
import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';
import crypto from 'crypto';

interface AuditLogAttributes {
  id: string;
  timestamp: Date;
  userId?: string;
  userEmail?: string;
  ipAddress?: string;
  userAgent?: string;
  action: string;
  resourceType?: string;
  resourceId?: string;
  serviceName: string;
  endpoint?: string;
  method?: string;
  requestId?: string;
  correlationId?: string;
  oldValues?: any;
  newValues?: any;
  statusCode?: number;
  success: boolean;
  errorMessage?: string;
  checksum: string;
  metadata?: any;
}

class AuditLog extends Model<AuditLogAttributes> implements AuditLogAttributes {
  public id!: string;
  public timestamp!: Date;
  public userId?: string;
  public userEmail?: string;
  public ipAddress?: string;
  public userAgent?: string;
  public action!: string;
  public resourceType?: string;
  public resourceId?: string;
  public serviceName!: string;
  public endpoint?: string;
  public method?: string;
  public requestId?: string;
  public correlationId?: string;
  public oldValues?: any;
  public newValues?: any;
  public statusCode?: number;
  public success!: boolean;
  public errorMessage?: string;
  public checksum!: string;
  public metadata?: any;

  // Generate checksum for tamper detection
  public static generateChecksum(data: Partial<AuditLogAttributes>): string {
    const dataString = JSON.stringify(data);
    return crypto.createHash('sha256').update(dataString).digest('hex');
  }
}

AuditLog.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true
    },
    timestamp: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    },
    userId: DataTypes.STRING,
    userEmail: DataTypes.STRING,
    ipAddress: DataTypes.STRING,
    userAgent: DataTypes.TEXT,
    action: {
      type: DataTypes.STRING,
      allowNull: false
    },
    resourceType: DataTypes.STRING,
    resourceId: DataTypes.STRING,
    serviceName: {
      type: DataTypes.STRING,
      allowNull: false
    },
    endpoint: DataTypes.STRING,
    method: DataTypes.STRING,
    requestId: DataTypes.STRING,
    correlationId: DataTypes.STRING,
    oldValues: DataTypes.JSONB,
    newValues: DataTypes.JSONB,
    statusCode: DataTypes.INTEGER,
    success: {
      type: DataTypes.BOOLEAN,
      allowNull: false
    },
    errorMessage: DataTypes.TEXT,
    checksum: {
      type: DataTypes.STRING,
      allowNull: false
    },
    metadata: DataTypes.JSONB
  },
  {
    sequelize,
    tableName: 'audit_logs',
    timestamps: false, // We use our own timestamp field
    hooks: {
      beforeCreate: (auditLog: AuditLog) => {
        // Generate checksum before saving
        const dataToHash = {
          timestamp: auditLog.timestamp,
          userId: auditLog.userId,
          action: auditLog.action,
          resourceId: auditLog.resourceId,
          oldValues: auditLog.oldValues,
          newValues: auditLog.newValues
        };
        auditLog.checksum = AuditLog.generateChecksum(dataToHash);
      }
    }
  }
);

export default AuditLog;
```

#### Step 2: Audit Service

```typescript
// src/services/auditService.ts
import AuditLog from '../models/AuditLog';
import { Request } from 'express';

export interface AuditEvent {
  action: string;
  resourceType?: string;
  resourceId?: string;
  oldValues?: any;
  newValues?: any;
  success: boolean;
  errorMessage?: string;
  metadata?: any;
}

export class AuditService {
  private serviceName: string;

  constructor(serviceName: string) {
    this.serviceName = serviceName;
  }

  async logEvent(
    req: Request,
    event: AuditEvent
  ): Promise<void> {
    try {
      const user = (req as any).user;
      
      await AuditLog.create({
        userId: user?.id || user?.userId,
        userEmail: user?.email,
        ipAddress: req.ip || req.socket.remoteAddress,
        userAgent: req.get('user-agent'),
        action: event.action,
        resourceType: event.resourceType,
        resourceId: event.resourceId,
        serviceName: this.serviceName,
        endpoint: req.path,
        method: req.method,
        requestId: (req as any).requestId,
        correlationId: (req as any).correlationId,
        oldValues: event.oldValues,
        newValues: event.newValues,
        statusCode: (req as any).statusCode,
        success: event.success,
        errorMessage: event.errorMessage,
        metadata: event.metadata
      });
    } catch (error) {
      // Log audit failure but don't break the request
      console.error('Failed to write audit log:', error);
      // In production, you might want to send this to a dead letter queue
    }
  }

  // Helper methods for common actions
  async logCreate(req: Request, resourceType: string, resourceId: string, newValues: any): Promise<void> {
    await this.logEvent(req, {
      action: `${resourceType}.created`,
      resourceType,
      resourceId,
      newValues,
      success: true
    });
  }

  async logUpdate(req: Request, resourceType: string, resourceId: string, oldValues: any, newValues: any): Promise<void> {
    await this.logEvent(req, {
      action: `${resourceType}.updated`,
      resourceType,
      resourceId,
      oldValues,
      newValues,
      success: true
    });
  }

  async logDelete(req: Request, resourceType: string, resourceId: string, oldValues: any): Promise<void> {
    await this.logEvent(req, {
      action: `${resourceType}.deleted`,
      resourceType,
      resourceId,
      oldValues,
      success: true
    });
  }

  async logAccess(req: Request, resourceType: string, resourceId: string): Promise<void> {
    await this.logEvent(req, {
      action: `${resourceType}.accessed`,
      resourceType,
      resourceId,
      success: true
    });
  }
}

// Export singleton instance
export const auditService = new AuditService(process.env.SERVICE_NAME || 'deepiri-core-api');
```

#### Step 3: Audit Middleware

```typescript
// src/middleware/auditMiddleware.ts
import { Request, Response, NextFunction } from 'express';
import { auditService } from '../services/auditService';

// Middleware to automatically audit certain actions
export function auditMiddleware(actionPattern: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    // Store original response methods
    const originalSend = res.send;
    const originalJson = res.json;
    
    let responseBody: any = null;
    
    res.json = function(body: any) {
      responseBody = body;
      return originalJson.call(this, body);
    };
    
    res.send = function(body: any) {
      responseBody = body;
      return originalSend.call(this, body);
    };
    
    // Audit after response is sent
    res.on('finish', async () => {
      // Only audit successful operations (2xx status codes)
      if (res.statusCode >= 200 && res.statusCode < 300) {
        const resourceId = extractResourceId(req, responseBody);
        const resourceType = extractResourceType(req.path);
        
        // Determine action from HTTP method
        let action: string;
        switch (req.method) {
          case 'POST':
            action = `${resourceType}.created`;
            break;
          case 'PUT':
          case 'PATCH':
            action = `${resourceType}.updated`;
            break;
          case 'DELETE':
            action = `${resourceType}.deleted`;
            break;
          case 'GET':
            action = `${resourceType}.accessed`;
            break;
          default:
            action = `${resourceType}.${req.method.toLowerCase()}`;
        }
        
        await auditService.logEvent(req, {
          action,
          resourceType,
          resourceId,
          newValues: req.method === 'POST' || req.method === 'PUT' ? req.body : undefined,
          oldValues: req.method === 'PUT' || req.method === 'PATCH' ? (req as any).oldValues : undefined,
          success: true
        });
      } else {
        // Log failed operations
        await auditService.logEvent(req, {
          action: actionPattern,
          success: false,
          errorMessage: responseBody?.message || `HTTP ${res.statusCode}`
        });
      }
    });
    
    next();
  };
}

// Helper to extract resource ID from request/response
function extractResourceId(req: Request, responseBody: any): string | undefined {
  // Try from URL params
  if (req.params.id) return req.params.id;
  
  // Try from response body
  if (responseBody?.id) return String(responseBody.id);
  if (responseBody?.data?.id) return String(responseBody.data.id);
  
  return undefined;
}

// Helper to extract resource type from path
function extractResourceType(path: string): string {
  // Extract from /api/users/123 -> "users"
  const match = path.match(/\/api\/([^\/]+)/);
  return match ? match[1].replace(/s$/, '') : 'unknown';
}
```

#### Step 4: Using Audit Middleware

```typescript
// In your route handlers
import { auditMiddleware } from '../middleware/auditMiddleware';
import { auditService } from '../services/auditService';

// Automatic auditing for CRUD operations
app.post('/api/users', auditMiddleware('user.created'), async (req, res) => {
  const user = await createUser(req.body);
  res.json(user);
});

// Manual auditing for complex operations
app.post('/api/orders/:orderId/cancel', async (req, res) => {
  try {
    const order = await cancelOrder(req.params.orderId);
    
    // Manual audit log
    await auditService.logEvent(req, {
      action: 'order.cancelled',
      resourceType: 'order',
      resourceId: req.params.orderId,
      oldValues: order,
      newValues: { ...order, status: 'cancelled' },
      success: true,
      metadata: { reason: req.body.reason }
    });
    
    res.json(order);
  } catch (error) {
    await auditService.logEvent(req, {
      action: 'order.cancel_failed',
      resourceType: 'order',
      resourceId: req.params.orderId,
      success: false,
      errorMessage: error.message
    });
    throw error;
  }
});
```

### Advanced: Tamper Detection

To detect if audit logs have been tampered with:

```typescript
// src/services/auditVerification.ts
import AuditLog from '../models/AuditLog';
import crypto from 'crypto';

export class AuditVerificationService {
  async verifyLog(auditLogId: string): Promise<boolean> {
    const log = await AuditLog.findByPk(auditLogId);
    if (!log) return false;
    
    // Recalculate checksum
    const dataToHash = {
      timestamp: log.timestamp,
      userId: log.userId,
      action: log.action,
      resourceId: log.resourceId,
      oldValues: log.oldValues,
      newValues: log.newValues
    };
    
    const calculatedChecksum = AuditLog.generateChecksum(dataToHash);
    
    // Compare with stored checksum
    return calculatedChecksum === log.checksum;
  }

  async verifyLogRange(startDate: Date, endDate: Date): Promise<{
    total: number;
    verified: number;
    tampered: string[];
  }> {
    const logs = await AuditLog.findAll({
      where: {
        timestamp: {
          [Op.between]: [startDate, endDate]
        }
      }
    });
    
    const tampered: string[] = [];
    let verified = 0;
    
    for (const log of logs) {
      const isValid = await this.verifyLog(log.id);
      if (isValid) {
        verified++;
      } else {
        tampered.push(log.id);
      }
    }
    
    return {
      total: logs.length,
      verified,
      tampered
    };
  }
}
```

---

## Production-Ready Implementation

### Complete Logging Middleware for Express/TypeScript

```typescript
// src/middleware/requestLogger.ts
import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';
import logger from '../utils/logger';
import { redactSensitiveData } from '../utils/redaction';

export interface RequestContext {
  requestId: string;
  correlationId?: string;
  userId?: string;
  startTime: number;
}

declare global {
  namespace Express {
    interface Request {
      requestId: string;
      correlationId?: string;
      context: RequestContext;
    }
  }
}

export function requestLoggerMiddleware() {
  return (req: Request, res: Response, next: NextFunction) => {
    // Generate or extract request ID
    const requestId = req.get('X-Request-ID') || uuidv4();
    req.requestId = requestId;
    res.setHeader('X-Request-ID', requestId);
    
    // Extract or generate correlation ID
    const correlationId = req.get('X-Correlation-ID') || 
      (req.path.startsWith('/api/') ? `corr-${Date.now()}-${Math.random().toString(36).substr(2, 9)}` : undefined);
    if (correlationId) {
      req.correlationId = correlationId;
      res.setHeader('X-Correlation-ID', correlationId);
    }
    
    // Store context
    const startTime = Date.now();
    req.context = {
      requestId,
      correlationId,
      userId: (req as any).user?.id,
      startTime
    };
    
    // Log incoming request
    logger.info('Request received', {
      requestId,
      correlationId,
      method: req.method,
      path: req.path,
      query: redactSensitiveData(req.query),
      ip: req.ip || req.socket.remoteAddress,
      userAgent: req.get('user-agent'),
      userId: req.context.userId,
      // Conditionally log body (skip for large uploads, sensitive endpoints)
      body: shouldLogBody(req) ? redactSensitiveData(req.body) : '[SKIPPED]'
    });
    
    // Capture response
    const originalSend = res.send;
    const originalJson = res.json;
    let responseBody: any = null;
    let responseSize = 0;
    
    res.json = function(body: any) {
      responseBody = body;
      responseSize = JSON.stringify(body).length;
      return originalJson.call(this, body);
    };
    
    res.send = function(body: any) {
      responseBody = body;
      responseSize = typeof body === 'string' ? body.length : JSON.stringify(body).length;
      return originalSend.call(this, body);
    };
    
    // Log response when finished
    res.on('finish', () => {
      const duration = Date.now() - startTime;
      const logData: any = {
        requestId,
        correlationId,
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        duration: `${duration}ms`,
        responseSize: `${(responseSize / 1024).toFixed(2)}KB`,
        userId: req.context.userId
      };
      
      // Determine log level
      let logLevel: string;
      if (res.statusCode >= 500) {
        logLevel = 'error';
        logData.error = true;
        // Always log response body for errors
        logData.responseBody = responseBody;
      } else if (res.statusCode >= 400) {
        logLevel = 'warn';
        logData.warning = true;
        logData.responseBody = responseBody;
      } else {
        logLevel = 'info';
      }
      
      // Add performance warning for slow requests
      if (duration > 1000) {
        logData.performanceWarning = true;
        logData.slowRequest = true;
      }
      
      logger.log(logLevel, 'Request completed', logData);
      
      // Emit metrics (if you have a metrics system)
      if (global.metrics) {
        global.metrics.increment('http.requests.total', {
          method: req.method,
          path: req.path,
          status: res.statusCode.toString()
        });
        
        global.metrics.histogram('http.request.duration', duration, {
          method: req.method,
          path: req.path
        });
      }
    });
    
    next();
  };
}

function shouldLogBody(req: Request): boolean {
  // Don't log body for file uploads
  if (req.get('content-type')?.includes('multipart/form-data')) {
    return false;
  }
  
  // Don't log body for very large requests
  const contentLength = parseInt(req.get('content-length') || '0');
  if (contentLength > 100000) { // 100KB
    return false;
  }
  
  // Always log for errors (handled separately)
  return true;
}
```

### Complete Logging for FastAPI/Python

```python
# app/middleware/logging_middleware.py
import time
import uuid
import json
from typing import Callable
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from app.logging_config import get_logger
from app.utils.redaction import redact_sensitive_data

logger = get_logger(__name__)

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Generate or extract request ID
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        
        # Extract correlation ID
        correlation_id = request.headers.get("X-Correlation-ID")
        
        # Store in request state
        request.state.request_id = request_id
        if correlation_id:
            request.state.correlation_id = correlation_id
        
        start_time = time.time()
        
        # Log incoming request
        logger.info(
            "Request received",
            request_id=request_id,
            correlation_id=correlation_id,
            method=request.method,
            path=request.url.path,
            query_params=dict(request.query_params),
            ip=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent"),
        )
        
        # Process request
        try:
            response = await call_next(request)
        except Exception as e:
            # Log error
            duration = (time.time() - start_time) * 1000
            logger.error(
                "Request error",
                request_id=request_id,
                correlation_id=correlation_id,
                method=request.method,
                path=request.url.path,
                duration=f"{duration:.2f}ms",
                error=str(e),
                error_type=type(e).__name__
            )
            raise
        
        # Calculate duration
        duration = (time.time() - start_time) * 1000
        
        # Add request ID to response headers
        response.headers["X-Request-ID"] = request_id
        if correlation_id:
            response.headers["X-Correlation-ID"] = correlation_id
        
        # Determine log level
        status_code = response.status_code
        if status_code >= 500:
            log_level = "error"
        elif status_code >= 400:
            log_level = "warn"
        else:
            log_level = "info"
        
        # Log response
        log_data = {
            "request_id": request_id,
            "correlation_id": correlation_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": status_code,
            "duration": f"{duration:.2f}ms"
        }
        
        # Add performance warning
        if duration > 1000:
            log_data["performance_warning"] = True
            log_data["slow_request"] = True
        
        logger.log(log_level, "Request completed", **log_data)
        
        return response
```

### Log Aggregation Setup

For production, you'll want to aggregate logs from all services. Common solutions:

#### Option 1: ELK Stack (Elasticsearch, Logstash, Kibana)

```yaml
# docker-compose.yml
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
    ports:
      - "9200:9200"
  
  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch
  
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
```

```ruby
# logstash.conf
input {
  file {
    path => "/var/log/app/*.log"
    codec => "json"
  }
}

filter {
  json {
    source => "message"
  }
  
  date {
    match => [ "timestamp", "ISO8601" ]
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "api-logs-%{+YYYY.MM.dd}"
  }
}
```

#### Option 2: Fluentd

```xml
<!-- fluentd.conf -->
<source>
  @type forward
  port 24224
</source>

<match api.**>
  @type elasticsearch
  host elasticsearch
  port 9200
  index_name api-logs
  type_name _doc
  <buffer>
    @type file
    path /var/log/fluentd-buffer
  </buffer>
</match>
```

#### Option 3: Cloud Services

- **AWS CloudWatch**: Native AWS logging
- **Google Cloud Logging**: GCP native
- **Azure Monitor**: Azure native
- **Datadog**: Third-party, feature-rich
- **Splunk**: Enterprise-grade

---

## Testing and Validation

### Unit Testing Logging Middleware

```typescript
// tests/middleware/requestLogger.test.ts
import { Request, Response, NextFunction } from 'express';
import { requestLoggerMiddleware } from '../../src/middleware/requestLogger';
import logger from '../../src/utils/logger';

jest.mock('../../src/utils/logger');

describe('RequestLoggerMiddleware', () => {
  let req: Partial<Request>;
  let res: Partial<Response>;
  let next: NextFunction;

  beforeEach(() => {
    req = {
      method: 'GET',
      path: '/api/users',
      get: jest.fn(),
      ip: '192.168.1.1',
      query: {},
      body: {}
    };
    
    res = {
      setHeader: jest.fn(),
      on: jest.fn((event, callback) => {
        if (event === 'finish') {
          // Simulate response finish
          setTimeout(() => callback(), 10);
        }
      }),
      statusCode: 200,
      send: jest.fn(),
      json: jest.fn()
    };
    
    next = jest.fn();
  });

  it('should generate request ID if not present', () => {
    (req.get as jest.Mock).mockReturnValue(null);
    
    const middleware = requestLoggerMiddleware();
    middleware(req as Request, res as Response, next);
    
    expect(req.requestId).toBeDefined();
    expect(res.setHeader).toHaveBeenCalledWith('X-Request-ID', req.requestId);
  });

  it('should use existing request ID from header', () => {
    const existingId = 'existing-request-id';
    (req.get as jest.Mock).mockImplementation((header) => {
      if (header === 'X-Request-ID') return existingId;
      return null;
    });
    
    const middleware = requestLoggerMiddleware();
    middleware(req as Request, res as Response, next);
    
    expect(req.requestId).toBe(existingId);
  });

  it('should log request and response', (done) => {
    const middleware = requestLoggerMiddleware();
    middleware(req as Request, res as Response, next);
    
    // Wait for response finish event
    setTimeout(() => {
      expect(logger.info).toHaveBeenCalled();
      expect(next).toHaveBeenCalled();
      done();
    }, 20);
  });
});
```

### Integration Testing

```typescript
// tests/integration/logging.integration.test.ts
import request from 'supertest';
import app from '../../src/app';

describe('API Logging Integration', () => {
  it('should include request ID in response headers', async () => {
    const response = await request(app)
      .get('/api/users')
      .expect(200);
    
    expect(response.headers['x-request-id']).toBeDefined();
  });

  it('should propagate request ID across services', async () => {
    const requestId = 'test-request-id';
    
    const response = await request(app)
      .get('/api/users')
      .set('X-Request-ID', requestId)
      .expect(200);
    
    expect(response.headers['x-request-id']).toBe(requestId);
  });

  it('should log slow requests with warning', async () => {
    // Mock a slow endpoint
    jest.spyOn(global, 'setTimeout').mockImplementation((fn) => {
      return setTimeout(fn, 1500) as any;
    });
    
    const response = await request(app)
      .get('/api/slow-endpoint')
      .expect(200);
    
    // Check logs for performance warning
    // (Implementation depends on your logging setup)
  });
});
```

### Validating Audit Trails

```typescript
// tests/services/auditService.test.ts
import { auditService } from '../../src/services/auditService';
import AuditLog from '../../src/models/AuditLog';

describe('AuditService', () => {
  it('should create audit log entry', async () => {
    const mockReq = {
      method: 'POST',
      path: '/api/users',
      ip: '192.168.1.1',
      get: jest.fn().mockReturnValue('Mozilla/5.0'),
      user: { id: 'user-123', email: 'test@example.com' },
      requestId: 'req-123'
    } as any;

    await auditService.logCreate(mockReq, 'user', 'user-456', { name: 'Test User' });

    const auditLog = await AuditLog.findOne({
      where: { requestId: 'req-123' }
    });

    expect(auditLog).toBeDefined();
    expect(auditLog?.action).toBe('user.created');
    expect(auditLog?.userId).toBe('user-123');
    expect(auditLog?.resourceId).toBe('user-456');
  });

  it('should generate checksum for tamper detection', async () => {
    const mockReq = {
      method: 'POST',
      path: '/api/users',
      ip: '192.168.1.1',
      get: jest.fn(),
      requestId: 'req-123'
    } as any;

    await auditService.logCreate(mockReq, 'user', 'user-456', { name: 'Test' });

    const auditLog = await AuditLog.findOne({
      where: { requestId: 'req-123' }
    });

    expect(auditLog?.checksum).toBeDefined();
    
    // Verify checksum
    const verificationService = new AuditVerificationService();
    const isValid = await verificationService.verifyLog(auditLog!.id);
    expect(isValid).toBe(true);
  });
});
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Logs Not Appearing

**Symptoms:** No log files created, or logs not showing in console.

**Solutions:**
1. Check log directory permissions
2. Verify logger configuration
3. Check log level settings
4. Ensure middleware is registered before routes

```typescript
// Debug logging setup
console.log('Log directory:', logsDir);
console.log('Log level:', logger.level);
console.log('Transports:', logger.transports.length);
```

#### Issue 2: Missing Request IDs

**Symptoms:** Request IDs are undefined or not propagating.

**Solutions:**
1. Ensure middleware runs before route handlers
2. Check middleware order in app setup
3. Verify request ID header is being set

```typescript
// Debug middleware order
app.use((req, res, next) => {
  console.log('Middleware order check:', req.requestId);
  next();
});
```

#### Issue 3: Performance Impact

**Symptoms:** Logging slows down API responses.

**Solutions:**
1. Use asynchronous logging
2. Batch log writes
3. Use separate log writer process
4. Reduce log verbosity in production

```typescript
// Async logging with queue
import { Queue } from 'bull';

const logQueue = new Queue('logging', {
  redis: { host: 'localhost', port: 6379 }
});

// In middleware
res.on('finish', () => {
  logQueue.add('log-request', {
    requestId: req.requestId,
    // ... log data
  });
});
```

#### Issue 4: Log File Size Issues

**Symptoms:** Log files growing too large, disk space issues.

**Solutions:**
1. Implement log rotation
2. Set maximum file size
3. Archive old logs
4. Use log aggregation service

```typescript
// Winston with rotation
import winstonDailyRotateFile from 'winston-daily-rotate-file';

const transport = new winstonDailyRotateFile({
  filename: 'logs/application-%DATE%.log',
  datePattern: 'YYYY-MM-DD',
  maxSize: '20m',
  maxFiles: '14d',
  zippedArchive: true
});
```

#### Issue 5: Sensitive Data in Logs

**Symptoms:** Passwords, tokens appearing in logs.

**Solutions:**
1. Implement redaction utility
2. Review all log statements
3. Use environment-based logging
4. Regular security audits

```typescript
// Comprehensive redaction
const SENSITIVE_PATTERNS = [
  /password["\s]*[:=]["\s]*([^"}\s,]+)/gi,
  /token["\s]*[:=]["\s]*([^"}\s,]+)/gi,
  /api[_-]?key["\s]*[:=]["\s]*([^"}\s,]+)/gi
];

function redactString(str: string): string {
  let redacted = str;
  SENSITIVE_PATTERNS.forEach(pattern => {
    redacted = redacted.replace(pattern, (match, value) => {
      return match.replace(value, '[REDACTED]');
    });
  });
  return redacted;
}
```

---

## Best Practices and Patterns

### 1. Logging Best Practices

#### Do's

- **Do** use structured logging (JSON)
- **Do** include request IDs in all logs
- **Do** log at appropriate levels
- **Do** redact sensitive information
- **Do** log errors with full context
- **Do** use correlation IDs for related operations
- **Do** set up log rotation and retention policies
- **Do** monitor log volume and performance

#### Don'ts

- **Don't** log sensitive data (passwords, tokens, PII)
- **Don't** log excessively in production
- **Don't** use console.log in production
- **Don't** block request handling for logging
- **Don't** log binary data or large payloads
- **Don't** use inconsistent log formats
- **Don't** forget to include timestamps
- **Don't** log without request context

### 2. Audit Trail Best Practices

#### Security

- Store audit logs in a separate, secure database
- Implement access controls (only security/compliance teams)
- Use encryption at rest and in transit
- Implement tamper detection (checksums)
- Regular integrity checks
- Immutable storage (append-only)

#### Compliance

- Define retention periods based on regulations
- Ensure complete coverage of all critical operations
- Regular compliance audits
- Document audit log access
- Implement audit log query APIs for compliance reporting

#### Performance

- Use database partitioning for large volumes
- Index frequently queried fields
- Archive old logs to cold storage
- Use async writes (don't block requests)
- Batch writes when possible

### 3. Logging Patterns by Use Case

#### Pattern: Debugging Production Issues

```typescript
// Include full context for debugging
logger.error('Payment processing failed', {
  requestId: req.requestId,
  userId: req.user.id,
  orderId: order.id,
  paymentMethod: order.paymentMethod,
  amount: order.amount,
  error: error.message,
  stack: error.stack,
  requestBody: req.body,
  responseBody: responseBody
});
```

#### Pattern: Performance Monitoring

```typescript
// Track performance metrics
logger.info('Database query performance', {
  requestId: req.requestId,
  query: 'getUserOrders',
  duration: `${queryDuration}ms`,
  rowCount: results.length,
  slowQuery: queryDuration > 1000
});
```

#### Pattern: Security Monitoring

```typescript
// Log security events
logger.warn('Suspicious activity detected', {
  requestId: req.requestId,
  userId: req.user.id,
  ip: req.ip,
  event: 'multiple_failed_logins',
  attempts: failedLoginCount,
  timeWindow: '5 minutes'
});
```

#### Pattern: Business Analytics

```typescript
// Log business events
logger.info('Order created', {
  requestId: req.requestId,
  userId: req.user.id,
  orderId: order.id,
  amount: order.total,
  items: order.items.length,
  currency: order.currency,
  timestamp: new Date().toISOString()
});
```

### 4. Architecture Patterns

#### Pattern: Centralized Logging Service

```
All Services
    ↓
Log Aggregation (Fluentd/Logstash)
    ↓
Centralized Storage (Elasticsearch/S3)
    ↓
Query Interface (Kibana/CloudWatch)
```

#### Pattern: Distributed Tracing

```
Request → Service A (trace-id: abc)
    ↓
Service A → Service B (trace-id: abc, span-id: 1)
    ↓
Service B → Service C (trace-id: abc, span-id: 2)
    ↓
All logs include trace-id for correlation
```

#### Pattern: Audit Trail Service

```
Application Services
    ↓
Audit Middleware (captures events)
    ↓
Audit Service (validates, enriches)
    ↓
Audit Database (immutable, secure)
    ↓
Compliance API (read-only access)
```

### 5. Monitoring and Alerting

#### Key Metrics to Monitor

1. **Log Volume**: Total logs per minute/hour
2. **Error Rate**: Percentage of error logs
3. **Slow Requests**: Requests taking > threshold
4. **Missing Request IDs**: Requests without IDs
5. **Audit Log Failures**: Failed audit writes
6. **Log Storage**: Disk space usage

#### Alerting Rules

```yaml
# Example alerting configuration
alerts:
  - name: HighErrorRate
    condition: error_rate > 5%
    action: notify_team
    
  - name: SlowRequests
    condition: p95_latency > 2000ms
    action: notify_devops
    
  - name: AuditLogFailures
    condition: audit_failures > 10/hour
    action: notify_security
    
  - name: LogStorageFull
    condition: log_storage_usage > 90%
    action: notify_infrastructure
```

---

## Summary

This guide has taken you from basic console logging to advanced audit trail systems. You've learned:

1. **Fundamentals**: HTTP lifecycle, middleware, request IDs, structured logging
2. **Basic Implementation**: Console logging, file logging, structured logs
3. **Intermediate Patterns**: Request ID propagation, correlation IDs, sensitive data redaction
4. **Advanced Systems**: Immutable audit trails, tamper detection, compliance
5. **Production Ready**: Complete middleware implementations, log aggregation, monitoring

### Next Steps

1. **Start Simple**: Implement basic request/response logging in one service
2. **Add Request IDs**: Ensure all requests have unique identifiers
3. **Structured Logging**: Convert to JSON format
4. **Add Audit Trails**: For critical operations (user actions, data changes)
5. **Set Up Aggregation**: Centralize logs from all services
6. **Monitor and Alert**: Set up dashboards and alerts
7. **Iterate**: Refine based on your specific needs

### Key Takeaways

- **Logging is essential** for debugging, monitoring, and security
- **Request IDs** enable tracing requests across services
- **Structured logging** makes logs searchable and analyzable
- **Audit trails** are separate from logs and serve compliance needs
- **Performance matters** - don't let logging slow down your API
- **Security first** - always redact sensitive data
- **Start simple, evolve** - begin with basics and add complexity as needed

Remember: Good logging is an investment that pays off when you need to debug production issues, investigate security incidents, or demonstrate compliance.

---

## Appendix: Complete Code Examples

### Express/TypeScript Complete Implementation

See the production-ready implementation section for complete middleware code.

### FastAPI/Python Complete Implementation

See the production-ready implementation section for complete middleware code.

### Database Migrations

```sql
-- PostgreSQL migration for audit_logs table
-- Run this in your database migration system

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    user_id VARCHAR(255),
    user_email VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    action VARCHAR(255) NOT NULL,
    resource_type VARCHAR(100),
    resource_id VARCHAR(255),
    service_name VARCHAR(100) NOT NULL,
    endpoint VARCHAR(500),
    method VARCHAR(10),
    request_id VARCHAR(255),
    correlation_id VARCHAR(255),
    old_values JSONB,
    new_values JSONB,
    status_code INTEGER,
    success BOOLEAN NOT NULL,
    error_message TEXT,
    checksum VARCHAR(64) NOT NULL,
    metadata JSONB
);

CREATE INDEX idx_audit_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_request_id ON audit_logs(request_id);
CREATE INDEX idx_audit_correlation_id ON audit_logs(correlation_id);
CREATE INDEX idx_audit_service ON audit_logs(service_name, timestamp DESC);

-- Partition by month (optional, for high-volume systems)
-- CREATE TABLE audit_logs_2025_01 PARTITION OF audit_logs
--     FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
```

---

**End of Guide**

