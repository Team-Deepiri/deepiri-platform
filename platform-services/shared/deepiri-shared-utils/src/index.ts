/**
 * Shared Utilities for Deepiri Microservices
 * Export all shared utilities from this module
 */
import { createLogger } from './logger';
import winston from 'winston';
export { createLogger };
export const logger: winston.Logger = createLogger('shared-utils');
export { StreamingClient, StreamTopics } from './streaming/StreamingClient';
export type { StreamEvent } from './streaming/StreamingClient';
export { secureLog } from './secureLogger';
export { validateSecret, validateDatabaseUrl } from './config/secrets';
// Config/validation exports
export {
  SecretValidator,
  createSecretValidator,
  PasswordValidator,
  ApiKeyValidator,
  TokenValidator,
  UrlValidator,
  EnvironmentType,
  SecretType,
} from './config';
export type {
  SecretConfig,
  ValidationResult,
  ValidationError,
} from './config';
// Auth & Cache Utilities
export { hashApiKey } from './cryptoUtils';
export { createRedisClient } from './redisClient';
export type { ApiKeyScope, ApiKeyCachePayload } from './types';
