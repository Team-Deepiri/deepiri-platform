# JWT Token Refresh Mechanism and Token Rotation

**Version:** 1.0  
**Date:** 2025-01-27  
**Status:** Implementation Guide  
**Target:** Auth Service at `platform-services/backend/deepiri-auth-service/`

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Warmup Exercises](#warmup-exercises)
3. [The Problem](#the-problem)
4. [The Solution](#the-solution)
5. [Step-by-Step Implementation](#step-by-step-implementation)
6. [Advanced Implementation](#advanced-implementation)
7. [Token Rotation Strategies](#token-rotation-strategies)
8. [Testing & Security](#testing--security)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before implementing JWT token refresh and rotation, you need to understand several fundamental concepts. This section will break down everything you need to know, from basic to advanced.

### 1. JWT (JSON Web Token) Fundamentals

#### What is a JWT?

A JWT is a compact, URL-safe token format used to securely transmit information between parties. It consists of three parts separated by dots:

```
header.payload.signature
```

**Example:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIxMjMiLCJlbWFpbCI6InVzZXJAZXhhbXBsZS5jb20iLCJpYXQiOjE2NDA5OTUyMDAsImV4cCI6MTY0MTA4MTYwMH0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

#### JWT Structure

**Header:**
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```
- `alg`: Algorithm used for signing (HS256, RS256, etc.)
- `typ`: Token type (always "JWT")

**Payload:**
```json
{
  "userId": "123",
  "email": "user@example.com",
  "iat": 1640995200,
  "exp": 1641081600
}
```
- Contains claims (data about the user)
- `iat`: Issued at (timestamp)
- `exp`: Expiration (timestamp)

**Signature:**
```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret
)
```
- Verifies token hasn't been tampered with
- Created using secret key

#### JWT Properties

1. **Stateless**: No server-side storage needed (for access tokens)
2. **Self-contained**: All user info in the token
3. **Signed**: Cannot be modified without secret
4. **Expires**: Has expiration time
5. **Verifiable**: Can be verified without database lookup

### 2. Access Tokens vs Refresh Tokens

#### Access Token

**Purpose**: Authenticate API requests

**Characteristics:**
- Short-lived (15 minutes to 1 hour)
- Contains user identity and permissions
- Sent with every API request
- Stored in memory (not localStorage for security)
- If stolen, limited damage (expires quickly)

**Example:**
```typescript
const accessToken = jwt.sign(
  { userId: user.id, email: user.email },
  JWT_SECRET,
  { expiresIn: '15m' } // Short expiration
);
```

#### Refresh Token

**Purpose**: Obtain new access tokens

**Characteristics:**
- Long-lived (7 days to 90 days)
- Stored securely (httpOnly cookie or secure storage)
- Not sent with every request
- Used only for token refresh
- Can be revoked (stored in database)
- If stolen, more damage (longer validity)

**Example:**
```typescript
const refreshToken = jwt.sign(
  { userId: user.id, tokenId: uuid() },
  REFRESH_TOKEN_SECRET,
  { expiresIn: '7d' } // Long expiration
);
```

#### Why Two Tokens?

**Security Benefits:**
1. **Reduced Attack Window**: Access token expires quickly
2. **Revocation**: Refresh tokens can be invalidated
3. **Compromise Isolation**: Stolen access token has limited use
4. **Rotation**: Refresh tokens can be rotated on each use

### 3. Token Expiration and Refresh Flow

#### Basic Flow

```
1. User logs in
   → Server issues: accessToken (15min) + refreshToken (7d)

2. Client makes API request
   → Sends: Authorization: Bearer <accessToken>
   → Server validates accessToken

3. Access token expires
   → Client receives 401 Unauthorized

4. Client refreshes token
   → Sends: refreshToken to /auth/refresh
   → Server validates refreshToken
   → Server issues: new accessToken + new refreshToken

5. Client uses new accessToken
   → Continues making API requests
```

#### Token Lifecycle

```
Login
  ↓
Access Token (15min) ──┐
                       │
Refresh Token (7d) ────┼──→ Used after 15min
                       │
                       ↓
                   Refresh
                       ↓
New Access Token (15min) ──┐
                          │
New Refresh Token (7d) ───┼──→ Used after 15min
                          │
                          ↓
                      (Repeat)
```

### 4. Token Rotation Concepts

#### What is Token Rotation?

Token rotation means issuing a new refresh token every time the refresh endpoint is called, and invalidating the old one.

#### Why Rotate Tokens?

**Security Benefits:**
1. **Detect Theft**: If old token is used, we know it was stolen
2. **Limit Damage**: Stolen token can only be used once
3. **Compromise Detection**: Multiple refresh attempts indicate attack
4. **Forward Secrecy**: Old tokens become useless immediately

#### Rotation Strategies

**Strategy 1: Rotate on Every Refresh**
```
Old Refresh Token → New Access Token + New Refresh Token
Old Refresh Token → INVALID (cannot be reused)
```

**Strategy 2: Reuse Detection**
```
Old Refresh Token → New Access Token + New Refresh Token
Old Refresh Token → If used again → REVOKE ALL tokens (theft detected)
```

**Strategy 3: Sliding Window**
```
Old Refresh Token → New Access Token + New Refresh Token
Old Refresh Token → Valid for 24h after rotation (grace period)
```

### 5. Database Schema for Refresh Tokens

#### Why Store Refresh Tokens?

Access tokens are stateless (JWT), but refresh tokens should be stored because:
- Need to revoke them
- Need to detect reuse (theft)
- Need to track active sessions
- Need to implement rotation

#### Schema Design

**Option 1: Separate RefreshToken Table**

```prisma
model RefreshToken {
  id        String   @id @default(uuid())
  token     String   @unique
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  expiresAt DateTime
  revoked   Boolean  @default(false)
  revokedAt DateTime?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  ipAddress String?
  userAgent  String?
  
  @@index([userId])
  @@index([token])
  @@index([expiresAt])
}
```

**Option 2: Embedded in User Model**

```prisma
model User {
  id            String   @id @default(uuid())
  email         String   @unique
  password      String
  refreshTokens RefreshToken[]
  // ... other fields
}

model RefreshToken {
  id        String   @id @default(uuid())
  token     String
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  expiresAt DateTime
  revoked   Boolean  @default(false)
  // ... other fields
}
```

**Option 3: Single Token Per User (Simpler)**

```prisma
model User {
  id                String    @id @default(uuid())
  email             String    @unique
  password          String
  refreshToken      String?
  refreshTokenExp   DateTime?
  // ... other fields
}
```

### 6. Cryptographic Concepts

#### Hashing vs Signing

**Hashing (One-way):**
```typescript
hash(password) → "abc123..." // Cannot reverse
```
- Used for passwords
- One-way function
- Cannot be reversed

**Signing (Verifiable):**
```typescript
sign(data, secret) → "signature"
verify(data, signature, secret) → true/false
```
- Used for JWTs
- Can verify authenticity
- Cannot modify without secret

#### HMAC (Hash-based Message Authentication Code)

```typescript
const signature = crypto
  .createHmac('sha256', secret)
  .update(header + '.' + payload)
  .digest('base64url');
```

**Properties:**
- Symmetric (same secret for sign/verify)
- Fast
- Good for single-server deployments

#### RSA (Asymmetric)

```typescript
// Sign with private key
const signature = crypto
  .createSign('RSA-SHA256')
  .update(header + '.' + payload)
  .sign(privateKey, 'base64url');

// Verify with public key
const isValid = crypto
  .createVerify('RSA-SHA256')
  .update(header + '.' + payload)
  .verify(publicKey, signature);
```

**Properties:**
- Asymmetric (private key signs, public key verifies)
- Slower
- Good for distributed systems

### 7. Security Best Practices

#### Token Storage

**Access Token:**
- ✅ Memory (JavaScript variable)
- ✅ Session storage (better than localStorage)
- ❌ localStorage (vulnerable to XSS)
- ❌ Cookies (unless httpOnly, but then can't read in JS)

**Refresh Token:**
- ✅ httpOnly cookie (most secure)
- ✅ Secure storage (mobile apps)
- ❌ localStorage (vulnerable to XSS)
- ❌ Memory (lost on refresh)

#### Token Transmission

**Access Token:**
```
Authorization: Bearer <token>
```

**Refresh Token:**
```
Cookie: refreshToken=<token>; HttpOnly; Secure; SameSite=Strict
```

#### Token Validation

Always validate:
1. Token signature
2. Token expiration
3. Token format
4. User still exists
5. User still active
6. Refresh token not revoked

### 8. Express.js and Middleware

#### Request Object

```typescript
req.headers.authorization  // "Bearer <token>"
req.cookies.refreshToken   // Refresh token from cookie
req.body.refreshToken      // Refresh token from body
req.ip                     // Client IP
req.get('user-agent')      // User agent
```

#### Response Object

```typescript
res.cookie('refreshToken', token, {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict',
  maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
});

res.json({
  accessToken: '...',
  refreshToken: '...' // Or set as cookie
});
```

### 9. Error Handling

#### Token Errors

**TokenExpiredError:**
```typescript
if (error.name === 'TokenExpiredError') {
  // Token expired, try refresh
}
```

**JsonWebTokenError:**
```typescript
if (error.name === 'JsonWebTokenError') {
  // Invalid token format or signature
}
```

**NotBeforeError:**
```typescript
if (error.name === 'NotBeforeError') {
  // Token not yet valid
}
```

### 10. TypeScript Types

#### JWT Payload Types

```typescript
interface AccessTokenPayload {
  userId: string;
  email: string;
  roles?: string[];
  iat: number;
  exp: number;
}

interface RefreshTokenPayload {
  userId: string;
  tokenId: string; // Unique ID for this refresh token
  iat: number;
  exp: number;
}
```

#### Request Extensions

```typescript
declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        userId: string;
        email: string;
        roles: string[];
      };
    }
  }
}
```

---

## Warmup Exercises

Before implementing token refresh and rotation, complete these exercises to solidify your understanding.

### Exercise 1: Create and Verify JWT

**Goal**: Create a JWT and verify it

**Task**:
1. Install `jsonwebtoken` and `@types/jsonwebtoken`
2. Create a function to sign a JWT
3. Create a function to verify a JWT
4. Test with valid and invalid tokens

**Solution:**
```typescript
// src/utils/jwt.ts
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'secret';

export function signToken(payload: { userId: string; email: string }): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '15m' });
}

export function verifyToken(token: string): any {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error: any) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Token expired');
    }
    if (error.name === 'JsonWebTokenError') {
      throw new Error('Invalid token');
    }
    throw error;
  }
}

// Test
const token = signToken({ userId: '123', email: 'user@example.com' });
console.log('Token:', token);

try {
  const decoded = verifyToken(token);
  console.log('Decoded:', decoded);
} catch (error) {
  console.error('Error:', error);
}
```

### Exercise 2: Access Token Middleware

**Goal**: Create middleware to verify access tokens

**Task**:
1. Extract token from Authorization header
2. Verify token
3. Attach user to request object
4. Handle errors gracefully

**Solution:**
```typescript
// src/middleware/authenticateToken.ts
import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../utils/jwt';

export function authenticateToken(
  req: Request,
  res: Response,
  next: NextFunction
) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.substring(7);
    const decoded = verifyToken(token);

    (req as any).user = {
      userId: decoded.userId,
      email: decoded.email,
    };

    next();
  } catch (error: any) {
    if (error.message === 'Token expired') {
      return res.status(401).json({ error: 'Token expired' });
    }
    if (error.message === 'Invalid token') {
      return res.status(401).json({ error: 'Invalid token' });
    }
    return res.status(500).json({ error: 'Authentication error' });
  }
}
```

### Exercise 3: Refresh Token Storage

**Goal**: Store refresh tokens in database

**Task**:
1. Create RefreshToken model in Prisma schema
2. Create function to save refresh token
3. Create function to find refresh token
4. Create function to revoke refresh token

**Solution:**
```typescript
// prisma/schema.prisma
model RefreshToken {
  id        String   @id @default(uuid())
  token     String   @unique
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  expiresAt DateTime
  revoked   Boolean  @default(false)
  createdAt DateTime @default(now())
  
  @@index([userId])
  @@index([token])
}

model User {
  id            String         @id @default(uuid())
  email         String         @unique
  password      String
  refreshTokens RefreshToken[]
}

// src/services/refreshTokenService.ts
import prisma from '../db';

export async function saveRefreshToken(
  userId: string,
  token: string,
  expiresAt: Date
) {
  return prisma.refreshToken.create({
    data: {
      userId,
      token,
      expiresAt,
    },
  });
}

export async function findRefreshToken(token: string) {
  return prisma.refreshToken.findUnique({
    where: { token },
    include: { user: true },
  });
}

export async function revokeRefreshToken(token: string) {
  return prisma.refreshToken.update({
    where: { token },
    data: { revoked: true },
  });
}
```

### Exercise 4: Basic Refresh Endpoint

**Goal**: Create endpoint to refresh access token

**Task**:
1. Accept refresh token
2. Validate refresh token
3. Check if token exists in database
4. Check if token is expired
5. Issue new access token

**Solution:**
```typescript
// src/routes/auth.ts
import { Router, Request, Response } from 'express';
import { verifyToken, signToken } from '../utils/jwt';
import { findRefreshToken } from '../services/refreshTokenService';

const router = Router();

router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;
    
    if (!refreshToken) {
      return res.status(401).json({ error: 'No refresh token provided' });
    }

    // Verify JWT signature
    const decoded = verifyToken(refreshToken);
    
    // Check if token exists in database
    const storedToken = await findRefreshToken(refreshToken);
    if (!storedToken) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    // Check if token is revoked
    if (storedToken.revoked) {
      return res.status(401).json({ error: 'Refresh token revoked' });
    }

    // Check if token is expired
    if (storedToken.expiresAt < new Date()) {
      return res.status(401).json({ error: 'Refresh token expired' });
    }

    // Issue new access token
    const accessToken = signToken({
      userId: storedToken.userId,
      email: storedToken.user.email,
    });

    res.json({
      accessToken,
    });
  } catch (error: any) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});

export default router;
```

### Exercise 5: Token Rotation

**Goal**: Rotate refresh token on each refresh

**Task**:
1. When refreshing, create new refresh token
2. Revoke old refresh token
3. Return both new access token and new refresh token

**Solution:**
```typescript
// Update refresh endpoint
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { refreshToken: oldRefreshToken } = req.body;
    
    // ... validation code from Exercise 4 ...

    // Create new refresh token
    const newRefreshToken = jwt.sign(
      { userId: storedToken.userId, tokenId: uuid() },
      REFRESH_TOKEN_SECRET,
      { expiresIn: '7d' }
    );

    // Save new refresh token
    await saveRefreshToken(
      storedToken.userId,
      newRefreshToken,
      new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    );

    // Revoke old refresh token
    await revokeRefreshToken(oldRefreshToken);

    // Issue new access token
    const accessToken = signToken({
      userId: storedToken.userId,
      email: storedToken.user.email,
    });

    res.json({
      accessToken,
      refreshToken: newRefreshToken,
    });
  } catch (error: any) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});
```

---

## The Problem

### Why Do We Need Token Refresh?

#### Problem 1: Token Expiration vs User Experience

**Without Refresh:**
```
User logs in → Gets token (15min expiration)
User works for 20 minutes → Token expires
User makes request → 401 Unauthorized
User must log in again → Bad UX
```

**With Refresh:**
```
User logs in → Gets accessToken (15min) + refreshToken (7d)
User works for 20 minutes → Access token expires
User makes request → 401 Unauthorized
Client automatically refreshes → New accessToken
User continues working → Good UX
```

#### Problem 2: Security vs Convenience

**Long-lived tokens:**
- ✅ Convenient (no frequent logins)
- ❌ Security risk (stolen token valid for long time)

**Short-lived tokens:**
- ✅ Secure (stolen token expires quickly)
- ❌ Inconvenient (frequent logins)

**Solution: Refresh tokens**
- ✅ Secure (access token expires quickly)
- ✅ Convenient (refresh token lasts longer)
- ✅ Best of both worlds

#### Problem 3: Token Theft

**Without Rotation:**
```
Attacker steals refresh token
Attacker uses it to get access tokens
Attacker continues using refresh token indefinitely
Victim doesn't know token was stolen
```

**With Rotation:**
```
Attacker steals refresh token
Attacker uses it once → Gets new tokens
Original refresh token is revoked
If attacker uses old token again → We detect theft
If victim uses new token → Attacker's token becomes invalid
```

### Current State of Our Auth Service

Looking at `platform-services/backend/deepiri-auth-service/src/authService.ts`:

**Issues:**
1. ❌ No refresh tokens stored in database
2. ❌ Refresh endpoint just re-signs same token (not proper refresh)
3. ❌ No token rotation
4. ❌ No token revocation
5. ❌ Access tokens last 7 days (too long)
6. ❌ No distinction between access and refresh tokens

**Current Implementation:**
```typescript
// Login: Issues single token (7 days)
const token = jwt.sign(
  { userId: user.id, email: user.email },
  JWT_SECRET,
  { expiresIn: '7d' }
);

// Refresh: Just re-signs same token
const newToken = jwt.sign(
  { userId: decoded.userId, email: decoded.email },
  JWT_SECRET,
  { expiresIn: '7d' }
);
```

**Problems:**
- Token never expires for 7 days (security risk)
- No way to revoke token
- No refresh token mechanism
- No token rotation

---

## The Solution

### Architecture Overview

We'll implement a proper JWT refresh and rotation system:

```
┌─────────────────────────────────────────┐
│         User Login                       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│      Auth Service                        │
│  ┌───────────────────────────────────┐  │
│  │  Issue Tokens                     │  │
│  │  • Access Token (15min)           │  │
│  │  • Refresh Token (7d)             │  │
│  └──────────────┬────────────────────┘  │
│                 │                        │
│  ┌──────────────▼────────────────────┐  │
│  │  Store Refresh Token in DB         │  │
│  │  • Token hash                      │  │
│  │  • User ID                        │  │
│  │  • Expiration                      │  │
│  └───────────────────────────────────┘  │
└─────────────────┬───────────────────────┘
                  │
                  ▼
         ┌─────────────────┐
         │  Client Storage │
         │  • Access: Memory│
         │  • Refresh: Cookie│
         └─────────────────┘
                  │
                  ▼
         ┌─────────────────┐
         │  API Requests    │
         │  Bearer <access> │
         └─────────────────┘
                  │
                  ▼
         ┌─────────────────┐
         │  Token Expired? │
         └────────┬────────┘
                  │ Yes
                  ▼
         ┌─────────────────┐
         │  Refresh Endpoint│
         │  POST /refresh   │
         └────────┬────────┘
                  │
                  ▼
         ┌─────────────────┐
         │  Validate Refresh│
         │  • Check DB      │
         │  • Check expiry  │
         │  • Check revoked │
         └────────┬────────┘
                  │
                  ▼
         ┌─────────────────┐
         │  Rotate Tokens   │
         │  • New access    │
         │  • New refresh   │
         │  • Revoke old    │
         └─────────────────┘
```

### Solution Components

#### 1. **Access Token**
- Short-lived (15 minutes)
- Contains user identity
- Used for API authentication
- Stored in memory

#### 2. **Refresh Token**
- Long-lived (7 days)
- Stored in database
- Used only for token refresh
- Can be revoked
- Rotated on each use

#### 3. **Token Storage**
- Refresh tokens in PostgreSQL (Prisma)
- Track expiration, revocation, user association

#### 4. **Token Rotation**
- New refresh token on each refresh
- Old refresh token revoked
- Theft detection if old token reused

#### 5. **Security Features**
- httpOnly cookies for refresh tokens
- Secure flag in production
- SameSite protection
- Token revocation on logout
- Theft detection

### Technology Stack

- **jsonwebtoken**: JWT creation and verification
- **Prisma**: Database ORM for refresh token storage
- **PostgreSQL**: Database for refresh tokens
- **bcryptjs**: Token hashing (optional, for extra security)
- **crypto**: UUID generation for token IDs

### Design Decisions

#### Why Separate Access and Refresh Tokens?
- **Security**: Access tokens expire quickly, limiting damage if stolen
- **Revocation**: Refresh tokens can be revoked
- **UX**: Users don't need to log in frequently

#### Why Store Refresh Tokens?
- **Revocation**: Need to invalidate tokens
- **Theft Detection**: Detect if token is reused
- **Session Management**: Track active sessions

#### Why Rotate Tokens?
- **Theft Detection**: Reuse of old token indicates theft
- **Forward Secrecy**: Old tokens become useless
- **Compromise Detection**: Multiple refresh attempts indicate attack

---

## Step-by-Step Implementation

This section will walk you through implementing JWT refresh and rotation from scratch, starting with the simplest approach and building up to a production-ready solution.

### Phase 1: Database Schema Setup (Beginner)

**Goal**: Set up database schema for refresh tokens

#### Step 1.1: Update Prisma Schema

Edit `platform-services/backend/deepiri-auth-service/prisma/schema.prisma`:

```prisma
model User {
  id            String         @id @default(uuid())
  email         String         @unique
  password      String
  name          String?
  isActive      Boolean        @default(true)
  lastLoginAt   DateTime?
  createdAt     DateTime       @default(now())
  updatedAt     DateTime       @updatedAt
  refreshTokens RefreshToken[]
}

model RefreshToken {
  id        String   @id @default(uuid())
  token     String   @unique // The actual JWT refresh token
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  expiresAt DateTime
  revoked   Boolean  @default(false)
  revokedAt DateTime?
  ipAddress String?
  userAgent String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@index([userId])
  @@index([token])
  @@index([expiresAt])
  @@index([revoked])
}
```

#### Step 1.2: Create Migration

```bash
cd platform-services/backend/deepiri-auth-service
npx prisma migrate dev --name add_refresh_tokens
```

#### Step 1.3: Generate Prisma Client

```bash
npx prisma generate
```

**What this does:**
- Creates RefreshToken table in database
- Sets up relationship with User
- Adds indexes for performance
- Enables cascade delete (if user deleted, tokens deleted)

---

### Phase 2: JWT Utility Functions (Intermediate)

**Goal**: Create utilities for token creation and verification

#### Step 2.1: Create JWT Utilities

Create `src/utils/jwt.ts`:

```typescript
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const REFRESH_TOKEN_SECRET = process.env.REFRESH_TOKEN_SECRET || JWT_SECRET + '-refresh';
const ACCESS_TOKEN_EXPIRY = process.env.ACCESS_TOKEN_EXPIRY || '15m';
const REFRESH_TOKEN_EXPIRY = process.env.REFRESH_TOKEN_EXPIRY || '7d';

export interface AccessTokenPayload {
  userId: string;
  email: string;
  roles?: string[];
  iat?: number;
  exp?: number;
}

export interface RefreshTokenPayload {
  userId: string;
  tokenId: string; // Unique ID for this refresh token
  iat?: number;
  exp?: number;
}

/**
 * Sign an access token
 */
export function signAccessToken(payload: {
  userId: string;
  email: string;
  roles?: string[];
}): string {
  return jwt.sign(
    {
      userId: payload.userId,
      email: payload.email,
      roles: payload.roles || ['user'],
    },
    JWT_SECRET,
    {
      expiresIn: ACCESS_TOKEN_EXPIRY,
      issuer: 'deepiri-auth-service',
      audience: 'deepiri-api',
    }
  );
}

/**
 * Sign a refresh token
 */
export function signRefreshToken(userId: string): { token: string; tokenId: string } {
  const tokenId = uuidv4();
  const token = jwt.sign(
    {
      userId,
      tokenId,
    },
    REFRESH_TOKEN_SECRET,
    {
      expiresIn: REFRESH_TOKEN_EXPIRY,
      issuer: 'deepiri-auth-service',
      audience: 'deepiri-api',
    }
  );

  return { token, tokenId };
}

/**
 * Verify an access token
 */
export function verifyAccessToken(token: string): AccessTokenPayload {
  try {
    return jwt.verify(token, JWT_SECRET, {
      issuer: 'deepiri-auth-service',
      audience: 'deepiri-api',
    }) as AccessTokenPayload;
  } catch (error: any) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Access token expired');
    }
    if (error.name === 'JsonWebTokenError') {
      throw new Error('Invalid access token');
    }
    throw error;
  }
}

/**
 * Verify a refresh token
 */
export function verifyRefreshToken(token: string): RefreshTokenPayload {
  try {
    return jwt.verify(token, REFRESH_TOKEN_SECRET, {
      issuer: 'deepiri-auth-service',
      audience: 'deepiri-api',
    }) as RefreshTokenPayload;
  } catch (error: any) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Refresh token expired');
    }
    if (error.name === 'JsonWebTokenError') {
      throw new Error('Invalid refresh token');
    }
    throw error;
  }
}

/**
 * Get token expiration date
 */
export function getTokenExpiration(expiresIn: string): Date {
  const now = Date.now();
  let milliseconds = 0;

  if (expiresIn.endsWith('s')) {
    milliseconds = parseInt(expiresIn) * 1000;
  } else if (expiresIn.endsWith('m')) {
    milliseconds = parseInt(expiresIn) * 60 * 1000;
  } else if (expiresIn.endsWith('h')) {
    milliseconds = parseInt(expiresIn) * 60 * 60 * 1000;
  } else if (expiresIn.endsWith('d')) {
    milliseconds = parseInt(expiresIn) * 24 * 60 * 60 * 1000;
  }

  return new Date(now + milliseconds);
}
```

#### Step 2.2: Install Dependencies

```bash
npm install uuid
npm install --save-dev @types/uuid
```

**What this does:**
- Creates separate functions for access and refresh tokens
- Uses different secrets for access and refresh tokens
- Adds issuer and audience for extra security
- Provides clear error messages

---

### Phase 3: Refresh Token Service (Intermediate)

**Goal**: Create service to manage refresh tokens in database

#### Step 3.1: Create Refresh Token Service

Create `src/services/refreshTokenService.ts`:

```typescript
import prisma from '../db';
import { getTokenExpiration } from '../utils/jwt';

const REFRESH_TOKEN_EXPIRY = process.env.REFRESH_TOKEN_EXPIRY || '7d';

/**
 * Save a refresh token to the database
 */
export async function saveRefreshToken(
  userId: string,
  token: string,
  ipAddress?: string,
  userAgent?: string
) {
  const expiresAt = getTokenExpiration(REFRESH_TOKEN_EXPIRY);

  return prisma.refreshToken.create({
    data: {
      userId,
      token,
      expiresAt,
      ipAddress,
      userAgent,
    },
  });
}

/**
 * Find a refresh token by token string
 */
export async function findRefreshToken(token: string) {
  return prisma.refreshToken.findUnique({
    where: { token },
    include: {
      user: {
        select: {
          id: true,
          email: true,
          name: true,
          isActive: true,
        },
      },
    },
  });
}

/**
 * Revoke a refresh token
 */
export async function revokeRefreshToken(token: string) {
  return prisma.refreshToken.update({
    where: { token },
    data: {
      revoked: true,
      revokedAt: new Date(),
    },
  });
}

/**
 * Revoke all refresh tokens for a user
 */
export async function revokeAllUserTokens(userId: string) {
  return prisma.refreshToken.updateMany({
    where: {
      userId,
      revoked: false,
    },
    data: {
      revoked: true,
      revokedAt: new Date(),
    },
  });
}

/**
 * Delete expired refresh tokens (cleanup job)
 */
export async function deleteExpiredTokens() {
  return prisma.refreshToken.deleteMany({
    where: {
      expiresAt: {
        lt: new Date(),
      },
    },
  });
}

/**
 * Check if refresh token is valid
 */
export async function isRefreshTokenValid(token: string): Promise<{
  valid: boolean;
  reason?: string;
  tokenData?: any;
}> {
  const tokenData = await findRefreshToken(token);

  if (!tokenData) {
    return { valid: false, reason: 'Token not found' };
  }

  if (tokenData.revoked) {
    return { valid: false, reason: 'Token revoked' };
  }

  if (tokenData.expiresAt < new Date()) {
    return { valid: false, reason: 'Token expired' };
  }

  if (!tokenData.user.isActive) {
    return { valid: false, reason: 'User inactive' };
  }

  return { valid: true, tokenData };
}
```

**What this does:**
- Provides functions to manage refresh tokens
- Validates token existence, expiration, and revocation
- Supports bulk operations (revoke all, cleanup)

---

### Phase 4: Update Login Endpoint (Advanced)

**Goal**: Issue both access and refresh tokens on login

#### Step 4.1: Update Auth Service Login

Edit `src/authService.ts`:

```typescript
import { signAccessToken, signRefreshToken } from './utils/jwt';
import { saveRefreshToken } from './services/refreshTokenService';

class AuthService {
  async login(req: Request, res: Response): Promise<void> {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        res.status(400).json({ error: 'Email and password are required' });
        return;
      }

      const user = await prisma.user.findUnique({
        where: { email }
      });

      if (!user) {
        res.status(401).json({ error: 'Invalid credentials' });
        return;
      }

      const isValidPassword = await bcrypt.compare(password, user.password);
      if (!isValidPassword) {
        res.status(401).json({ error: 'Invalid credentials' });
        return;
      }

      if (!user.isActive) {
        res.status(403).json({ error: 'Account is deactivated' });
        return;
      }

      // Update last login
      await prisma.user.update({
        where: { id: user.id },
        data: { lastLoginAt: new Date() }
      });

      // Generate tokens
      const accessToken = signAccessToken({
        userId: user.id,
        email: user.email,
      });

      const { token: refreshToken } = signRefreshToken(user.id);

      // Save refresh token to database
      await saveRefreshToken(
        user.id,
        refreshToken,
        req.ip || undefined,
        req.get('user-agent') || undefined
      );

      // Set refresh token as httpOnly cookie
      res.cookie('refreshToken', refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
        path: '/api/auth',
      });

      // Return access token in response body
      res.json({
        success: true,
        accessToken,
        user: {
          id: user.id,
          email: user.email,
          name: user.name
        }
      });
    } catch (error: any) {
      console.error('Login error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
}
```

**What this does:**
- Issues short-lived access token (15 minutes)
- Issues long-lived refresh token (7 days)
- Stores refresh token in database
- Sets refresh token as httpOnly cookie
- Returns access token in response body

---

### Phase 5: Implement Refresh Endpoint (Expert)

**Goal**: Create endpoint to refresh access tokens with rotation

#### Step 5.1: Create Refresh Endpoint

Update `src/authService.ts`:

```typescript
import { verifyRefreshToken, signAccessToken, signRefreshToken } from './utils/jwt';
import { findRefreshToken, revokeRefreshToken, saveRefreshToken, isRefreshTokenValid } from './services/refreshTokenService';

class AuthService {
  async refresh(req: Request, res: Response): Promise<void> {
    try {
      // Get refresh token from cookie or body
      const refreshToken = req.cookies?.refreshToken || req.body.refreshToken;

      if (!refreshToken) {
        res.status(401).json({ error: 'No refresh token provided' });
        return;
      }

      // Verify JWT signature and expiration
      let decoded;
      try {
        decoded = verifyRefreshToken(refreshToken);
      } catch (error: any) {
        if (error.message === 'Refresh token expired') {
          res.status(401).json({ error: 'Refresh token expired' });
          return;
        }
        res.status(401).json({ error: 'Invalid refresh token' });
        return;
      }

      // Check if token exists in database and is valid
      const validation = await isRefreshTokenValid(refreshToken);
      if (!validation.valid) {
        res.status(401).json({ error: validation.reason || 'Invalid refresh token' });
        return;
      }

      const tokenData = validation.tokenData!;
      const user = tokenData.user;

      // TOKEN ROTATION: Revoke old refresh token
      await revokeRefreshToken(refreshToken);

      // Generate new tokens
      const newAccessToken = signAccessToken({
        userId: user.id,
        email: user.email,
      });

      const { token: newRefreshToken } = signRefreshToken(user.id);

      // Save new refresh token to database
      await saveRefreshToken(
        user.id,
        newRefreshToken,
        req.ip || undefined,
        req.get('user-agent') || undefined
      );

      // Set new refresh token as httpOnly cookie
      res.cookie('refreshToken', newRefreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
        path: '/api/auth',
      });

      // Return new access token
      res.json({
        success: true,
        accessToken: newAccessToken,
      });
    } catch (error: any) {
      console.error('Refresh error:', error);
      res.status(401).json({ error: 'Invalid refresh token' });
    }
  }
}
```

**What this does:**
- Accepts refresh token from cookie or body
- Verifies JWT signature and expiration
- Validates token in database
- **Rotates tokens**: Revokes old, creates new
- Returns new access token
- Sets new refresh token as cookie

---

### Phase 6: Theft Detection (Master Level)

**Goal**: Detect if old refresh token is reused (indicates theft)

#### Step 6.1: Add Theft Detection

Update `src/services/refreshTokenService.ts`:

```typescript
/**
 * Check if refresh token was already used (theft detection)
 */
export async function detectTokenTheft(token: string): Promise<{
  isTheft: boolean;
  shouldRevokeAll: boolean;
}> {
  const tokenData = await findRefreshToken(token);

  if (!tokenData) {
    // Token not found - might be old revoked token
    return { isTheft: false, shouldRevokeAll: false };
  }

  if (tokenData.revoked) {
    // Token was already used (rotated) - this is theft!
    return { isTheft: true, shouldRevokeAll: true };
  }

  return { isTheft: false, shouldRevokeAll: false };
}
```

Update `src/authService.ts` refresh method:

```typescript
async refresh(req: Request, res: Response): Promise<void> {
  try {
    const refreshToken = req.cookies?.refreshToken || req.body.refreshToken;

    if (!refreshToken) {
      res.status(401).json({ error: 'No refresh token provided' });
      return;
    }

    // Verify JWT
    let decoded;
    try {
      decoded = verifyRefreshToken(refreshToken);
    } catch (error: any) {
      res.status(401).json({ error: 'Invalid refresh token' });
      return;
    }

    // THEFT DETECTION: Check if token was already used
    const theftCheck = await detectTokenTheft(refreshToken);
    if (theftCheck.isTheft) {
      // Token was already rotated - possible theft!
      // Revoke all tokens for this user
      await revokeAllUserTokens(decoded.userId);
      
      // Log security event
      console.error('SECURITY ALERT: Refresh token reuse detected', {
        userId: decoded.userId,
        ip: req.ip,
        userAgent: req.get('user-agent'),
      });

      res.status(401).json({
        error: 'Security violation detected. Please log in again.',
      });
      return;
    }

    // Validate token
    const validation = await isRefreshTokenValid(refreshToken);
    if (!validation.valid) {
      res.status(401).json({ error: validation.reason || 'Invalid refresh token' });
      return;
    }

    const tokenData = validation.tokenData!;
    const user = tokenData.user;

    // Rotate tokens
    await revokeRefreshToken(refreshToken);

    const newAccessToken = signAccessToken({
      userId: user.id,
      email: user.email,
    });

    const { token: newRefreshToken } = signRefreshToken(user.id);

    await saveRefreshToken(
      user.id,
      newRefreshToken,
      req.ip || undefined,
      req.get('user-agent') || undefined
    );

    res.cookie('refreshToken', newRefreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000,
      path: '/api/auth',
    });

    res.json({
      success: true,
      accessToken: newAccessToken,
    });
  } catch (error: any) {
    console.error('Refresh error:', error);
    res.status(401).json({ error: 'Invalid refresh token' });
  }
}
```

**What this does:**
- Detects if old refresh token is reused
- If theft detected, revokes all user tokens
- Logs security event
- Forces user to log in again

---

### Phase 7: Update Logout Endpoint (Advanced)

**Goal**: Revoke refresh token on logout

#### Step 7.1: Update Logout Method

Update `src/authService.ts`:

```typescript
async logout(req: Request, res: Response): Promise<void> {
  try {
    const refreshToken = req.cookies?.refreshToken || req.body.refreshToken;

    if (refreshToken) {
      // Revoke refresh token
      await revokeRefreshToken(refreshToken);
    }

    // Clear refresh token cookie
    res.clearCookie('refreshToken', {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      path: '/api/auth',
    });

    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error: any) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}
```

**What this does:**
- Revokes refresh token in database
- Clears refresh token cookie
- Prevents token reuse after logout

---

### Phase 8: Update Authentication Middleware (Expert)

**Goal**: Handle token expiration gracefully

#### Step 8.1: Create Enhanced Auth Middleware

Create `src/middleware/authenticateToken.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { verifyAccessToken } from '../utils/jwt';

export function authenticateToken(
  req: Request,
  res: Response,
  next: NextFunction
) {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        error: 'No token provided',
        code: 'NO_TOKEN',
      });
      return;
    }

    const token = authHeader.substring(7);
    
    try {
      const decoded = verifyAccessToken(token);
      
      // Attach user to request
      (req as any).user = {
        id: decoded.userId,
        userId: decoded.userId,
        email: decoded.email,
        roles: decoded.roles || ['user'],
      };

      next();
    } catch (error: any) {
      if (error.message === 'Access token expired') {
        res.status(401).json({
          error: 'Token expired',
          code: 'TOKEN_EXPIRED',
          // Client can use this to trigger refresh
        });
        return;
      }
      
      res.status(401).json({
        error: 'Invalid token',
        code: 'INVALID_TOKEN',
      });
    }
  } catch (error: any) {
    res.status(500).json({
      error: 'Authentication error',
      code: 'AUTH_ERROR',
    });
  }
}
```

**What this does:**
- Verifies access token
- Handles expiration with clear error codes
- Attaches user to request object
- Provides error codes for client handling

---

## Advanced Implementation

### Advanced Feature 1: Sliding Window Refresh

Allow refresh token to be used within a grace period after rotation:

```typescript
// In refreshTokenService.ts
export async function isRefreshTokenValidWithGracePeriod(
  token: string,
  gracePeriodMs: number = 24 * 60 * 60 * 1000 // 24 hours
): Promise<{
  valid: boolean;
  reason?: string;
  tokenData?: any;
}> {
  const tokenData = await findRefreshToken(token);

  if (!tokenData) {
    return { valid: false, reason: 'Token not found' };
  }

  // Check if revoked but within grace period
  if (tokenData.revoked && tokenData.revokedAt) {
    const timeSinceRevocation = Date.now() - tokenData.revokedAt.getTime();
    if (timeSinceRevocation <= gracePeriodMs) {
      // Still valid within grace period
      return { valid: true, tokenData };
    }
    return { valid: false, reason: 'Token revoked' };
  }

  // ... rest of validation
}
```

### Advanced Feature 2: Device Tracking

Track devices and allow per-device token management:

```prisma
model RefreshToken {
  // ... existing fields
  deviceId    String?
  deviceName  String?
  deviceType  String? // 'mobile', 'desktop', 'tablet'
}
```

```typescript
// On login
await saveRefreshToken(
  user.id,
  refreshToken,
  req.ip,
  req.get('user-agent'),
  deviceId, // Extract from header or generate
  deviceName,
  deviceType
);

// List user's devices
export async function getUserDevices(userId: string) {
  return prisma.refreshToken.findMany({
    where: {
      userId,
      revoked: false,
      expiresAt: { gt: new Date() },
    },
    select: {
      deviceId: true,
      deviceName: true,
      deviceType: true,
      ipAddress: true,
      createdAt: true,
    },
  });
}

// Revoke specific device
export async function revokeDeviceToken(userId: string, deviceId: string) {
  return prisma.refreshToken.updateMany({
    where: {
      userId,
      deviceId,
      revoked: false,
    },
    data: {
      revoked: true,
      revokedAt: new Date(),
    },
  });
}
```

### Advanced Feature 3: Rate Limiting on Refresh

Prevent refresh token abuse:

```typescript
import rateLimit from 'express-rate-limit';

const refreshRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 refresh attempts per 15 minutes
  message: 'Too many refresh attempts. Please try again later.',
  keyGenerator: (req) => {
    const token = req.cookies?.refreshToken || req.body.refreshToken;
    if (token) {
      try {
        const decoded = verifyRefreshToken(token);
        return decoded.userId; // Rate limit per user
      } catch {
        return req.ip; // Fallback to IP
      }
    }
    return req.ip;
  },
});

// Apply to refresh endpoint
router.post('/refresh', refreshRateLimiter, authService.refresh);
```

### Advanced Feature 4: Token Family Tracking

Track token families to detect token reuse across devices:

```prisma
model RefreshToken {
  // ... existing fields
  familyId     String? // All tokens from same login share familyId
}
```

```typescript
// On login, create family
const familyId = uuidv4();

// Save token with familyId
await saveRefreshToken(userId, refreshToken, ip, userAgent, familyId);

// On refresh, reuse same familyId
await saveRefreshToken(userId, newRefreshToken, ip, userAgent, tokenData.familyId);

// Detect if token from different family is used
if (tokenData.familyId !== expectedFamilyId) {
  // Possible theft - revoke all tokens in family
  await revokeTokenFamily(tokenData.familyId);
}
```

### Advanced Feature 5: Automatic Token Cleanup

Scheduled job to clean up expired tokens:

```typescript
// src/jobs/cleanupTokens.ts
import { deleteExpiredTokens } from '../services/refreshTokenService';

export async function cleanupExpiredTokens() {
  try {
    const result = await deleteExpiredTokens();
    console.log(`Cleaned up ${result.count} expired tokens`);
  } catch (error) {
    console.error('Token cleanup error:', error);
  }
}

// Run every hour
setInterval(cleanupExpiredTokens, 60 * 60 * 1000);
```

---

## Token Rotation Strategies

### Strategy 1: Rotate on Every Refresh (Recommended)

**How it works:**
- Every refresh request issues new refresh token
- Old refresh token is immediately revoked
- If old token is used, theft is detected

**Pros:**
- Maximum security
- Immediate theft detection
- Forward secrecy

**Cons:**
- Slightly more complex
- More database writes

**Implementation:** (Already implemented in Phase 5)

### Strategy 2: Reuse Detection

**How it works:**
- Old refresh token can be used once more (grace period)
- If used again, revoke all tokens
- Allows for network issues/race conditions

**Pros:**
- Handles race conditions
- Better UX (network retries work)

**Cons:**
- Slightly less secure
- More complex logic

**Implementation:**
```typescript
// Track token usage count
model RefreshToken {
  usageCount Int @default(0)
}

// On refresh
if (tokenData.usageCount > 0) {
  // Token was already used - theft!
  await revokeAllUserTokens(userId);
  return error;
}

// Increment usage count
await prisma.refreshToken.update({
  where: { token },
  data: { usageCount: { increment: 1 } },
});
```

### Strategy 3: Sliding Window

**How it works:**
- Old refresh token valid for 24 hours after rotation
- After 24 hours, old token is invalid
- Allows for device synchronization issues

**Pros:**
- Handles device sync issues
- Better for mobile apps

**Cons:**
- Less secure (longer window)
- More complex

**Implementation:** (See Advanced Feature 1)

### Strategy 4: No Rotation (Not Recommended)

**How it works:**
- Refresh token is reused until expiration
- No rotation

**Pros:**
- Simple
- Fewer database writes

**Cons:**
- No theft detection
- Stolen token valid until expiration
- Less secure

**When to use:** Only for low-security applications

---

## Testing & Security

### Unit Tests

Create `src/__tests__/jwt.test.ts`:

```typescript
import { signAccessToken, verifyAccessToken, signRefreshToken, verifyRefreshToken } from '../utils/jwt';

describe('JWT Utilities', () => {
  it('should sign and verify access token', () => {
    const payload = { userId: '123', email: 'test@example.com' };
    const token = signAccessToken(payload);
    const decoded = verifyAccessToken(token);
    
    expect(decoded.userId).toBe('123');
    expect(decoded.email).toBe('test@example.com');
  });

  it('should throw error for expired token', async () => {
    // Set short expiration
    process.env.ACCESS_TOKEN_EXPIRY = '1s';
    
    const token = signAccessToken({ userId: '123', email: 'test@example.com' });
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    expect(() => verifyAccessToken(token)).toThrow('Access token expired');
  });
});
```

### Integration Tests

```typescript
import request from 'supertest';
import app from '../server';

describe('Token Refresh', () => {
  it('should refresh access token', async () => {
    // Login
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'password' });
    
    const { accessToken, refreshToken } = loginRes.body;
    
    // Refresh
    const refreshRes = await request(app)
      .post('/api/auth/refresh')
      .set('Cookie', `refreshToken=${refreshToken}`);
    
    expect(refreshRes.status).toBe(200);
    expect(refreshRes.body.accessToken).toBeDefined();
    expect(refreshRes.body.accessToken).not.toBe(accessToken);
  });

  it('should reject reused refresh token', async () => {
    // Login and get refresh token
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'password' });
    
    const { refreshToken } = loginRes.body;
    
    // Use refresh token first time
    await request(app)
      .post('/api/auth/refresh')
      .set('Cookie', `refreshToken=${refreshToken}`);
    
    // Try to use same refresh token again (should fail)
    const refreshRes = await request(app)
      .post('/api/auth/refresh')
      .set('Cookie', `refreshToken=${refreshToken}`);
    
    expect(refreshRes.status).toBe(401);
  });
});
```

### Security Checklist

- [ ] Access tokens expire in 15 minutes or less
- [ ] Refresh tokens expire in 7-30 days
- [ ] Refresh tokens stored in database
- [ ] Refresh tokens can be revoked
- [ ] Token rotation implemented
- [ ] Theft detection implemented
- [ ] Refresh tokens in httpOnly cookies
- [ ] Secure flag set in production
- [ ] SameSite protection enabled
- [ ] Different secrets for access and refresh tokens
- [ ] Token validation includes user status check
- [ ] Rate limiting on refresh endpoint
- [ ] Logging of security events
- [ ] Cleanup of expired tokens

---

## Troubleshooting

### Common Issues

#### Issue 1: Refresh Token Not Sent

**Symptoms**: Refresh endpoint returns "No refresh token provided"

**Solutions:**
1. Check cookie settings (httpOnly, secure, sameSite)
2. Verify cookie path matches endpoint path
3. Check CORS settings allow credentials
4. Verify client sends cookie with request

#### Issue 2: Token Rotation Causes Issues

**Symptoms**: Client gets 401 after refresh

**Solutions:**
1. Ensure client updates stored refresh token
2. Check for race conditions (multiple simultaneous refreshes)
3. Verify old token is properly revoked
4. Consider grace period for old tokens

#### Issue 3: Theft Detection Too Aggressive

**Symptoms**: Legitimate users getting logged out

**Solutions:**
1. Implement grace period
2. Check for race conditions
3. Verify token storage in client
4. Add logging to debug false positives

#### Issue 4: Cookies Not Working

**Symptoms**: Refresh token not in cookies

**Solutions:**
1. Check httpOnly, secure, sameSite settings
2. Verify CORS credentials: true
3. Check cookie path
4. Test in browser (not just API client)

#### Issue 5: Token Expiration Issues

**Symptoms**: Tokens expire too quickly or not at all

**Solutions:**
1. Verify JWT_SECRET is set correctly
2. Check token expiration settings
3. Verify system clock is synchronized
4. Check token payload for exp claim

### Debugging Tips

#### Enable Debug Logging

```typescript
// In jwt.ts
export function verifyAccessToken(token: string): AccessTokenPayload {
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as AccessTokenPayload;
    console.log('Token verified:', { userId: decoded.userId, exp: decoded.exp });
    return decoded;
  } catch (error: any) {
    console.error('Token verification failed:', error.name, error.message);
    throw error;
  }
}
```

#### Check Token Contents

```typescript
// Decode without verification (for debugging)
const decoded = jwt.decode(token);
console.log('Token payload:', decoded);
```

#### Monitor Database

```sql
-- Check active refresh tokens
SELECT * FROM "RefreshToken" 
WHERE "revoked" = false 
AND "expiresAt" > NOW();

-- Check revoked tokens
SELECT * FROM "RefreshToken" 
WHERE "revoked" = true 
ORDER BY "revokedAt" DESC 
LIMIT 10;
```

---

## Conclusion

You've now learned how to implement comprehensive JWT token refresh and rotation in your authentication service. From basic token issuance to advanced theft detection, you have the tools to build a secure, production-ready authentication system.

### Key Takeaways

1. **Separate Tokens**: Use short-lived access tokens and long-lived refresh tokens
2. **Store Refresh Tokens**: Database storage enables revocation and theft detection
3. **Rotate Tokens**: Issue new refresh token on each refresh, revoke old one
4. **Detect Theft**: Monitor for token reuse to detect compromise
5. **Secure Storage**: Use httpOnly cookies for refresh tokens
6. **Handle Errors**: Provide clear error codes for client handling

### Next Steps

1. Implement database schema (Phase 1)
2. Create JWT utilities (Phase 2)
3. Build refresh token service (Phase 3)
4. Update login endpoint (Phase 4)
5. Implement refresh endpoint (Phase 5)
6. Add theft detection (Phase 6)
7. Update logout (Phase 7)
8. Test thoroughly
9. Monitor in production
10. Tune expiration times based on usage

### Resources

- [JWT.io](https://jwt.io/) - JWT debugger and documentation
- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [RFC 7519 - JSON Web Token](https://tools.ietf.org/html/rfc7519)
- [Prisma Documentation](https://www.prisma.io/docs/)

---

**Happy Token Management!**




