# Rate Limiting and Request Throttling in API Gateway

**Version:** 1.0  
**Date:** 2025-01-27  
**Status:** Implementation Guide  
**Target:** API Gateway at `platform-services/backend/deepiri-api-gateway/`

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Warmup Exercises](#warmup-exercises)
3. [The Problem](#the-problem)
4. [The Solution](#the-solution)
5. [Step-by-Step Implementation](#step-by-step-implementation)
6. [Advanced Implementation](#advanced-implementation)
7. [Testing & Monitoring](#testing--monitoring)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before implementing rate limiting and request throttling, you need to understand several fundamental concepts. This section will break down everything you need to know, from basic to advanced.

### 1. HTTP Fundamentals

#### What is HTTP?
HTTP (HyperText Transfer Protocol) is the foundation of data communication on the web. Every time you visit a website, your browser sends HTTP requests, and the server responds with HTTP responses.

**Key Concepts:**
- **Request**: Client asks for something (GET, POST, PUT, DELETE, etc.)
- **Response**: Server answers with data and status codes (200 OK, 404 Not Found, 429 Too Many Requests)
- **Headers**: Metadata about the request/response (Content-Type, Authorization, etc.)
- **Status Codes**: 
  - `200`: Success
  - `401`: Unauthorized
  - `403`: Forbidden
  - `404`: Not Found
  - `429`: Too Many Requests (this is what we'll use!)
  - `500`: Server Error

#### Why This Matters
Rate limiting works by intercepting HTTP requests before they reach your application logic. Understanding HTTP helps you know where and how to implement rate limiting.

### 2. Express.js Middleware

#### What is Middleware?
Middleware are functions that execute during the request-response cycle. They can:
- Execute code
- Modify request/response objects
- End the request-response cycle
- Call the next middleware

**Basic Middleware Pattern:**
```typescript
app.use((req, res, next) => {
  // Do something with req/res
  console.log('Request received:', req.method, req.path);
  next(); // Pass control to next middleware
});
```

#### Middleware Execution Order
Express executes middleware in the order they're registered:

```typescript
app.use(middleware1);  // Runs first
app.use(middleware2);  // Runs second
app.use('/api', middleware3);  // Runs only for /api routes
```

#### Types of Middleware
1. **Application-level**: `app.use()` - runs for all routes
2. **Router-level**: `router.use()` - runs for specific router
3. **Error-handling**: `app.use((err, req, res, next) => {})` - handles errors
4. **Built-in**: `express.json()`, `express.static()`
5. **Third-party**: `cors`, `helmet`, `express-rate-limit`

### 3. Request Identification

To rate limit effectively, you need to identify who's making requests. Common identifiers:

#### IP Address
```typescript
const clientIP = req.ip || req.connection.remoteAddress;
```
- **Pros**: Works without authentication
- **Cons**: Multiple users behind same IP (NAT, corporate networks)

#### User ID (Authenticated Users)
```typescript
const userId = req.user?.id || req.user?.userId;
```
- **Pros**: More accurate per-user limits
- **Cons**: Requires authentication middleware to run first

#### API Key
```typescript
const apiKey = req.headers['x-api-key'];
```
- **Pros**: Good for API consumers
- **Cons**: Requires key management

#### Session ID
```typescript
const sessionId = req.session?.id;
```
- **Pros**: Works for authenticated sessions
- **Cons**: Requires session management

### 4. Rate Limiting Algorithms

Understanding different algorithms helps you choose the right one for your use case.

#### Fixed Window Counter
**How it works:**
- Divide time into fixed windows (e.g., 1 minute)
- Count requests in current window
- Reset counter at window boundary

**Example:**
```
Window 1 (0:00-0:59): [req, req, req] = 3 requests
Window 2 (1:00-1:59): [req, req] = 2 requests
```

**Pros:**
- Simple to implement
- Low memory usage
- Fast lookups

**Cons:**
- Burst problem: 100 requests at 0:59 and 100 at 1:00 = 200 in 2 seconds
- Boundary issues

**Use case:** Simple rate limiting where bursts are acceptable

#### Sliding Window Log
**How it works:**
- Keep a log of all request timestamps
- Remove timestamps outside the window
- Count remaining timestamps

**Example:**
```
Current time: 1:30
Window: 1 minute
Log: [1:29:45, 1:29:50, 1:30:10, 1:30:15]
Count: 4 requests
```

**Pros:**
- Accurate rate limiting
- No burst problem
- Smooth distribution

**Cons:**
- High memory usage (stores all timestamps)
- Slower (needs to clean old entries)

**Use case:** When you need precise rate limiting

#### Sliding Window Counter
**How it works:**
- Divide window into sub-windows
- Count requests in each sub-window
- Estimate current count using weighted average

**Example:**
```
1-minute window divided into 6 sub-windows (10 seconds each)
Sub-window 1 (0:00-0:09): 10 requests
Sub-window 2 (0:10-0:19): 15 requests
...
Current estimate: weighted average of recent sub-windows
```

**Pros:**
- Good balance of accuracy and memory
- Handles bursts better than fixed window
- More memory efficient than sliding log

**Cons:**
- Slightly less accurate than sliding log
- More complex implementation

**Use case:** Production systems needing good balance

#### Token Bucket
**How it works:**
- Bucket has capacity (max tokens)
- Tokens refill at constant rate
- Request consumes token(s)
- Request allowed if tokens available

**Example:**
```
Capacity: 100 tokens
Refill rate: 10 tokens/second
Current tokens: 50

Request arrives → consumes 1 token → 49 tokens remain
After 1 second → 59 tokens (50 + 10 - 1)
```

**Pros:**
- Allows bursts (if tokens available)
- Smooth rate limiting
- Natural throttling

**Cons:**
- More complex to implement
- Need to track refill timestamps

**Use case:** When you want to allow bursts but control average rate

#### Leaky Bucket
**How it works:**
- Bucket has capacity
- Requests enter bucket
- Requests processed at constant rate (leak)
- Request rejected if bucket full

**Example:**
```
Capacity: 100 requests
Leak rate: 10 requests/second
Current: 50 requests

Request arrives → bucket has space → add to bucket (51 requests)
Process 10 requests/second → bucket decreases
```

**Pros:**
- Smooths out traffic spikes
- Constant output rate
- Good for downstream protection

**Cons:**
- Requests may wait in queue
- More complex implementation

**Use case:** When you need to protect downstream services

### 5. Data Storage for Rate Limiting

Rate limiting needs to track request counts. Where to store this data?

#### In-Memory (JavaScript Map/Object)
```typescript
const requestCounts = new Map<string, number>();
```
- **Pros**: Fast, no external dependencies
- **Cons**: Lost on restart, doesn't work in cluster mode
- **Use case**: Development, single-instance apps

#### Redis (Recommended for Production)
```typescript
await redis.incr(`ratelimit:${key}`);
await redis.expire(`ratelimit:${key}`, windowSeconds);
```
- **Pros**: Persistent, works across instances, built-in expiration
- **Cons**: Requires Redis server, network latency
- **Use case**: Production, multi-instance deployments

#### Database (PostgreSQL, MongoDB)
```typescript
await db.ratelimits.upsert({ key, count: { $inc: 1 } });
```
- **Pros**: Persistent, queryable
- **Cons**: Slower than Redis, more overhead
- **Use case**: When you need complex queries or analytics

### 6. Express Request/Response Objects

Understanding Express objects is crucial for implementing rate limiting.

#### Request Object (`req`)
```typescript
req.method        // 'GET', 'POST', etc.
req.path          // '/api/users'
req.url           // '/api/users?page=1'
req.originalUrl   // Full original URL
req.ip            // Client IP address
req.headers       // All headers
req.get('header') // Get specific header
req.body          // Parsed request body
req.query         // Query parameters
req.params        // Route parameters
req.user          // Authenticated user (if auth middleware added)
```

#### Response Object (`res`)
```typescript
res.status(429)                    // Set status code
res.json({ error: 'Too many' })    // Send JSON response
res.set('X-RateLimit-Limit', '100') // Set header
res.header('Retry-After', '60')     // Set header (alternative)
res.send()                          // Send response
```

### 7. TypeScript Basics

Since our API Gateway uses TypeScript, you need to understand:

#### Type Annotations
```typescript
const count: number = 0;
const message: string = 'Hello';
const isActive: boolean = true;
```

#### Interfaces
```typescript
interface RateLimitConfig {
  windowMs: number;
  max: number;
  keyGenerator?: (req: Request) => string;
}
```

#### Type Guards
```typescript
function isRateLimitConfig(obj: any): obj is RateLimitConfig {
  return obj && typeof obj.windowMs === 'number';
}
```

### 8. Async/Await and Promises

Rate limiting often involves async operations (Redis, database calls).

#### Promises
```typescript
redis.get(key)
  .then(value => {
    // Handle value
  })
  .catch(error => {
    // Handle error
  });
```

#### Async/Await
```typescript
async function checkRateLimit(key: string) {
  try {
    const value = await redis.get(key);
    return parseInt(value || '0');
  } catch (error) {
    // Handle error
  }
}
```

### 9. Error Handling

Rate limiting can fail (Redis down, network issues). You need graceful degradation.

#### Try-Catch
```typescript
try {
  const allowed = await checkRateLimit(key);
  if (!allowed) {
    return res.status(429).json({ error: 'Rate limited' });
  }
} catch (error) {
  // Fail open: allow request if rate limiting fails
  logger.error('Rate limit check failed', error);
  // Continue with request
}
```

#### Fail-Open vs Fail-Closed
- **Fail-Open**: If rate limiting fails, allow request (better UX, security risk)
- **Fail-Closed**: If rate limiting fails, reject request (better security, worse UX)

### 10. HTTP Headers for Rate Limiting

Standard headers to include in responses:

```typescript
res.set({
  'X-RateLimit-Limit': '100',        // Max requests allowed
  'X-RateLimit-Remaining': '95',     // Requests remaining
  'X-RateLimit-Reset': '1640995200', // Unix timestamp when limit resets
  'Retry-After': '60'                // Seconds to wait before retrying
});
```

---

## Warmup Exercises

Before implementing rate limiting, complete these exercises to solidify your understanding.

### Exercise 1: Basic Middleware

**Goal**: Create a middleware that logs all requests.

**Task**: 
1. Create a file `src/middleware/logger.ts`
2. Export a function that logs: method, path, IP, timestamp
3. Use it in `server.ts` before other middleware

**Solution:**
```typescript
// src/middleware/logger.ts
import { Request, Response, NextFunction } from 'express';

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} from ${req.ip}`);
  next();
}

// In server.ts
import { requestLogger } from './middleware/logger';
app.use(requestLogger);
```

### Exercise 2: IP-Based Counter

**Goal**: Count requests per IP address using in-memory storage.

**Task**:
1. Create a Map to store IP → count
2. Create middleware that increments count for each IP
3. Log the count in response header `X-Request-Count`

**Solution:**
```typescript
// src/middleware/ipCounter.ts
import { Request, Response, NextFunction } from 'express';

const ipCounts = new Map<string, number>();

export function ipCounter(req: Request, res: Response, next: NextFunction) {
  const ip = req.ip || 'unknown';
  const count = (ipCounts.get(ip) || 0) + 1;
  ipCounts.set(ip, count);
  
  res.set('X-Request-Count', count.toString());
  next();
}
```

### Exercise 3: Simple Rate Limiter (Fixed Window)

**Goal**: Implement a basic fixed-window rate limiter.

**Task**:
1. Allow 10 requests per minute per IP
2. Return 429 if limit exceeded
3. Include `X-RateLimit-Remaining` header

**Solution:**
```typescript
// src/middleware/simpleRateLimit.ts
import { Request, Response, NextFunction } from 'express';

interface Window {
  count: number;
  resetAt: number;
}

const windows = new Map<string, Window>();
const WINDOW_MS = 60 * 1000; // 1 minute
const MAX_REQUESTS = 10;

export function simpleRateLimit(req: Request, res: Response, next: NextFunction) {
  const ip = req.ip || 'unknown';
  const now = Date.now();
  
  let window = windows.get(ip);
  
  // Reset window if expired
  if (!window || now > window.resetAt) {
    window = { count: 0, resetAt: now + WINDOW_MS };
    windows.set(ip, window);
  }
  
  // Check limit
  if (window.count >= MAX_REQUESTS) {
    res.status(429).json({
      error: 'Too many requests',
      retryAfter: Math.ceil((window.resetAt - now) / 1000)
    });
    return;
  }
  
  // Increment and allow
  window.count++;
  res.set('X-RateLimit-Remaining', (MAX_REQUESTS - window.count).toString());
  next();
}
```

### Exercise 4: Token Bucket Implementation

**Goal**: Implement a token bucket algorithm.

**Task**:
1. Create a TokenBucket class
2. Capacity: 100 tokens
3. Refill rate: 10 tokens/second
4. Middleware consumes 1 token per request

**Solution:**
```typescript
// src/middleware/tokenBucket.ts
class TokenBucket {
  private tokens: number;
  private capacity: number;
  private refillRate: number; // tokens per second
  private lastRefill: number;
  
  constructor(capacity: number, refillRate: number) {
    this.capacity = capacity;
    this.tokens = capacity;
    this.refillRate = refillRate;
    this.lastRefill = Date.now();
  }
  
  consume(tokens: number = 1): boolean {
    const now = Date.now();
    const elapsed = (now - this.lastRefill) / 1000; // seconds
    const refill = elapsed * this.refillRate;
    
    this.tokens = Math.min(this.capacity, this.tokens + refill);
    this.lastRefill = now;
    
    if (this.tokens >= tokens) {
      this.tokens -= tokens;
      return true;
    }
    return false;
  }
  
  getRemaining(): number {
    return Math.floor(this.tokens);
  }
}

const buckets = new Map<string, TokenBucket>();

export function tokenBucketRateLimit(req: Request, res: Response, next: NextFunction) {
  const ip = req.ip || 'unknown';
  
  if (!buckets.has(ip)) {
    buckets.set(ip, new TokenBucket(100, 10)); // 100 capacity, 10/sec refill
  }
  
  const bucket = buckets.get(ip)!;
  
  if (!bucket.consume(1)) {
    res.status(429).json({ error: 'Rate limit exceeded' });
    return;
  }
  
  res.set('X-RateLimit-Remaining', bucket.getRemaining().toString());
  next();
}
```

### Exercise 5: Redis Integration

**Goal**: Use Redis to store rate limit counters.

**Task**:
1. Install `ioredis` or `redis` package
2. Create Redis client
3. Implement rate limiting using Redis INCR and EXPIRE

**Solution:**
```typescript
// src/middleware/redisRateLimit.ts
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

export async function redisRateLimit(req: Request, res: Response, next: NextFunction) {
  const ip = req.ip || 'unknown';
  const key = `ratelimit:${ip}`;
  const windowSeconds = 60;
  const maxRequests = 100;
  
  try {
    // Increment counter
    const count = await redis.incr(key);
    
    // Set expiration on first request
    if (count === 1) {
      await redis.expire(key, windowSeconds);
    }
    
    // Check limit
    if (count > maxRequests) {
      const ttl = await redis.ttl(key);
      res.status(429).json({
        error: 'Too many requests',
        retryAfter: ttl
      });
      return;
    }
    
    // Set headers
    res.set({
      'X-RateLimit-Limit': maxRequests.toString(),
      'X-RateLimit-Remaining': Math.max(0, maxRequests - count).toString(),
      'X-RateLimit-Reset': (Date.now() + ttl * 1000).toString()
    });
    
    next();
  } catch (error) {
    // Fail open: allow request if Redis fails
    console.error('Redis rate limit error:', error);
    next();
  }
}
```

---

## The Problem

### Why Do We Need Rate Limiting?

Without rate limiting, your API is vulnerable to:

#### 1. **DDoS Attacks**
A malicious actor sends thousands of requests per second, overwhelming your server:
```
Attacker: 10,000 requests/second
Your server capacity: 100 requests/second
Result: Server crashes, legitimate users can't access API
```

#### 2. **Resource Exhaustion**
Even legitimate users can accidentally overload your system:
```
User's script has a bug → infinite loop → 1,000 requests/second
Result: Database connections exhausted, memory full, service down
```

#### 3. **API Abuse**
Users abuse your API to:
- Scrape all your data
- Perform brute-force attacks
- Bypass business logic (e.g., unlimited free tier usage)

#### 4. **Cost Explosion**
Each request costs money:
- Database queries
- External API calls
- Compute resources
- Bandwidth

Unlimited requests = unlimited costs

#### 5. **Fair Usage**
Rate limiting ensures fair resource distribution:
- One user shouldn't monopolize resources
- Free tier users get limited access
- Premium users get higher limits

### Real-World Scenarios

#### Scenario 1: Brute Force Attack
```
Attacker tries to guess passwords:
POST /api/auth/login
Body: { email: "user@example.com", password: "password1" }
POST /api/auth/login
Body: { email: "user@example.com", password: "password2" }
... (10,000 attempts)
```

**Without rate limiting**: Attacker can try unlimited passwords  
**With rate limiting**: After 5 failed attempts, block for 15 minutes

#### Scenario 2: Data Scraping
```
Scraper wants all your data:
GET /api/users?page=1
GET /api/users?page=2
GET /api/users?page=3
... (10,000 pages)
```

**Without rate limiting**: Scraper downloads entire database  
**With rate limiting**: Limited to 100 requests/minute, scraping becomes impractical

#### Scenario 3: Accidental Loop
```
Developer's code has bug:
while (true) {
  fetch('/api/tasks');
}
```

**Without rate limiting**: Server crashes  
**With rate limiting**: After 100 requests, blocked, server stays up

### Current State of Our API Gateway

Looking at `platform-services/backend/deepiri-api-gateway/src/server.ts`, we have:
- ✅ Request routing (proxying to microservices)
- ✅ CORS configuration
- ✅ Security headers (helmet)
- ✅ Logging
- ❌ **No rate limiting** (this is what we need to add!)

The gateway currently allows unlimited requests, making it vulnerable to all the problems above.

---

## The Solution

### Architecture Overview

We'll implement a multi-layered rate limiting strategy:

```
┌─────────────────────────────────────────┐
│         Client Request                   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│      API Gateway (Port 5000)             │
│  ┌───────────────────────────────────┐  │
│  │  Global Rate Limiter              │  │  ← All requests
│  │  (100 req/min per IP)             │  │
│  └──────────────┬────────────────────┘  │
│                 │                        │
│  ┌──────────────▼────────────────────┐  │
│  │  Route-Specific Rate Limiter      │  │  ← Per endpoint
│  │  (Auth: 5 req/min, API: 100/min) │  │
│  └──────────────┬────────────────────┘  │
│                 │                        │
│  ┌──────────────▼────────────────────┐  │
│  │  User-Based Rate Limiter          │  │  ← Authenticated users
│  │  (Premium: 1000/min, Free: 100/min)│  │
│  └──────────────┬────────────────────┘  │
│                 │                        │
│  ┌──────────────▼────────────────────┐  │
│  │  Request Throttling               │  │  ← Smooth traffic
│  │  (Token bucket, leaky bucket)      │  │
│  └──────────────┬────────────────────┘  │
└─────────────────┼────────────────────────┘
                  │
                  ▼
         ┌────────────────┐
         │  Microservices │
         └────────────────┘
```

### Solution Components

#### 1. **Global Rate Limiter**
- First line of defense
- IP-based limiting
- Prevents DDoS attacks
- Fast rejection of abusive traffic

#### 2. **Route-Specific Rate Limiters**
- Different limits for different endpoints
- Auth endpoints: stricter (prevent brute force)
- Read endpoints: more lenient
- Write endpoints: moderate

#### 3. **User-Based Rate Limiting**
- For authenticated users
- Different tiers (free, premium, enterprise)
- More accurate than IP-based
- Better user experience

#### 4. **Request Throttling**
- Smooths out traffic spikes
- Token bucket for burst allowance
- Leaky bucket for constant rate
- Protects downstream services

#### 5. **Redis Storage**
- Shared state across instances
- Works in cluster mode
- Persistent counters
- Built-in expiration

### Technology Stack

- **express-rate-limit**: Industry-standard library
- **ioredis**: Redis client for distributed rate limiting
- **TypeScript**: Type safety
- **Winston**: Logging rate limit violations

### Design Decisions

#### Why express-rate-limit?
- Battle-tested (millions of downloads)
- Well-maintained
- Flexible configuration
- Good TypeScript support
- Redis store available

#### Why Redis?
- Fast (in-memory)
- Atomic operations (INCR, EXPIRE)
- Distributed (works across instances)
- Built-in expiration
- Industry standard

#### Why Multiple Layers?
- Defense in depth
- Different limits for different use cases
- Graceful degradation
- Better user experience

---

## Step-by-Step Implementation

This section will walk you through implementing rate limiting from scratch, starting with the simplest approach and building up to a production-ready solution.

### Phase 1: Basic Setup (Beginner)

**Goal**: Get a simple rate limiter working

#### Step 1.1: Install Dependencies

```bash
cd deepiri-platform/platform-services/backend/deepiri-api-gateway
npm install express-rate-limit ioredis
npm install --save-dev @types/ioredis
```

**What this does:**
- `express-rate-limit`: Rate limiting middleware
- `ioredis`: Redis client for distributed rate limiting
- `@types/ioredis`: TypeScript types

#### Step 1.2: Create Basic Rate Limiter

Create `src/middleware/rateLimiter.ts`:

```typescript
import rateLimit from 'express-rate-limit';
import { Request, Response } from 'express';

// Basic rate limiter: 100 requests per 15 minutes per IP
export const basicRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true, // Return rate limit info in `RateLimit-*` headers
  legacyHeaders: false, // Disable `X-RateLimit-*` headers
  // Skip rate limiting for OPTIONS requests (CORS preflight)
  skip: (req: Request) => req.method === 'OPTIONS',
});
```

**Explanation:**
- `windowMs`: Time window in milliseconds (15 minutes)
- `max`: Maximum requests allowed in that window
- `message`: Error message when limit exceeded
- `standardHeaders`: Adds `RateLimit-*` headers (RFC standard)
- `skip`: Function to skip rate limiting for certain requests

#### Step 1.3: Apply to API Gateway

Edit `src/server.ts`:

```typescript
import { basicRateLimiter } from './middleware/rateLimiter';

// Apply rate limiting BEFORE proxy routes
app.use('/api', basicRateLimiter);

// Your existing proxy routes...
app.use('/api/users', createProxyMiddleware(...));
```

**Why before proxy routes?**
- Rate limiting should happen early (reject bad traffic quickly)
- Before proxying saves resources (don't forward requests we'll reject)

#### Step 1.4: Test It

Start your API Gateway:
```bash
npm run dev
```

Test with curl:
```bash
# Make 101 requests quickly
for i in {1..101}; do
  curl http://localhost:5000/api/users
done
```

**Expected result:**
- First 100 requests: `200 OK`
- 101st request: `429 Too Many Requests` with message

**Check headers:**
```bash
curl -I http://localhost:5000/api/users
```

You should see:
```
RateLimit-Limit: 100
RateLimit-Remaining: 99
RateLimit-Reset: 1640995200
```

**Congratulations!** You have basic rate limiting working. But this is just the beginning...

---

### Phase 2: Redis Integration (Intermediate)

**Goal**: Make rate limiting work across multiple instances

#### Step 2.1: Create Redis Store

The basic rate limiter uses in-memory storage, which doesn't work in cluster mode. We need Redis.

Create `src/middleware/redisStore.ts`:

```typescript
import Redis from 'ioredis';
import { RateLimiterRedis } from 'rate-limiter-flexible';

// Create Redis client
const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379', 10),
  password: process.env.REDIS_PASSWORD,
  retryStrategy: (times) => {
    // Retry with exponential backoff
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
  maxRetriesPerRequest: 3,
});

// Handle Redis connection errors
redis.on('error', (error) => {
  console.error('Redis connection error:', error);
});

redis.on('connect', () => {
  console.log('Redis connected successfully');
});

export { redis };
```

**Wait!** `express-rate-limit` doesn't have built-in Redis support. We have two options:

**Option A: Use `rate-limiter-flexible` (More features)**
```bash
npm install rate-limiter-flexible
```

**Option B: Use `express-rate-limit` with custom store**

Let's use Option B to stay with `express-rate-limit`. Create a custom Redis store:

#### Step 2.2: Custom Redis Store for express-rate-limit

Create `src/middleware/redisRateLimitStore.ts`:

```typescript
import { Store } from 'express-rate-limit';
import { Redis } from 'ioredis';

export class RedisRateLimitStore implements Store {
  private redis: Redis;
  private prefix: string;

  constructor(redis: Redis, prefix: string = 'ratelimit:') {
    this.redis = redis;
    this.prefix = prefix;
  }

  async increment(key: string, cb: (err?: Error, hits?: number, resetTime?: Date) => void): Promise<void> {
    const fullKey = `${this.prefix}${key}`;
    
    try {
      // Use Redis pipeline for atomic operations
      const pipeline = this.redis.pipeline();
      
      // Increment counter
      pipeline.incr(fullKey);
      
      // Set expiration on first request (only if key doesn't exist)
      pipeline.set(fullKey, '1', 'EX', 900, 'NX'); // 15 minutes = 900 seconds
      
      const results = await pipeline.exec();
      
      if (!results) {
        return cb(new Error('Redis pipeline failed'));
      }
      
      const count = results[0][1] as number;
      const ttl = await this.redis.ttl(fullKey);
      const resetTime = new Date(Date.now() + ttl * 1000);
      
      cb(undefined, count, resetTime);
    } catch (error) {
      cb(error as Error);
    }
  }

  async decrement(key: string): Promise<void> {
    const fullKey = `${this.prefix}${key}`;
    await this.redis.decr(fullKey);
  }

  async resetKey(key: string): Promise<void> {
    const fullKey = `${this.prefix}${key}`;
    await this.redis.del(fullKey);
  }

  async shutdown(): Promise<void> {
    // Optionally close Redis connection
    // this.redis.disconnect();
  }
}
```

**Actually, `express-rate-limit` v7 has a simpler approach.** Let's use the built-in Redis store:

#### Step 2.3: Use express-rate-limit with Redis (Simpler)

Actually, `express-rate-limit` v7 doesn't have built-in Redis. Let's use a community package:

```bash
npm install @upstash/ratelimit
# OR
npm install rate-limiter-flexible
```

Let's use `rate-limiter-flexible` as it's more mature:

```bash
npm install rate-limiter-flexible
```

Create `src/middleware/redisRateLimiter.ts`:

```typescript
import { RateLimiterRedis } from 'rate-limiter-flexible';
import { redis } from './redisStore';
import { Request, Response, NextFunction } from 'express';

// Create rate limiter with Redis
const rateLimiter = new RateLimiterRedis({
  storeClient: redis,
  keyPrefix: 'ratelimit',
  points: 100, // Number of requests
  duration: 900, // Per 900 seconds (15 minutes)
  blockDuration: 0, // Don't block, just rate limit
});

// Express middleware wrapper
export const redisRateLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  // Skip for OPTIONS requests
  if (req.method === 'OPTIONS') {
    return next();
  }

  const key = req.ip || 'unknown';

  try {
    const rateLimiterRes = await rateLimiter.consume(key);
    
    // Set rate limit headers
    res.set({
      'X-RateLimit-Limit': '100',
      'X-RateLimit-Remaining': rateLimiterRes.remainingPoints.toString(),
      'X-RateLimit-Reset': new Date(Date.now() + rateLimiterRes.msBeforeNext).toISOString(),
    });

    next();
  } catch (rejRes: any) {
    // Rate limit exceeded
    const secs = Math.round(rejRes.msBeforeNext / 1000) || 1;
    
    res.status(429).set({
      'Retry-After': secs.toString(),
      'X-RateLimit-Limit': '100',
      'X-RateLimit-Remaining': '0',
      'X-RateLimit-Reset': new Date(Date.now() + rejRes.msBeforeNext).toISOString(),
    }).json({
      error: 'Too many requests',
      message: `Rate limit exceeded. Try again in ${secs} seconds.`,
      retryAfter: secs,
    });
  }
};
```

**Wait, this is getting complex.** Let's use a simpler approach with `express-rate-limit` and a custom store implementation. Actually, let me check if there's a simpler way...

**Simplest approach**: Use `express-rate-limit` with a memory store for now, then we'll add Redis later. But for production, we need Redis.

Let's create a proper Redis-backed rate limiter using `express-rate-limit` with a custom store:

#### Step 2.4: Proper Redis Store Implementation

Create `src/middleware/redisStore.ts`:

```typescript
import Redis from 'ioredis';

export const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379', 10),
  password: process.env.REDIS_PASSWORD,
  retryStrategy: (times) => Math.min(times * 50, 2000),
  maxRetriesPerRequest: 3,
});

redis.on('error', (error) => {
  console.error('Redis connection error:', error);
});

redis.on('connect', () => {
  console.log('✅ Redis connected for rate limiting');
});
```

Create `src/middleware/redisRateLimitStore.ts`:

```typescript
import { Store } from 'express-rate-limit';
import { redis } from './redisStore';

export class RedisStore implements Store {
  async increment(key: string): Promise<{ totalHits: number; resetTime: Date | undefined }> {
    const windowMs = 15 * 60 * 1000; // 15 minutes
    const now = Date.now();
    const windowStart = Math.floor(now / windowMs) * windowMs;
    const redisKey = `ratelimit:${key}:${windowStart}`;
    
    try {
      // Increment and set expiration
      const totalHits = await redis.incr(redisKey);
      if (totalHits === 1) {
        // Set expiration only on first request
        await redis.pexpire(redisKey, windowMs);
      }
      
      const ttl = await redis.pttl(redisKey);
      const resetTime = ttl > 0 ? new Date(now + ttl) : undefined;
      
      return { totalHits, resetTime };
    } catch (error) {
      console.error('Redis rate limit error:', error);
      // Fail open: allow request
      return { totalHits: 0, resetTime: undefined };
    }
  }

  async decrement(key: string): Promise<void> {
    // Optional: implement if needed
  }

  async resetKey(key: string): Promise<void> {
    // Optional: implement if needed
  }

  async shutdown(): Promise<void> {
    // Optional: close Redis connection
  }
}
```

**Actually, `express-rate-limit` v7 uses a different store interface.** Let me check the actual interface...

After checking the `express-rate-limit` documentation, the store interface in v7 is:

```typescript
interface Store {
  increment(key: string): Promise<IncrementResponse>;
  decrement?(key: string): Promise<void>;
  resetKey?(key: string): Promise<void>;
  shutdown?(): Promise<void>;
}

interface IncrementResponse {
  totalHits: number;
  resetTime: Date | undefined;
}
```

Our implementation above matches this! Now let's use it:

#### Step 2.5: Use Redis Store in Rate Limiter

Update `src/middleware/rateLimiter.ts`:

```typescript
import rateLimit from 'express-rate-limit';
import { Request } from 'express';
import { RedisStore } from './redisRateLimitStore';

// Check if Redis is available
const useRedis = process.env.REDIS_HOST && process.env.REDIS_HOST !== '';

// Create rate limiter with Redis store (if available) or memory store
export const basicRateLimiter = rateLimit({
  store: useRedis ? new RedisStore() : undefined, // undefined = use memory store
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req: Request) => req.method === 'OPTIONS',
  // Fail open: if Redis fails, allow request
  skipOnError: true,
});
```

**What this does:**
- Uses Redis if `REDIS_HOST` is set
- Falls back to memory store if Redis unavailable
- `skipOnError: true` means if Redis fails, allow requests (fail-open)

#### Step 2.6: Test Redis Rate Limiting

1. Start Redis:
```bash
docker run -d -p 6379:6379 redis:alpine
```

2. Set environment variable:
```bash
export REDIS_HOST=localhost
```

3. Start API Gateway:
```bash
npm run dev
```

4. Test (same as before):
```bash
for i in {1..101}; do
  curl http://localhost:5000/api/users
done
```

5. Check Redis:
```bash
redis-cli
> KEYS ratelimit:*
> GET ratelimit:127.0.0.1:1234567890
```

**You now have distributed rate limiting!** Multiple API Gateway instances will share the same rate limit counters.

---

### Phase 3: Multiple Rate Limiters (Advanced)

**Goal**: Different limits for different routes

#### Step 3.1: Create Route-Specific Limiters

Update `src/middleware/rateLimiter.ts`:

```typescript
import rateLimit from 'express-rate-limit';
import { Request } from 'express';
import { RedisStore } from './redisRateLimitStore';

const useRedis = process.env.REDIS_HOST && process.env.REDIS_HOST !== '';

// Global rate limiter: 100 requests per 15 minutes
export const globalRateLimiter = rateLimit({
  store: useRedis ? new RedisStore() : undefined,
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req: Request) => req.method === 'OPTIONS',
  skipOnError: true,
});

// Strict rate limiter for auth endpoints: 5 requests per 15 minutes
export const authRateLimiter = rateLimit({
  store: useRedis ? new RedisStore() : undefined,
  windowMs: 15 * 60 * 1000,
  max: 5, // Very strict to prevent brute force
  message: 'Too many authentication attempts. Please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req: Request) => req.method === 'OPTIONS',
  skipOnError: true,
  // Custom key generator: include email if available
  keyGenerator: (req: Request) => {
    // Try to get email from body (for login attempts)
    const body = req.body as any;
    if (body?.email) {
      return `${req.ip}:${body.email}`;
    }
    return req.ip || 'unknown';
  },
});

// Moderate rate limiter for write operations: 50 requests per 15 minutes
export const writeRateLimiter = rateLimit({
  store: useRedis ? new RedisStore() : undefined,
  windowMs: 15 * 60 * 1000,
  max: 50,
  message: 'Too many write requests. Please slow down.',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req: Request) => req.method === 'OPTIONS',
  skipOnError: true,
});

// Lenient rate limiter for read operations: 200 requests per 15 minutes
export const readRateLimiter = rateLimit({
  store: useRedis ? new RedisStore() : undefined,
  windowMs: 15 * 60 * 1000,
  max: 200,
  message: 'Too many read requests. Please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req: Request) => req.method === 'OPTIONS',
  skipOnError: true,
});
```

#### Step 3.2: Apply to Specific Routes

Update `src/server.ts`:

```typescript
import {
  globalRateLimiter,
  authRateLimiter,
  writeRateLimiter,
  readRateLimiter,
} from './middleware/rateLimiter';

// Global rate limiter for all API routes
app.use('/api', globalRateLimiter);

// Strict rate limiting for auth routes (prevent brute force)
app.use('/api/auth', authRateLimiter);

// Apply write rate limiter to POST/PUT/DELETE/PATCH routes
app.use('/api', (req, res, next) => {
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(req.method)) {
    return writeRateLimiter(req, res, next);
  }
  next();
});

// Apply read rate limiter to GET/HEAD routes
app.use('/api', (req, res, next) => {
  if (['GET', 'HEAD'].includes(req.method)) {
    return readRateLimiter(req, res, next);
  }
  next();
});

// Your existing proxy routes...
app.use('/api/auth', createProxyMiddleware(...));
```

**What this does:**
- All routes: 100 requests/15min (global)
- Auth routes: Additional 5 requests/15min (very strict)
- Write operations: Additional 50 requests/15min
- Read operations: Additional 200 requests/15min

**Note**: These limits stack! A POST to `/api/auth/login` will check:
1. Global limiter (100/15min)
2. Auth limiter (5/15min)
3. Write limiter (50/15min)

The strictest limit wins.

---

### Phase 4: User-Based Rate Limiting (Expert)

**Goal**: Different limits for different user tiers

#### Step 4.1: Create User-Based Rate Limiter

Create `src/middleware/userRateLimiter.ts`:

```typescript
import rateLimit from 'express-rate-limit';
import { Request } from 'express';
import { RedisStore } from './redisRateLimitStore';

const useRedis = process.env.REDIS_HOST && process.env.REDIS_HOST !== '';

// Get user tier from request (assumes auth middleware sets req.user)
function getUserTier(req: Request): 'free' | 'premium' | 'enterprise' {
  const user = (req as any).user;
  if (!user) return 'free';
  
  // Assuming user object has a tier or subscription field
  return user.tier || user.subscription?.tier || 'free';
}

// Rate limit configuration per tier
const tierLimits = {
  free: {
    windowMs: 15 * 60 * 1000,
    max: 100,
  },
  premium: {
    windowMs: 15 * 60 * 1000,
    max: 1000,
  },
  enterprise: {
    windowMs: 15 * 60 * 1000,
    max: 10000,
  },
};

// Create rate limiter with dynamic limits based on user tier
export const userRateLimiter = rateLimit({
  store: useRedis ? new RedisStore() : undefined,
  windowMs: tierLimits.free.windowMs, // Default to free tier
  max: tierLimits.free.max,
  message: 'Rate limit exceeded for your tier.',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req: Request) => {
    if (req.method === 'OPTIONS') return true;
    // Skip if user not authenticated (will be handled by IP-based limiter)
    return !(req as any).user;
  },
  skipOnError: true,
  // Custom key generator: use user ID instead of IP
  keyGenerator: (req: Request) => {
    const user = (req as any).user;
    if (user?.id || user?.userId) {
      return `user:${user.id || user.userId}`;
    }
    return req.ip || 'unknown';
  },
  // Dynamic max based on user tier
  max: (req: Request) => {
    const tier = getUserTier(req);
    return tierLimits[tier].max;
  },
  // Dynamic windowMs based on user tier
  windowMs: (req: Request) => {
    const tier = getUserTier(req);
    return tierLimits[tier].windowMs;
  },
});

// Wait, express-rate-limit doesn't support dynamic max/windowMs like this.
// We need a different approach...

// Alternative: Create separate limiters per tier
export const freeUserRateLimiter = rateLimit({
  store: useRedis ? new RedisStore() : undefined,
  ...tierLimits.free,
  keyGenerator: (req: Request) => {
    const user = (req as any).user;
    return user?.id || user?.userId || req.ip || 'unknown';
  },
  skip: (req: Request) => {
    if (req.method === 'OPTIONS') return true;
    const tier = getUserTier(req);
    return tier !== 'free'; // Skip if not free tier
  },
});

export const premiumUserRateLimiter = rateLimit({
  store: useRedis ? new RedisStore() : undefined,
  ...tierLimits.premium,
  keyGenerator: (req: Request) => {
    const user = (req as any).user;
    return user?.id || user?.userId || req.ip || 'unknown';
  },
  skip: (req: Request) => {
    if (req.method === 'OPTIONS') return true;
    const tier = getUserTier(req);
    return tier !== 'premium';
  },
});

export const enterpriseUserRateLimiter = rateLimit({
  store: useRedis ? new RedisStore() : undefined,
  ...tierLimits.enterprise,
  keyGenerator: (req: Request) => {
    const user = (req as any).user;
    return user?.id || user?.userId || req.ip || 'unknown';
  },
  skip: (req: Request) => {
    if (req.method === 'OPTIONS') return true;
    const tier = getUserTier(req);
    return tier !== 'enterprise';
  },
});

// Combined middleware that applies the right limiter
export const userBasedRateLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const tier = getUserTier(req);
  
  // Apply the appropriate limiter
  if (tier === 'free') {
    return freeUserRateLimiter(req, res, next);
  } else if (tier === 'premium') {
    return premiumUserRateLimiter(req, res, next);
  } else if (tier === 'enterprise') {
    return enterpriseUserRateLimiter(req, res, next);
  } else {
    // Fallback to IP-based
    next();
  }
};
```

**Actually, this is getting too complex.** Let's use a simpler approach with a custom middleware:

#### Step 4.2: Simpler User-Based Rate Limiter

Update `src/middleware/userRateLimiter.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { RedisStore } from './redisRateLimitStore';
import rateLimit from 'express-rate-limit';

const useRedis = process.env.REDIS_HOST && process.env.REDIS_HOST !== '';

// Tier configurations
const TIER_CONFIGS = {
  free: { windowMs: 15 * 60 * 1000, max: 100 },
  premium: { windowMs: 15 * 60 * 1000, max: 1000 },
  enterprise: { windowMs: 15 * 60 * 1000, max: 10000 },
} as const;

// Create a rate limiter factory
function createUserRateLimiter(tier: keyof typeof TIER_CONFIGS) {
  const config = TIER_CONFIGS[tier];
  
  return rateLimit({
    store: useRedis ? new RedisStore() : undefined,
    windowMs: config.windowMs,
    max: config.max,
    message: `Rate limit exceeded for ${tier} tier.`,
    standardHeaders: true,
    legacyHeaders: false,
    skip: (req: Request) => {
      if (req.method === 'OPTIONS') return true;
      // Only apply to authenticated users
      return !(req as any).user;
    },
    skipOnError: true,
    keyGenerator: (req: Request) => {
      const user = (req as any).user;
      return user?.id || user?.userId || req.ip || 'unknown';
    },
  });
}

// Create limiters for each tier
const freeLimiter = createUserRateLimiter('free');
const premiumLimiter = createUserRateLimiter('premium');
const enterpriseLimiter = createUserRateLimiter('enterprise');

// Get user tier from request
function getUserTier(req: Request): keyof typeof TIER_CONFIGS {
  const user = (req as any).user;
  if (!user) return 'free';
  return user.tier || user.subscription?.tier || 'free';
}

// Combined middleware
export const userBasedRateLimiter = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  // Skip if not authenticated (IP-based limiter will handle it)
  if (!(req as any).user) {
    return next();
  }

  const tier = getUserTier(req);

  // Apply appropriate limiter
  switch (tier) {
    case 'free':
      return freeLimiter(req, res, next);
    case 'premium':
      return premiumLimiter(req, res, next);
    case 'enterprise':
      return enterpriseLimiter(req, res, next);
    default:
      return freeLimiter(req, res, next);
  }
};
```

#### Step 4.3: Apply User-Based Rate Limiter

Update `src/server.ts`:

```typescript
import { userBasedRateLimiter } from './middleware/userRateLimiter';

// Apply user-based rate limiting AFTER authentication middleware
// (Assuming you have auth middleware that sets req.user)
app.use('/api', userBasedRateLimiter);
```

**Note**: This should come AFTER your authentication middleware, so `req.user` is available.

---

### Phase 5: Request Throttling (Master Level)

**Goal**: Smooth out traffic spikes using token bucket algorithm

#### Step 5.1: Implement Token Bucket

Create `src/middleware/tokenBucket.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { redis } from './redisStore';

interface TokenBucketConfig {
  capacity: number; // Maximum tokens
  refillRate: number; // Tokens per second
  cost: number; // Tokens per request (default 1)
}

class TokenBucket {
  private config: TokenBucketConfig;
  private redis: typeof redis;

  constructor(config: TokenBucketConfig, redisClient: typeof redis) {
    this.config = config;
    this.redis = redisClient;
  }

  async consume(key: string, tokens: number = this.config.cost): Promise<{
    allowed: boolean;
    remaining: number;
    resetIn: number; // milliseconds until next token available
  }> {
    const redisKey = `tokenbucket:${key}`;
    const now = Date.now();

    try {
      // Use Lua script for atomic operations
      const luaScript = `
        local key = KEYS[1]
        local capacity = tonumber(ARGV[1])
        local refillRate = tonumber(ARGV[2])
        local tokens = tonumber(ARGV[3])
        local now = tonumber(ARGV[4])
        
        local bucket = redis.call('HMGET', key, 'tokens', 'lastRefill')
        local currentTokens = tonumber(bucket[1]) or capacity
        local lastRefill = tonumber(bucket[2]) or now
        
        -- Calculate refill
        local elapsed = (now - lastRefill) / 1000 -- seconds
        local refill = elapsed * refillRate
        currentTokens = math.min(capacity, currentTokens + refill)
        
        -- Check if we can consume
        if currentTokens >= tokens then
          currentTokens = currentTokens - tokens
          redis.call('HMSET', key, 'tokens', currentTokens, 'lastRefill', now)
          redis.call('EXPIRE', key, math.ceil(capacity / refillRate) + 1)
          return {1, currentTokens, 0}
        else
          -- Calculate when next token will be available
          local tokensNeeded = tokens - currentTokens
          local waitTime = math.ceil((tokensNeeded / refillRate) * 1000)
          return {0, currentTokens, waitTime}
        end
      `;

      const result = await this.redis.eval(
        luaScript,
        1,
        redisKey,
        this.config.capacity.toString(),
        this.config.refillRate.toString(),
        tokens.toString(),
        now.toString()
      ) as [number, number, number];

      const [allowed, remaining, resetIn] = result;

      return {
        allowed: allowed === 1,
        remaining: Math.floor(remaining),
        resetIn,
      };
    } catch (error) {
      console.error('Token bucket error:', error);
      // Fail open: allow request
      return { allowed: true, remaining: this.config.capacity, resetIn: 0 };
    }
  }
}

// Create token bucket instances
const defaultBucket = new TokenBucket(
  {
    capacity: 100, // 100 tokens
    refillRate: 10, // 10 tokens per second
    cost: 1, // 1 token per request
  },
  redis
);

// Middleware factory
export function createTokenBucketMiddleware(bucket: TokenBucket = defaultBucket) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (req.method === 'OPTIONS') {
      return next();
    }

    const key = (req as any).user?.id || req.ip || 'unknown';
    const result = await bucket.consume(key);

    // Set headers
    res.set({
      'X-RateLimit-Remaining': result.remaining.toString(),
      'X-RateLimit-Reset-In': result.resetIn.toString(),
    });

    if (!result.allowed) {
      return res.status(429).set({
        'Retry-After': Math.ceil(result.resetIn / 1000).toString(),
      }).json({
        error: 'Rate limit exceeded',
        message: `Too many requests. Try again in ${Math.ceil(result.resetIn / 1000)} seconds.`,
        retryAfter: Math.ceil(result.resetIn / 1000),
      });
    }

    next();
  };
}

export const tokenBucketMiddleware = createTokenBucketMiddleware();
```

#### Step 5.2: Apply Token Bucket Throttling

Update `src/server.ts`:

```typescript
import { tokenBucketMiddleware } from './middleware/tokenBucket';

// Apply token bucket throttling (allows bursts but controls average rate)
app.use('/api', tokenBucketMiddleware);
```

**What this does:**
- Allows bursts (if tokens available)
- Controls average rate (10 requests/second)
- Smooths out traffic spikes
- Better user experience than hard limits

---

## Advanced Implementation

### Advanced Feature 1: Whitelist/Blacklist

Create `src/middleware/ipFilter.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { redis } from './redisStore';

// Whitelist: always allow
const WHITELIST_IPS = process.env.WHITELIST_IPS?.split(',') || [];

// Blacklist: always deny
const BLACKLIST_IPS = process.env.BLACKLIST_IPS?.split(',') || [];

export async function ipFilter(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const ip = req.ip || 'unknown';

  // Check whitelist
  if (WHITELIST_IPS.includes(ip)) {
    return next(); // Skip rate limiting
  }

  // Check blacklist
  if (BLACKLIST_IPS.includes(ip)) {
    return res.status(403).json({ error: 'IP address blocked' });
  }

  // Check Redis blacklist (for dynamic blacklisting)
  try {
    const isBlacklisted = await redis.get(`blacklist:${ip}`);
    if (isBlacklisted) {
      return res.status(403).json({ error: 'IP address blocked' });
    }
  } catch (error) {
    // Fail open
    console.error('Blacklist check error:', error);
  }

  next();
}
```

### Advanced Feature 2: Rate Limit Headers

Ensure all rate limiters set proper headers:

```typescript
// In your rate limiter configuration
standardHeaders: true, // Sets RateLimit-* headers (RFC standard)
legacyHeaders: false,   // Disables X-RateLimit-* headers

// Custom headers can be added in onLimitReached callback
onLimitReached: (req: Request, res: Response) => {
  res.set('X-Custom-RateLimit-Message', 'Custom message');
},
```

### Advanced Feature 3: Rate Limit Analytics

Track rate limit violations:

```typescript
import { redis } from './redisStore';

export async function trackRateLimitViolation(
  key: string,
  endpoint: string,
  ip: string
) {
  try {
    await redis.incr(`ratelimit:violations:${ip}`);
    await redis.lpush('ratelimit:violations:log', JSON.stringify({
      key,
      endpoint,
      ip,
      timestamp: Date.now(),
    }));
    // Keep only last 1000 violations
    await redis.ltrim('ratelimit:violations:log', 0, 999);
  } catch (error) {
    console.error('Failed to track violation:', error);
  }
}

// Use in rate limiter
onLimitReached: async (req: Request, res: Response) => {
  await trackRateLimitViolation(
    req.ip || 'unknown',
    req.path,
    req.ip || 'unknown'
  );
},
```

### Advanced Feature 4: Adaptive Rate Limiting

Adjust limits based on server load:

```typescript
import os from 'os';

async function getServerLoad(): Promise<number> {
  const loadAvg = os.loadavg()[0]; // 1-minute load average
  const cpuCount = os.cpus().length;
  return loadAvg / cpuCount; // Normalized load (0-1+)
}

export function createAdaptiveRateLimiter(baseMax: number) {
  return rateLimit({
    max: async (req: Request) => {
      const load = await getServerLoad();
      // Reduce limit if server is under heavy load
      if (load > 0.8) {
        return Math.floor(baseMax * 0.5); // 50% of base limit
      } else if (load > 0.5) {
        return Math.floor(baseMax * 0.75); // 75% of base limit
      }
      return baseMax;
    },
    // ... other config
  });
}
```

### Advanced Feature 5: Distributed Rate Limiting with Redis Cluster

For high-availability setups:

```typescript
import Redis from 'ioredis';

const redis = new Redis.Cluster([
  { host: 'redis-node-1', port: 6379 },
  { host: 'redis-node-2', port: 6379 },
  { host: 'redis-node-3', port: 6379 },
], {
  redisOptions: {
    password: process.env.REDIS_PASSWORD,
  },
});
```

---

## Testing & Monitoring

### Testing Rate Limiting

#### Unit Tests

Create `src/middleware/__tests__/rateLimiter.test.ts`:

```typescript
import request from 'supertest';
import express from 'express';
import { globalRateLimiter } from '../rateLimiter';

const app = express();
app.use(express.json());
app.use('/api', globalRateLimiter);
app.get('/api/test', (req, res) => res.json({ ok: true }));

describe('Rate Limiter', () => {
  it('should allow requests within limit', async () => {
    for (let i = 0; i < 100; i++) {
      const res = await request(app).get('/api/test');
      expect(res.status).toBe(200);
    }
  });

  it('should reject requests over limit', async () => {
    // Make 100 requests first
    for (let i = 0; i < 100; i++) {
      await request(app).get('/api/test');
    }

    // 101st request should be rejected
    const res = await request(app).get('/api/test');
    expect(res.status).toBe(429);
    expect(res.body.message).toContain('Too many requests');
  });

  it('should include rate limit headers', async () => {
    const res = await request(app).get('/api/test');
    expect(res.headers['ratelimit-limit']).toBeDefined();
    expect(res.headers['ratelimit-remaining']).toBeDefined();
    expect(res.headers['ratelimit-reset']).toBeDefined();
  });
});
```

#### Integration Tests

Test with actual Redis:

```typescript
import Redis from 'ioredis';

describe('Redis Rate Limiting', () => {
  let redis: Redis;

  beforeAll(() => {
    redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');
  });

  afterAll(async () => {
    await redis.quit();
  });

  it('should persist rate limits across instances', async () => {
    // Simulate two different API Gateway instances
    const key = 'test:ip:127.0.0.1';
    
    // Instance 1 increments
    await redis.incr(key);
    
    // Instance 2 should see the same count
    const count = await redis.get(key);
    expect(parseInt(count || '0')).toBe(1);
  });
});
```

### Monitoring Rate Limits

#### Logging Violations

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'rate-limit-violations.log' }),
  ],
});

// In rate limiter
onLimitReached: (req: Request, res: Response) => {
  logger.warn('Rate limit exceeded', {
    ip: req.ip,
    path: req.path,
    method: req.method,
    userAgent: req.get('user-agent'),
    timestamp: new Date().toISOString(),
  });
},
```

#### Metrics Collection

```typescript
import { redis } from './redisStore';

export async function collectRateLimitMetrics() {
  try {
    // Count total violations today
    const violations = await redis.get('ratelimit:violations:today');
    
    // Get top violating IPs
    const topIPs = await redis.zrevrange('ratelimit:violations:by-ip', 0, 9);
    
    return {
      violationsToday: parseInt(violations || '0'),
      topViolatingIPs: topIPs,
    };
  } catch (error) {
    console.error('Failed to collect metrics:', error);
    return null;
  }
}
```

#### Dashboard Endpoint

```typescript
app.get('/admin/rate-limit-stats', async (req, res) => {
  const stats = await collectRateLimitMetrics();
  res.json(stats);
});
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Rate Limiting Not Working

**Symptoms**: Requests are not being rate limited

**Solutions**:
1. Check middleware order (rate limiter must come before routes)
2. Verify Redis connection (if using Redis)
3. Check `skip` function logic
4. Ensure `skipOnError` is not silently failing

#### Issue 2: Rate Limits Reset Too Quickly

**Symptoms**: Users can make more requests than expected

**Solutions**:
1. Check `windowMs` value (should be in milliseconds)
2. Verify Redis TTL is set correctly
3. Check for multiple rate limiters conflicting

#### Issue 3: Redis Connection Errors

**Symptoms**: Rate limiting fails, all requests allowed

**Solutions**:
1. Check Redis is running: `redis-cli ping`
2. Verify `REDIS_HOST` and `REDIS_PORT` environment variables
3. Check network connectivity
4. Review `skipOnError` setting (fail-open vs fail-closed)

#### Issue 4: Rate Limits Too Strict

**Symptoms**: Legitimate users getting blocked

**Solutions**:
1. Increase `max` value
2. Increase `windowMs` (longer window)
3. Add whitelist for known good IPs
4. Implement user-based rate limiting (more accurate)

#### Issue 5: Memory Leaks (In-Memory Store)

**Symptoms**: API Gateway memory usage grows over time

**Solutions**:
1. Switch to Redis store
2. Implement cleanup for old entries
3. Set maximum Map size
4. Use TTL-based cleanup

### Debugging Tips

#### Enable Debug Logging

```typescript
const rateLimiter = rateLimit({
  // ... config
  onLimitReached: (req, res) => {
    console.log('Rate limit reached:', {
      ip: req.ip,
      path: req.path,
      headers: req.headers,
    });
  },
});
```

#### Check Redis Keys

```bash
redis-cli
> KEYS ratelimit:*
> GET ratelimit:127.0.0.1:1234567890
> TTL ratelimit:127.0.0.1:1234567890
```

#### Monitor Rate Limit Headers

```bash
curl -I http://localhost:5000/api/users
```

Look for:
- `RateLimit-Limit`
- `RateLimit-Remaining`
- `RateLimit-Reset`

---

## Conclusion

You've now learned how to implement comprehensive rate limiting and request throttling in your API Gateway. From basic IP-based limiting to advanced user-tier-based distributed rate limiting with Redis, you have the tools to protect your API from abuse while providing a good user experience.

### Key Takeaways

1. **Start Simple**: Begin with basic rate limiting, then add complexity
2. **Use Redis**: For production, distributed rate limiting is essential
3. **Multiple Layers**: Combine global, route-specific, and user-based limiters
4. **Fail Open**: In most cases, allow requests if rate limiting fails (better UX)
5. **Monitor**: Track violations and adjust limits based on real usage
6. **Test**: Write tests to ensure rate limiting works correctly

### Next Steps

1. Implement the basic rate limiter (Phase 1)
2. Add Redis integration (Phase 2)
3. Add route-specific limiters (Phase 3)
4. Implement user-based limiting (Phase 4)
5. Add request throttling (Phase 5)
6. Set up monitoring and alerting
7. Tune limits based on production metrics

### Resources

- [express-rate-limit Documentation](https://github.com/express-rate-limit/express-rate-limit)
- [Redis Rate Limiting Patterns](https://redis.io/docs/manual/patterns/rate-limiting/)
- [RFC 6585 - Additional HTTP Status Codes](https://tools.ietf.org/html/rfc6585#section-4) (429 status code)
- [Rate Limiting Strategies](https://cloud.google.com/architecture/rate-limiting-strategies-techniques)

---

**Happy Rate Limiting!** 🚀







