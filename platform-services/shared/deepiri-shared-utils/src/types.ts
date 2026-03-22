/**
 * Shared contract types for API Key authentication and caching.
 */

export type ApiKeyScope = 'ingestion:write' | 'analytics:read' | 'admin:all';

export interface ApiKeyCachePayload {
  serviceAccountId: string;
  ownerId:          string;
  scopes:           ApiKeyScope[];
  label:            string;
}