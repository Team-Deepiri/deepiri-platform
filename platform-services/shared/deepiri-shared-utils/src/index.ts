/**
 * Shared Utilities for Deepiri Microservices
 * Export all shared utilities from this module
 */
import { createLogger } from './logger';
import winston from 'winston';

export { createLogger };
export const logger: winston.Logger = createLogger('shared-utils'); // Default logger instance
export { StreamingClient, StreamTopics } from './streaming/StreamingClient';
export type { StreamEvent } from './streaming/StreamingClient';

