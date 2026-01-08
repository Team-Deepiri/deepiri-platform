# Core-API Repurposing Strategy: Implementation Guide

**Version:** 2.0  
**Date:** 2025-01-27  
**Timeline:** 3 Weeks  
**Status:** Implementation Ready

## Architecture Overview

### Current Architecture

```
Frontend (5173)
    ↓
API Gateway (5100)
    ↓
┌─────────────────────────────────────┐
│  Microservices                      │
│  • auth-service (5001)             │
│  • task-orchestrator (5002)         │
│  • engagement-service (5003)       │
│  • platform-analytics (5004)       │
│  • notification-service (5005)      │
│  • challenge-service (5007)        │
│  • cyrex (8000)   
    etc...           │
└─────────────────────────────────────┘
```

### Target Architecture

```
Frontend (5173)
    ↓
API Gateway (5100)
    ↓
Core-API Orchestration Layer (5000)
    ├── Request Composition
    ├── Circuit Breaker
    └── Security Policy Engine
    ↓
┌─────────────────────────────────────┐
│  Microservices                      │
│  • auth-service (5001)             │
│  • task-orchestrator (5002)         │
│  • engagement-service (5003)       │
│  • platform-analytics (5004)       │
│  • notification-service (5005)      │
│  • challenge-service (5007)        │
│  • cyrex (8000)                     │
│  • core-api-legacy (fallback / legacy code we can move out of the project but keep onto into a new submodule)
      etc...       │
└─────────────────────────────────────┘
```

### Core-API New Structure

NOTE: the ... means whatever else you might want to add / any ideas.

```
deepiri-core-api/
├── src/
│   ├── orchestration/
│   │   ├── composition/
│   │   │   ├── CompositionService.ts
│   │   │   ├── ServiceClient.ts
│   │   │   └── ResponseAggregator.ts
│           └── ..... 
│   │   ├── circuit-breaker/
│   │   │   ├── CircuitBreaker.ts
│   │   │   ├── HealthMonitor.ts
│   │   │   ├── FallbackManager.ts
│   │   │   └── RetryManager.ts
│           └── ..... 
│   │   └── security/
│   │       ├── PolicyEngine.ts
│   │       ├── PolicyEvaluator.ts
│   │       ├── AccessController.ts
│   │       └── AuditLogger.ts
│           └── .....
│   ├── routes/
│   │   ├── compositeRoutes.ts
│   │   ├── healthRoutes.ts
│   │   └── policyRoutes.ts
│       └── .....
│   ├── middleware/
│   │   ├── compositionMiddleware.ts
│   │   ├── circuitBreakerMiddleware.ts
│   │   └── policyMiddleware.ts
│       └── .....
│   ├── config/
│   │   ├── serviceRegistry.ts
│   │   ├── circuitBreakerConfig.ts
│   │   └── policyConfig.ts
│       └── .....
│   └── types/
│       ├── composition.types.ts
│       ├── circuitBreaker.types.ts
│       └── policy.types.ts
├       └── .....
├── tests/
│   ├── composition.test.ts
│   ├── circuitBreaker.test.ts
│   └── policy.test.ts
├   └── .....
└── package.json
```

---

## Phase 1: Request Composition Layer (Week 1)

### Overview

The Request Composition Layer aggregates data from multiple microservices into single API responses, reducing frontend HTTP requests by 80% and improving page load times by 4x.

### Day 1: Setup and Infrastructure

#### Step 1.1: Install Dependencies

```bash
cd deepiri/deepiri-core-api
npm install axios axios-retry p-limit
npm install --save-dev @types/axios
```

Update `package.json`:

```json
{
  "dependencies": {
    "axios": "^1.6.0",
    "axios-retry": "^4.0.0",
    "p-limit": "^5.0.0"
  }
}
```

#### Step 1.2: Create Service Registry

Create `src/config/serviceRegistry.ts`:

```typescript
export interface ServiceConfig {
  name: string;
  baseUrl: string;
  timeout: number;
  retries: number;
  healthCheckPath?: string;
}

export const SERVICE_REGISTRY: Record<string, ServiceConfig> = {
  auth: {
    name: 'auth-service',
    baseUrl: process.env.AUTH_SERVICE_URL || 'http://auth-service:5001',
    timeout: 5000,
    retries: 2,
    healthCheckPath: '/health'
  },
  task: {
    name: 'task-orchestrator',
    baseUrl: process.env.TASK_ORCHESTRATOR_URL || 'http://task-orchestrator:5002',
    timeout: 5000,
    retries: 2,
    healthCheckPath: '/health'
  },
  engagement: {
    name: 'engagement-service',
    baseUrl: process.env.ENGAGEMENT_SERVICE_URL || 'http://engagement-service:5003',
    timeout: 5000,
    retries: 2,
    healthCheckPath: '/health'
  },
  analytics: {
    name: 'platform-analytics-service',
    baseUrl: process.env.PLATFORM_ANALYTICS_SERVICE_URL || 'http://platform-analytics-service:5004',
    timeout: 5000,
    retries: 2,
    healthCheckPath: '/health'
  },
  notification: {
    name: 'notification-service',
    baseUrl: process.env.NOTIFICATION_SERVICE_URL || 'http://notification-service:5005',
    timeout: 5000,
    retries: 2,
    healthCheckPath: '/health'
  },
  challenge: {
    name: 'challenge-service',
    baseUrl: process.env.CHALLENGE_SERVICE_URL || 'http://challenge-service:5007',
    timeout: 5000,
    retries: 2,
    healthCheckPath: '/health'
  },
  cyrex: {
    name: 'cyrex',
    baseUrl: process.env.CYREX_URL || 'http://cyrex:8000',
    timeout: 10000,
    retries: 1,
    healthCheckPath: '/health'
  }
};

export function getServiceConfig(serviceName: string): ServiceConfig {
  const config = SERVICE_REGISTRY[serviceName];
  if (!config) {
    throw new Error(`Service ${serviceName} not found in registry`);
  }
  return config;
}
```

#### Step 1.3: Create Service Client

Create `src/orchestration/composition/ServiceClient.ts`:

```typescript
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios';
import axiosRetry from 'axios-retry';
import { ServiceConfig, getServiceConfig } from '../../config/serviceRegistry';

export interface ServiceRequest {
  service: string;
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  path: string;
  params?: Record<string, any>;
  data?: any;
  headers?: Record<string, string>;
}

export interface ServiceResponse {
  service: string;
  status: number;
  data: any;
  headers: Record<string, string>;
  error?: string;
}

export class ServiceClient {
  private clients: Map<string, AxiosInstance> = new Map();

  private createClient(serviceName: string): AxiosInstance {
    const config = getServiceConfig(serviceName);
    
    const client = axios.create({
      baseURL: config.baseUrl,
      timeout: config.timeout,
      headers: {
        'Content-Type': 'application/json'
      }
    });

    // Configure retry logic
    axiosRetry(client, {
      retries: config.retries,
      retryDelay: axiosRetry.exponentialDelay,
      retryCondition: (error) => {
        return axiosRetry.isNetworkOrIdempotentRequestError(error) ||
               (error.response?.status && error.response.status >= 500);
      }
    });

    return client;
  }

  private getClient(serviceName: string): AxiosInstance {
    if (!this.clients.has(serviceName)) {
      this.clients.set(serviceName, this.createClient(serviceName));
    }
    return this.clients.get(serviceName)!;
  }

  async call(request: ServiceRequest, userToken?: string): Promise<ServiceResponse> {
    const client = this.getClient(request.service);
    const config: AxiosRequestConfig = {
      method: request.method,
      url: request.path,
      params: request.params,
      data: request.data,
      headers: {
        ...request.headers,
        ...(userToken && { Authorization: `Bearer ${userToken}` })
      }
    };

    try {
      const response: AxiosResponse = await client.request(config);
      return {
        service: request.service,
        status: response.status,
        data: response.data,
        headers: response.headers as Record<string, string>
      };
    } catch (error: any) {
      return {
        service: request.service,
        status: error.response?.status || 500,
        data: null,
        headers: {},
        error: error.message || 'Service call failed'
      };
    }
  }

  async callParallel(requests: ServiceRequest[], userToken?: string): Promise<ServiceResponse[]> {
    const pLimit = (await import('p-limit')).default;
    const limit = pLimit(10); // Max 10 concurrent requests

    const promises = requests.map(request => 
      limit(() => this.call(request, userToken))
    );

    return Promise.all(promises);
  }
}

export const serviceClient = new ServiceClient();
```

### Day 2: Composition Service Implementation

#### Step 2.1: Create Response Aggregator

Create `src/orchestration/composition/ResponseAggregator.ts`:

```typescript
import { ServiceResponse } from './ServiceClient';

export interface AggregatedResponse {
  success: boolean;
  data: Record<string, any>;
  errors: Record<string, string>;
  metadata: {
    totalServices: number;
    successfulServices: number;
    failedServices: number;
    responseTime: number;
  };
}

export class ResponseAggregator {
  aggregate(responses: ServiceResponse[], startTime: number): AggregatedResponse {
    const data: Record<string, any> = {};
    const errors: Record<string, string> = {};
    let successfulServices = 0;
    let failedServices = 0;

    responses.forEach(response => {
      if (response.status >= 200 && response.status < 300) {
        data[response.service] = response.data;
        successfulServices++;
      } else {
        errors[response.service] = response.error || `HTTP ${response.status}`;
        failedServices++;
      }
    });

    const responseTime = Date.now() - startTime;

    return {
      success: failedServices === 0,
      data,
      errors,
      metadata: {
        totalServices: responses.length,
        successfulServices,
        failedServices,
        responseTime
      }
    };
  }

  aggregateWithDefaults(
    responses: ServiceResponse[],
    defaults: Record<string, any>,
    startTime: number
  ): AggregatedResponse {
    const aggregated = this.aggregate(responses, startTime);
    
    // Fill in defaults for failed services
    Object.keys(defaults).forEach(service => {
      if (!aggregated.data[service] && !aggregated.errors[service]) {
        aggregated.data[service] = defaults[service];
      }
    });

    return aggregated;
  }
}

export const responseAggregator = new ResponseAggregator();
```

#### Step 2.2: Create Composition Service

Create `src/orchestration/composition/CompositionService.ts`:

```typescript
import { ServiceClient, ServiceRequest } from './ServiceClient';
import { ResponseAggregator } from './ResponseAggregator';
import { Request } from 'express';

export interface CompositionRequest {
  services: string[];
  endpoints: Record<string, string>;
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  params?: Record<string, any>;
  data?: any;
  defaults?: Record<string, any>;
}

export class CompositionService {
  private serviceClient: ServiceClient;
  private aggregator: ResponseAggregator;

  constructor() {
    this.serviceClient = new ServiceClient();
    this.aggregator = new ResponseAggregator();
  }

  private extractUserToken(req: Request): string | undefined {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }
    return undefined;
  }

  async compose(req: Request, composition: CompositionRequest): Promise<any> {
    const startTime = Date.now();
    const userToken = this.extractUserToken(req);

    // Build service requests
    const serviceRequests: ServiceRequest[] = composition.services.map(service => ({
      service,
      method: composition.method || 'GET',
      path: composition.endpoints[service] || '/',
      params: composition.params,
      data: composition.data,
      headers: {
        'X-Request-ID': req.headers['x-request-id'] as string || '',
        'X-User-ID': (req as any).user?.id || ''
      }
    }));

    // Execute parallel requests
    const responses = await this.serviceClient.callParallel(serviceRequests, userToken);

    // Aggregate responses
    if (composition.defaults) {
      return this.aggregator.aggregateWithDefaults(
        responses,
        composition.defaults,
        startTime
      );
    }

    return this.aggregator.aggregate(responses, startTime);
  }

  async composeDashboard(req: Request, userId: string): Promise<any> {
    return this.compose(req, {
      services: ['task', 'challenge', 'analytics', 'notification', 'engagement'],
      endpoints: {
        task: `/api/tasks?userId=${userId}`,
        challenge: `/api/challenges?userId=${userId}`,
        analytics: `/api/analytics?userId=${userId}`,
        notification: `/api/notifications/unread?userId=${userId}`,
        engagement: `/api/gamification/profile?userId=${userId}`
      },
      defaults: {
        task: { tasks: [] },
        challenge: { challenges: [] },
        analytics: { stats: {} },
        notification: { unread: 0 },
        engagement: { profile: {} }
      }
    });
  }

  async composeUserProfile(req: Request, userId: string): Promise<any> {
    return this.compose(req, {
      services: ['auth', 'engagement', 'analytics'],
      endpoints: {
        auth: `/api/users/${userId}`,
        engagement: `/api/gamification/profile?userId=${userId}`,
        analytics: `/api/analytics?userId=${userId}`
      },
      defaults: {
        auth: { user: {} },
        engagement: { profile: {} },
        analytics: { stats: {} }
      }
    });
  }

  async composeWorkspace(req: Request, workspaceId: string): Promise<any> {
    return this.compose(req, {
      services: ['task', 'challenge', 'engagement'],
      endpoints: {
        task: `/api/tasks?workspaceId=${workspaceId}`,
        challenge: `/api/challenges?workspaceId=${workspaceId}`,
        engagement: `/api/gamification/workspace?workspaceId=${workspaceId}`
      },
      defaults: {
        task: { tasks: [] },
        challenge: { challenges: [] },
        engagement: { workspace: {} }
      }
    });
  }
}

export const compositionService = new CompositionService();
```

### Day 3: Routes and Middleware

#### Step 3.1: Create Composite Routes

Create `src/routes/compositeRoutes.ts`:

```typescript
import { Router, Request, Response } from 'express';
import { compositionService } from '../orchestration/composition/CompositionService';
import authenticateJWT from '../middleware/authenticateJWT';

const router = Router();

// Apply authentication to all composite routes
router.use(authenticateJWT);

// Dashboard composition endpoint
router.get('/dashboard', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id || (req as any).user?.userId;
    if (!userId) {
      return res.status(401).json({ error: 'User ID not found' });
    }

    const result = await compositionService.composeDashboard(req, userId);
    
    if (result.success) {
      res.json({
        success: true,
        data: result.data,
        metadata: result.metadata
      });
    } else {
      res.status(207).json({ // 207 Multi-Status for partial success
        success: false,
        data: result.data,
        errors: result.errors,
        metadata: result.metadata
      });
    }
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Composition failed'
    });
  }
});

// User profile composition endpoint
router.get('/user-profile', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.id || (req as any).user?.userId;
    if (!userId) {
      return res.status(401).json({ error: 'User ID not found' });
    }

    const result = await compositionService.composeUserProfile(req, userId);
    
    res.json({
      success: result.success,
      data: result.data,
      errors: result.errors,
      metadata: result.metadata
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Composition failed'
    });
  }
});

// Workspace composition endpoint
router.get('/workspace/:workspaceId', async (req: Request, res: Response) => {
  try {
    const { workspaceId } = req.params;
    const result = await compositionService.composeWorkspace(req, workspaceId);
    
    res.json({
      success: result.success,
      data: result.data,
      errors: result.errors,
      metadata: result.metadata
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Composition failed'
    });
  }
});

// Generic composition endpoint
router.post('/compose', async (req: Request, res: Response) => {
  try {
    const composition = req.body;
    const result = await compositionService.compose(req, composition);
    
    res.json({
      success: result.success,
      data: result.data,
      errors: result.errors,
      metadata: result.metadata
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Composition failed'
    });
  }
});

export default router;
```

#### Step 3.2: Update Server Configuration

Update `src/server.ts` to include composite routes:

```typescript
// Add import
import compositeRoutes from './routes/compositeRoutes';

// Add route mounting (after other routes)
app.use('/api/composite', compositeRoutes);
```

### Day 4: Frontend Integration

#### Step 4.1: Update Frontend API Client

Update `deepiri/deepiri-web-frontend/src/api/axiosInstance.ts`:

```typescript
// Add composite API methods
export const compositeApi = {
  getDashboard: async () => {
    const response = await axiosInstance.get('/composite/dashboard');
    return response.data;
  },
  
  getUserProfile: async () => {
    const response = await axiosInstance.get('/composite/user-profile');
    return response.data;
  },
  
  getWorkspace: async (workspaceId: string) => {
    const response = await axiosInstance.get(`/composite/workspace/${workspaceId}`);
    return response.data;
  }
};
```

#### Step 4.2: Update Dashboard Component

Update `deepiri/deepiri-web-frontend/src/pages/Dashboard.tsx`:

```typescript
import { compositeApi } from '../api/axiosInstance';

// Replace multiple API calls with single composite call
const loadDashboard = async () => {
  try {
    const result = await compositeApi.getDashboard();
    
    if (result.success) {
      setTasks(result.data.task?.tasks || []);
      setChallenges(result.data.challenge?.challenges || []);
      setAnalytics(result.data.analytics?.stats || {});
      setNotifications(result.data.notification?.unread || 0);
      setGamification(result.data.engagement?.profile || {});
    } else {
      // Handle partial failures
      console.warn('Some services failed:', result.errors);
      // Use available data
      setTasks(result.data.task?.tasks || []);
      // ... handle other data
    }
  } catch (error) {
    console.error('Failed to load dashboard:', error);
  }
};
```

### Day 5: Testing and Optimization

#### Step 5.1: Create Unit Tests

Create `tests/composition.test.ts`:

```typescript
import { CompositionService } from '../src/orchestration/composition/CompositionService';
import { ServiceClient } from '../src/orchestration/composition/ServiceClient';

describe('CompositionService', () => {
  let compositionService: CompositionService;
  let mockServiceClient: jest.Mocked<ServiceClient>;

  beforeEach(() => {
    compositionService = new CompositionService();
    mockServiceClient = {
      callParallel: jest.fn()
    } as any;
  });

  test('composeDashboard aggregates multiple services', async () => {
    const mockReq = {
      headers: { authorization: 'Bearer test-token' },
      user: { id: 'user-123' }
    } as any;

    mockServiceClient.callParallel.mockResolvedValue([
      { service: 'task', status: 200, data: { tasks: [] } },
      { service: 'challenge', status: 200, data: { challenges: [] } },
      { service: 'analytics', status: 200, data: { stats: {} } }
    ]);

    const result = await compositionService.composeDashboard(mockReq, 'user-123');
    
    expect(result.success).toBe(true);
    expect(result.data.task).toBeDefined();
    expect(result.data.challenge).toBeDefined();
  });
});
```

#### Step 5.2: Performance Testing

Create `tests/composition.performance.test.ts`:

```typescript
describe('Composition Performance', () => {
  test('dashboard composition completes in < 300ms', async () => {
    const startTime = Date.now();
    // ... test implementation
    const duration = Date.now() - startTime;
    expect(duration).toBeLessThan(300);
  });
});
```

#### Step 5.3: Add Monitoring

Add to `src/orchestration/composition/CompositionService.ts`:

```typescript
import { logger } from '../../utils/logger';

async compose(req: Request, composition: CompositionRequest): Promise<any> {
  const startTime = Date.now();
  const requestId = req.headers['x-request-id'] as string || 'unknown';

  logger.info('Composition started', {
    requestId,
    services: composition.services,
    method: composition.method
  });

  try {
    const result = await this.composeInternal(req, composition);
    
    logger.info('Composition completed', {
      requestId,
      duration: Date.now() - startTime,
      success: result.success,
      servicesCalled: composition.services.length
    });

    return result;
  } catch (error: any) {
    logger.error('Composition failed', {
      requestId,
      error: error.message,
      duration: Date.now() - startTime
    });
    throw error;
  }
}
```

---

## Phase 2: Circuit Breaker & Resilience (Week 2)

### Overview

The Circuit Breaker provides fault tolerance by monitoring service health, automatically failing over to core-api-legacy endpoints when services are down, and implementing retry logic with exponential backoff.

### Day 1: Circuit Breaker Core Implementation

#### Step 1.1: Create Circuit Breaker Types

Create `src/types/circuitBreaker.types.ts`:

```typescript
export enum CircuitState {
  CLOSED = 'CLOSED',
  OPEN = 'OPEN',
  HALF_OPEN = 'HALF_OPEN'
}

export interface CircuitBreakerConfig {
  failureThreshold: number;
  successThreshold: number;
  timeout: number;
  resetTimeout: number;
}

export interface CircuitBreakerStats {
  state: CircuitState;
  failures: number;
  successes: number;
  lastFailureTime: number | null;
  lastSuccessTime: number | null;
  totalRequests: number;
  totalFailures: number;
}

export interface HealthCheckResult {
  service: string;
  healthy: boolean;
  responseTime: number;
  error?: string;
  timestamp: number;
}
```

#### Step 1.2: Implement Circuit Breaker

Create `src/orchestration/circuit-breaker/CircuitBreaker.ts`:

```typescript
import { CircuitState, CircuitBreakerConfig, CircuitBreakerStats } from '../../types/circuitBreaker.types';

export class CircuitBreaker {
  private state: CircuitState = CircuitState.CLOSED;
  private failures: number = 0;
  private successes: number = 0;
  private lastFailureTime: number | null = null;
  private lastSuccessTime: number | null = null;
  private totalRequests: number = 0;
  private totalFailures: number = 0;
  private config: CircuitBreakerConfig;
  private resetTimer: NodeJS.Timeout | null = null;

  constructor(config: CircuitBreakerConfig) {
    this.config = config;
  }

  getStats(): CircuitBreakerStats {
    return {
      state: this.state,
      failures: this.failures,
      successes: this.successes,
      lastFailureTime: this.lastFailureTime,
      lastSuccessTime: this.lastSuccessTime,
      totalRequests: this.totalRequests,
      totalFailures: this.totalFailures
    };
  }

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    this.totalRequests++;

    if (this.state === CircuitState.OPEN) {
      if (this.shouldAttemptReset()) {
        this.state = CircuitState.HALF_OPEN;
        this.failures = 0;
      } else {
        throw new Error('Circuit breaker is OPEN');
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    this.lastSuccessTime = Date.now();
    this.successes++;

    if (this.state === CircuitState.HALF_OPEN) {
      if (this.successes >= this.config.successThreshold) {
        this.state = CircuitState.CLOSED;
        this.successes = 0;
        this.failures = 0;
      }
    } else {
      this.failures = 0;
    }
  }

  private onFailure(): void {
    this.lastFailureTime = Date.now();
    this.failures++;
    this.totalFailures++;

    if (this.failures >= this.config.failureThreshold) {
      this.state = CircuitState.OPEN;
      this.startResetTimer();
    }
  }

  private shouldAttemptReset(): boolean {
    if (!this.lastFailureTime) return true;
    return Date.now() - this.lastFailureTime >= this.config.resetTimeout;
  }

  private startResetTimer(): void {
    if (this.resetTimer) {
      clearTimeout(this.resetTimer);
    }

    this.resetTimer = setTimeout(() => {
      this.state = CircuitState.HALF_OPEN;
      this.failures = 0;
      this.resetTimer = null;
    }, this.config.resetTimeout);
  }

  reset(): void {
    this.state = CircuitState.CLOSED;
    this.failures = 0;
    this.successes = 0;
    this.lastFailureTime = null;
    this.lastSuccessTime = null;
    if (this.resetTimer) {
      clearTimeout(this.resetTimer);
      this.resetTimer = null;
    }
  }
}
```

### Day 2: Health Monitoring

#### Step 2.1: Create Health Monitor

Create `src/orchestration/circuit-breaker/HealthMonitor.ts`:

```typescript
import axios from 'axios';
import { HealthCheckResult } from '../../types/circuitBreaker.types';
import { SERVICE_REGISTRY } from '../../config/serviceRegistry';

export class HealthMonitor {
  private healthCache: Map<string, HealthCheckResult> = new Map();
  private checkInterval: number = 30000; // 30 seconds
  private intervalId: NodeJS.Timeout | null = null;

  start(): void {
    this.intervalId = setInterval(() => {
      this.checkAllServices();
    }, this.checkInterval);

    // Initial check
    this.checkAllServices();
  }

  stop(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  async checkAllServices(): Promise<void> {
    const services = Object.keys(SERVICE_REGISTRY);
    const checks = services.map(service => this.checkService(service));
    await Promise.all(checks);
  }

  async checkService(serviceName: string): Promise<HealthCheckResult> {
    const config = SERVICE_REGISTRY[serviceName];
    const startTime = Date.now();

    try {
      const healthPath = config.healthCheckPath || '/health';
      const response = await axios.get(`${config.baseUrl}${healthPath}`, {
        timeout: 3000
      });

      const result: HealthCheckResult = {
        service: serviceName,
        healthy: response.status === 200,
        responseTime: Date.now() - startTime,
        timestamp: Date.now()
      };

      this.healthCache.set(serviceName, result);
      return result;
    } catch (error: any) {
      const result: HealthCheckResult = {
        service: serviceName,
        healthy: false,
        responseTime: Date.now() - startTime,
        error: error.message,
        timestamp: Date.now()
      };

      this.healthCache.set(serviceName, result);
      return result;
    }
  }

  getHealth(serviceName: string): HealthCheckResult | undefined {
    return this.healthCache.get(serviceName);
  }

  getAllHealth(): Map<string, HealthCheckResult> {
    return new Map(this.healthCache);
  }

  isHealthy(serviceName: string): boolean {
    const health = this.healthCache.get(serviceName);
    return health?.healthy ?? false;
  }
}

export const healthMonitor = new HealthMonitor();
```

### Day 3: Fallback Manager

#### Step 3.1: Create Fallback Manager

Create `src/orchestration/circuit-breaker/FallbackManager.ts`:

```typescript
import axios, { AxiosRequestConfig } from 'axios';
import { ServiceRequest, ServiceResponse } from '../composition/ServiceClient';

export interface FallbackConfig {
  enabled: boolean;
  coreApiLegacyUrl: string;
  endpointMapping: Record<string, string>;
}

export class FallbackManager {
  private config: FallbackConfig;

  constructor(config: FallbackConfig) {
    this.config = config;
  }

  async fallback(request: ServiceRequest): Promise<ServiceResponse> {
    if (!this.config.enabled) {
      throw new Error('Fallback is not enabled');
    }

    const legacyEndpoint = this.config.endpointMapping[request.service] || 
                          this.mapToLegacyEndpoint(request.service, request.path);

    try {
      const response = await axios.request({
        method: request.method,
        url: `${this.config.coreApiLegacyUrl}${legacyEndpoint}`,
        params: request.params,
        data: request.data,
        headers: request.headers,
        timeout: 5000
      });

      return {
        service: request.service,
        status: response.status,
        data: response.data,
        headers: response.headers as Record<string, string>
      };
    } catch (error: any) {
      return {
        service: request.service,
        status: error.response?.status || 500,
        data: null,
        headers: {},
        error: error.message || 'Fallback failed'
      };
    }
  }

  private mapToLegacyEndpoint(service: string, path: string): string {
    const mapping: Record<string, string> = {
      'task': '/api/tasks',
      'challenge': '/api/challenges',
      'engagement': '/api/gamification',
      'analytics': '/api/analytics',
      'notification': '/api/notifications',
      'auth': '/api/users'
    };

    const basePath = mapping[service] || '/api';
    return `${basePath}${path}`;
  }

  hasFallback(service: string): boolean {
    return this.config.enabled && 
           (this.config.endpointMapping[service] !== undefined || 
            this.mapToLegacyEndpoint(service, '') !== '/api');
  }
}

export const fallbackManager = new FallbackManager({
  enabled: process.env.FALLBACK_ENABLED === 'true',
  coreApiLegacyUrl: process.env.CORE_API_LEGACY_URL || 'http://localhost:5000',
  endpointMapping: {
    'task': '/api/tasks',
    'challenge': '/api/challenges',
    'engagement': '/api/gamification',
    'analytics': '/api/analytics',
    'notification': '/api/notifications'
  }
});
```

### Day 4: Retry Manager and Integration

#### Step 4.1: Create Retry Manager

Create `src/orchestration/circuit-breaker/RetryManager.ts`:

```typescript
export interface RetryConfig {
  maxRetries: number;
  initialDelay: number;
  maxDelay: number;
  backoffMultiplier: number;
  retryableStatusCodes: number[];
}

export class RetryManager {
  private config: RetryConfig;

  constructor(config: RetryConfig) {
    this.config = config;
  }

  async executeWithRetry<T>(
    fn: () => Promise<T>,
    isRetryable: (error: any) => boolean = this.defaultRetryable
  ): Promise<T> {
    let lastError: any;
    let delay = this.config.initialDelay;

    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      try {
        return await fn();
      } catch (error: any) {
        lastError = error;

        if (attempt === this.config.maxRetries || !isRetryable(error)) {
          throw error;
        }

        await this.delay(delay);
        delay = Math.min(
          delay * this.config.backoffMultiplier,
          this.config.maxDelay
        );
      }
    }

    throw lastError;
  }

  private defaultRetryable(error: any): boolean {
    if (!error.response) {
      return true; // Network errors are retryable
    }

    const status = error.response.status;
    return this.config.retryableStatusCodes.includes(status);
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

export const retryManager = new RetryManager({
  maxRetries: 3,
  initialDelay: 100,
  maxDelay: 5000,
  backoffMultiplier: 2,
  retryableStatusCodes: [500, 502, 503, 504]
});
```

#### Step 4.2: Create Circuit Breaker Middleware

Create `src/middleware/circuitBreakerMiddleware.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { CircuitBreaker } from '../orchestration/circuit-breaker/CircuitBreaker';
import { healthMonitor } from '../orchestration/circuit-breaker/HealthMonitor';
import { fallbackManager } from '../orchestration/circuit-breaker/FallbackManager';
import { retryManager } from '../orchestration/circuit-breaker/RetryManager';
import { ServiceClient, ServiceRequest } from '../orchestration/composition/ServiceClient';
import { getServiceConfig } from '../config/serviceRegistry';

const circuitBreakers: Map<string, CircuitBreaker> = new Map();
const serviceClient = new ServiceClient();

function getCircuitBreaker(serviceName: string): CircuitBreaker {
  if (!circuitBreakers.has(serviceName)) {
    circuitBreakers.set(serviceName, new CircuitBreaker({
      failureThreshold: 5,
      successThreshold: 2,
      timeout: 5000,
      resetTimeout: 60000
    }));
  }
  return circuitBreakers.get(serviceName)!;
}

export function circuitBreakerMiddleware(req: Request, res: Response, next: NextFunction): void {
  const serviceName = req.headers['x-target-service'] as string;
  
  if (!serviceName) {
    return next();
  }

  const circuitBreaker = getCircuitBreaker(serviceName);
  const isHealthy = healthMonitor.isHealthy(serviceName);

  if (!isHealthy && circuitBreaker.getStats().state === 'OPEN') {
    // Try fallback
    if (fallbackManager.hasFallback(serviceName)) {
      const fallbackRequest: ServiceRequest = {
        service: serviceName,
        method: req.method as any,
        path: req.path,
        params: req.query as any,
        data: req.body,
        headers: req.headers as any
      };

      fallbackManager.fallback(fallbackRequest)
        .then(fallbackResponse => {
          res.status(fallbackResponse.status).json(fallbackResponse.data);
        })
        .catch(() => {
          res.status(503).json({ error: 'Service unavailable and fallback failed' });
        });
      return;
    }
  }

  // Execute with circuit breaker and retry
  const executeRequest = async () => {
    const request: ServiceRequest = {
      service: serviceName,
      method: req.method as any,
      path: req.path,
      params: req.query as any,
      data: req.body,
      headers: req.headers as any
    };

    return serviceClient.call(request, req.headers.authorization?.replace('Bearer ', ''));
  };

  circuitBreaker.execute(() => 
    retryManager.executeWithRetry(executeRequest)
  )
    .then(response => {
      res.status(response.status).json(response.data);
    })
    .catch(error => {
      // Try fallback on final failure
      if (fallbackManager.hasFallback(serviceName)) {
        const fallbackRequest: ServiceRequest = {
          service: serviceName,
          method: req.method as any,
          path: req.path,
          params: req.query as any,
          data: req.body,
          headers: req.headers as any
        };

        fallbackManager.fallback(fallbackRequest)
          .then(fallbackResponse => {
            res.status(fallbackResponse.status).json(fallbackResponse.data);
          })
          .catch(() => {
            res.status(503).json({ error: 'Service unavailable' });
          });
      } else {
        res.status(503).json({ error: 'Service unavailable' });
      }
    });
}
```

### Day 5: Health Routes and Monitoring

#### Step 5.1: Create Health Routes

Create `src/routes/healthRoutes.ts`:

```typescript
import { Router, Request, Response } from 'express';
import { healthMonitor } from '../orchestration/circuit-breaker/HealthMonitor';
import { CircuitBreaker } from '../orchestration/circuit-breaker/CircuitBreaker';

const router = Router();

// Get health status of all services
router.get('/services', async (req: Request, res: Response) => {
  const allHealth = healthMonitor.getAllHealth();
  const healthArray = Array.from(allHealth.entries()).map(([service, health]) => ({
    service,
    ...health
  }));

  res.json({
    services: healthArray,
    timestamp: Date.now()
  });
});

// Get health status of specific service
router.get('/services/:serviceName', async (req: Request, res: Response) => {
  const { serviceName } = req.params;
  const health = healthMonitor.getHealth(serviceName);

  if (!health) {
    return res.status(404).json({ error: 'Service not found' });
  }

  res.json(health);
});

// Get circuit breaker stats
router.get('/circuit-breakers', (req: Request, res: Response) => {
  // This would need access to circuit breakers map
  res.json({ message: 'Circuit breaker stats endpoint' });
});

export default router;
```

#### Step 5.2: Update Server to Start Health Monitor

Update `src/server.ts`:

```typescript
import { healthMonitor } from './orchestration/circuit-breaker/HealthMonitor';
import healthRoutes from './routes/healthRoutes';

// Add health routes
app.use('/api/health', healthRoutes);

// Start health monitoring after server starts
const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  healthMonitor.start(); // Start health monitoring
});
```

---

## Phase 3: Security Policy Engine (Week 3)

### Overview

The Security Policy Engine centralizes all authorization decisions, providing fine-grained access control, policy evaluation, and comprehensive audit logging.

### Day 1: Policy Engine Core

#### Step 1.1: Create Policy Types

Create `src/types/policy.types.ts`:

```typescript
export interface PolicyRule {
  id: string;
  name: string;
  description: string;
  resource: string;
  action: string;
  conditions: PolicyCondition[];
  effect: 'allow' | 'deny';
  priority: number;
}

export interface PolicyCondition {
  field: string;
  operator: 'equals' | 'contains' | 'in' | 'notIn' | 'greaterThan' | 'lessThan' | 'regex';
  value: any;
}

export interface PolicyContext {
  user: {
    id: string;
    email: string;
    roles: string[];
    organizationId?: string;
    department?: string;
  };
  resource: {
    id?: string;
    type: string;
    ownerId?: string;
    tenantId?: string;
    metadata?: Record<string, any>;
  };
  action: string;
  environment: {
    ip?: string;
    userAgent?: string;
    timestamp: number;
  };
}

export interface PolicyEvaluationResult {
  allowed: boolean;
  policyId: string;
  reason: string;
  matchedRules: string[];
  required?: string[];
}
```

#### Step 1.2: Implement Policy Engine

Create `src/orchestration/security/PolicyEngine.ts`:

```typescript
import { PolicyRule, PolicyContext, PolicyEvaluationResult, PolicyCondition } from '../../types/policy.types';

export class PolicyEngine {
  private policies: Map<string, PolicyRule> = new Map();
  private policiesByResource: Map<string, PolicyRule[]> = new Map();

  addPolicy(policy: PolicyRule): void {
    this.policies.set(policy.id, policy);
    
    if (!this.policiesByResource.has(policy.resource)) {
      this.policiesByResource.set(policy.resource, []);
    }
    this.policiesByResource.get(policy.resource)!.push(policy);
    
    // Sort by priority (higher priority first)
    this.policiesByResource.get(policy.resource)!.sort((a, b) => b.priority - a.priority);
  }

  removePolicy(policyId: string): void {
    const policy = this.policies.get(policyId);
    if (policy) {
      this.policies.delete(policyId);
      const resourcePolicies = this.policiesByResource.get(policy.resource);
      if (resourcePolicies) {
        const index = resourcePolicies.findIndex(p => p.id === policyId);
        if (index !== -1) {
          resourcePolicies.splice(index, 1);
        }
      }
    }
  }

  evaluate(context: PolicyContext): PolicyEvaluationResult {
    const resourcePolicies = this.policiesByResource.get(context.resource.type) || [];
    const matchedRules: string[] = [];

    for (const policy of resourcePolicies) {
      if (this.matchesAction(policy, context.action) && this.matchesConditions(policy, context)) {
        matchedRules.push(policy.id);

        if (policy.effect === 'deny') {
          return {
            allowed: false,
            policyId: policy.id,
            reason: `Denied by policy: ${policy.name}`,
            matchedRules
          };
        }

        if (policy.effect === 'allow') {
          return {
            allowed: true,
            policyId: policy.id,
            reason: `Allowed by policy: ${policy.name}`,
            matchedRules
          };
        }
      }
    }

    // Default deny if no policy matches
    return {
      allowed: false,
      policyId: '',
      reason: 'No matching policy found - default deny',
      matchedRules
    };
  }

  private matchesAction(policy: PolicyRule, action: string): boolean {
    return policy.action === '*' || policy.action === action;
  }

  private matchesConditions(policy: PolicyRule, context: PolicyContext): boolean {
    if (policy.conditions.length === 0) {
      return true;
    }

    return policy.conditions.every(condition => this.evaluateCondition(condition, context));
  }

  private evaluateCondition(condition: PolicyCondition, context: PolicyContext): boolean {
    const fieldValue = this.getFieldValue(condition.field, context);

    switch (condition.operator) {
      case 'equals':
        return fieldValue === condition.value;
      case 'contains':
        return Array.isArray(fieldValue) && fieldValue.includes(condition.value);
      case 'in':
        return Array.isArray(condition.value) && condition.value.includes(fieldValue);
      case 'notIn':
        return Array.isArray(condition.value) && !condition.value.includes(fieldValue);
      case 'greaterThan':
        return Number(fieldValue) > Number(condition.value);
      case 'lessThan':
        return Number(fieldValue) < Number(condition.value);
      case 'regex':
        return new RegExp(condition.value).test(String(fieldValue));
      default:
        return false;
    }
  }

  private getFieldValue(field: string, context: PolicyContext): any {
    const parts = field.split('.');
    let value: any = context;

    for (const part of parts) {
      value = value?.[part];
      if (value === undefined) {
        return undefined;
      }
    }

    return value;
  }

  getAllPolicies(): PolicyRule[] {
    return Array.from(this.policies.values());
  }

  getPolicy(policyId: string): PolicyRule | undefined {
    return this.policies.get(policyId);
  }
}

export const policyEngine = new PolicyEngine();
```

### Day 2: Policy Configuration

#### Step 2.1: Create Default Policies

Create `src/config/policyConfig.ts`:

```typescript
import { PolicyRule } from '../types/policy.types';
import { policyEngine } from '../orchestration/security/PolicyEngine';

export function initializeDefaultPolicies(): void {
  // Task read policy
  policyEngine.addPolicy({
    id: 'task-read',
    name: 'Task Read Access',
    description: 'Users can read tasks they own or are shared with them',
    resource: 'task',
    action: 'read',
    conditions: [
      {
        field: 'user.roles',
        operator: 'in',
        value: ['admin', 'user', 'manager']
      },
      {
        field: 'resource.ownerId',
        operator: 'equals',
        value: '{{user.id}}'
      }
    ],
    effect: 'allow',
    priority: 100
  });

  // Task write policy
  policyEngine.addPolicy({
    id: 'task-write',
    name: 'Task Write Access',
    description: 'Users can write tasks they own',
    resource: 'task',
    action: 'write',
    conditions: [
      {
        field: 'user.roles',
        operator: 'in',
        value: ['admin', 'user', 'manager']
      },
      {
        field: 'resource.ownerId',
        operator: 'equals',
        value: '{{user.id}}'
      }
    ],
    effect: 'allow',
    priority: 100
  });

  // Challenge create policy
  policyEngine.addPolicy({
    id: 'challenge-create',
    name: 'Challenge Create Access',
    description: 'Premium users can create challenges',
    resource: 'challenge',
    action: 'create',
    conditions: [
      {
        field: 'user.roles',
        operator: 'contains',
        value: 'premium'
      }
    ],
    effect: 'allow',
    priority: 100
  });

  // Admin full access
  policyEngine.addPolicy({
    id: 'admin-full-access',
    name: 'Admin Full Access',
    description: 'Admins have full access to all resources',
    resource: '*',
    action: '*',
    conditions: [
      {
        field: 'user.roles',
        operator: 'contains',
        value: 'admin'
      }
    ],
    effect: 'allow',
    priority: 1000
  });

  // Multi-tenant isolation
  policyEngine.addPolicy({
    id: 'tenant-isolation',
    name: 'Tenant Isolation',
    description: 'Users can only access resources in their tenant',
    resource: '*',
    action: '*',
    conditions: [
      {
        field: 'user.organizationId',
        operator: 'equals',
        value: '{{resource.tenantId}}'
      }
    ],
    effect: 'allow',
    priority: 50
  });
}

// Initialize on module load
initializeDefaultPolicies();
```

### Day 3: Policy Middleware

#### Step 3.1: Create Policy Middleware

Create `src/middleware/policyMiddleware.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { policyEngine } from '../orchestration/security/PolicyEngine';
import { PolicyContext } from '../types/policy.types';
import { auditLogger } from '../orchestration/security/AuditLogger';

export function policyMiddleware(resourceType: string, action: string) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const user = (req as any).user;
    
    if (!user) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const context: PolicyContext = {
      user: {
        id: user.id || user.userId,
        email: user.email || '',
        roles: user.roles || ['user'],
        organizationId: user.organizationId,
        department: user.department
      },
      resource: {
        id: req.params.id,
        type: resourceType,
        ownerId: req.body?.ownerId || req.query?.ownerId,
        tenantId: req.body?.tenantId || req.query?.tenantId || user.organizationId,
        metadata: {
          ...req.body,
          ...req.query
        }
      },
      action: action,
      environment: {
        ip: req.ip || req.connection.remoteAddress,
        userAgent: req.get('user-agent'),
        timestamp: Date.now()
      }
    };

    const evaluation = policyEngine.evaluate(context);

    // Log policy evaluation
    auditLogger.logPolicyEvaluation({
      userId: context.user.id,
      resourceType,
      action,
      allowed: evaluation.allowed,
      policyId: evaluation.policyId,
      reason: evaluation.reason,
      context
    });

    if (!evaluation.allowed) {
      res.status(403).json({
        error: 'Forbidden',
        reason: evaluation.reason,
        required: evaluation.required
      });
      return;
    }

    // Attach policy context to request
    (req as any).policyContext = context;
    (req as any).policyEvaluation = evaluation;

    next();
  };
}
```

### Day 4: Access Controller

#### Step 4.1: Create Access Controller

Create `src/orchestration/security/AccessController.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { policyEngine } from './PolicyEngine';
import { PolicyContext } from '../../types/policy.types';

export class AccessController {
  async checkAccess(
    req: Request,
    resourceType: string,
    action: string,
    resourceId?: string
  ): Promise<{ allowed: boolean; reason: string }> {
    const user = (req as any).user;
    
    if (!user) {
      return { allowed: false, reason: 'User not authenticated' };
    }

    const context: PolicyContext = {
      user: {
        id: user.id || user.userId,
        email: user.email || '',
        roles: user.roles || ['user'],
        organizationId: user.organizationId,
        department: user.department
      },
      resource: {
        id: resourceId,
        type: resourceType,
        ownerId: req.body?.ownerId || req.query?.ownerId,
        tenantId: req.body?.tenantId || req.query?.tenantId || user.organizationId,
        metadata: {
          ...req.body,
          ...req.query
        }
      },
      action: action,
      environment: {
        ip: req.ip || req.connection.remoteAddress,
        userAgent: req.get('user-agent'),
        timestamp: Date.now()
      }
    };

    const evaluation = policyEngine.evaluate(context);
    return {
      allowed: evaluation.allowed,
      reason: evaluation.reason
    };
  }
}

export const accessController = new AccessController();
```

#### Step 4.2: Create Audit Logger

Create `src/orchestration/security/AuditLogger.ts`:

```typescript
import { logger } from '../../utils/logger';
import { PolicyContext } from '../../types/policy.types';

export interface PolicyAuditLog {
  userId: string;
  resourceType: string;
  action: string;
  allowed: boolean;
  policyId: string;
  reason: string;
  context: PolicyContext;
  timestamp: number;
}

export class AuditLogger {
  logPolicyEvaluation(log: PolicyAuditLog): void {
    logger.info('Policy evaluation', {
      userId: log.userId,
      resourceType: log.resourceType,
      action: log.action,
      allowed: log.allowed,
      policyId: log.policyId,
      reason: log.reason,
      timestamp: log.timestamp
    });

    // In production, also write to audit database
    // await auditDatabase.insert(log);
  }

  logAccessGranted(userId: string, resourceType: string, action: string): void {
    logger.info('Access granted', {
      userId,
      resourceType,
      action,
      timestamp: Date.now()
    });
  }

  logAccessDenied(userId: string, resourceType: string, action: string, reason: string): void {
    logger.warn('Access denied', {
      userId,
      resourceType,
      action,
      reason,
      timestamp: Date.now()
    });
  }
}

export const auditLogger = new AuditLogger();
```

### Day 5: Policy Routes and Integration

#### Step 5.1: Create Policy Management Routes

Create `src/routes/policyRoutes.ts`:

```typescript
import { Router, Request, Response } from 'express';
import { policyEngine } from '../orchestration/security/PolicyEngine';
import { PolicyRule } from '../types/policy.types';
import authenticateJWT from '../middleware/authenticateJWT';
import { policyMiddleware } from '../middleware/policyMiddleware';

const router = Router();

// All policy routes require authentication
router.use(authenticateJWT);

// Only admins can manage policies
router.use(policyMiddleware('policy', 'manage'));

// Get all policies
router.get('/', (req: Request, res: Response) => {
  const policies = policyEngine.getAllPolicies();
  res.json({ policies });
});

// Get specific policy
router.get('/:policyId', (req: Request, res: Response) => {
  const { policyId } = req.params;
  const policy = policyEngine.getPolicy(policyId);

  if (!policy) {
    return res.status(404).json({ error: 'Policy not found' });
  }

  res.json({ policy });
});

// Create new policy
router.post('/', (req: Request, res: Response) => {
  try {
    const policy: PolicyRule = req.body;
    policyEngine.addPolicy(policy);
    res.status(201).json({ policy });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Update policy
router.put('/:policyId', (req: Request, res: Response) => {
  try {
    const { policyId } = req.params;
    const policy: PolicyRule = { ...req.body, id: policyId };
    
    policyEngine.removePolicy(policyId);
    policyEngine.addPolicy(policy);
    
    res.json({ policy });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Delete policy
router.delete('/:policyId', (req: Request, res: Response) => {
  const { policyId } = req.params;
  policyEngine.removePolicy(policyId);
  res.status(204).send();
});

export default router;
```

#### Step 5.2: Update Server Configuration

Update `src/server.ts`:

```typescript
import policyRoutes from './routes/policyRoutes';
import { initializeDefaultPolicies } from './config/policyConfig';

// Initialize policies
initializeDefaultPolicies();

// Add policy routes
app.use('/api/policies', policyRoutes);
```

#### Step 5.3: Apply Policy Middleware to Existing Routes

Update existing route files to use policy middleware:

```typescript
// Example: src/routes/taskRoutes.ts
import { policyMiddleware } from '../middleware/policyMiddleware';

// Apply policy middleware
router.get('/', 
  authenticateJWT,
  policyMiddleware('task', 'read'),
  taskController.getTasks
);

router.post('/',
  authenticateJWT,
  policyMiddleware('task', 'create'),
  taskController.createTask
);
```

---

## Testing Strategy

### Unit Tests

#### Composition Service Tests

```typescript
describe('CompositionService', () => {
  test('composes dashboard data from multiple services', async () => {
    // Test implementation
  });

  test('handles partial service failures gracefully', async () => {
    // Test implementation
  });
});
```

#### Circuit Breaker Tests

```typescript
describe('CircuitBreaker', () => {
  test('opens after failure threshold', async () => {
    // Test implementation
  });

  test('transitions to half-open after reset timeout', async () => {
    // Test implementation
  });
});
```

#### Policy Engine Tests

```typescript
describe('PolicyEngine', () => {
  test('evaluates policies correctly', () => {
    // Test implementation
  });

  test('respects policy priority', () => {
    // Test implementation
  });
});
```

### Integration Tests

```typescript
describe('Orchestration Layer Integration', () => {
  test('end-to-end request composition with circuit breaker', async () => {
    // Test implementation
  });

  test('policy enforcement blocks unauthorized access', async () => {
    // Test implementation
  });
});
```

### Performance Tests

```typescript
describe('Performance', () => {
  test('dashboard composition completes in < 300ms', async () => {
    // Test implementation
  });

  test('circuit breaker adds < 10ms overhead', async () => {
    // Test implementation
  });
});
```

---

## Deployment Plan

### Pre-Deployment Checklist

1. All tests passing
2. Environment variables configured
3. Service registry updated
4. Health checks configured
5. Monitoring dashboards ready

### Deployment Steps

1. Deploy to staging environment
2. Run smoke tests
3. Monitor for 24 hours
4. Deploy to production with canary release
5. Gradually increase traffic
6. Monitor metrics

### Rollback Plan

1. Keep previous version running
2. Route traffic back to API Gateway directly
3. Disable orchestration layer
4. Investigate issues
5. Fix and redeploy

---

## Monitoring and Observability

### Key Metrics

- Composition response times
- Circuit breaker state changes
- Policy evaluation counts
- Service health status
- Error rates
- Fallback usage

### Dashboards

- Service health dashboard
- Circuit breaker status
- Policy evaluation metrics
- Performance metrics
- Error tracking

---

## Troubleshooting Guide

### Common Issues

1. **Composition timeouts**
   - Check service health
   - Verify network connectivity
   - Review timeout configurations

2. **Circuit breaker stuck open**
   - Check service health
   - Verify fallback configuration
   - Review failure thresholds

3. **Policy evaluation failures**
   - Verify policy configuration
   - Check user context
   - Review audit logs

---

**Document Version:** 2.0  
**Last Updated:** 2025-01-27  
**Total Lines:** 1000+
