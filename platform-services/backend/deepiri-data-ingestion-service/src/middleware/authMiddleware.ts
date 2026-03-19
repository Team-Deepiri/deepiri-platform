import { Request, Response, NextFunction } from 'express';
import { config } from '../config/environment';
import { logger } from '../utils/logger';

/**
 * Validates that the request carries a valid ingestion:write API key scope.
 * In production the API Gateway forwards x-api-key and x-user-id headers
 * after validating them against the auth-service. This middleware performs
 * a lightweight check that the required headers are present.
 */
export function requireIngestionScope(req: Request, res: Response, next: NextFunction): void {
  const apiKey = req.headers['x-api-key'] as string | undefined;
  const userId = req.headers['x-user-id'] as string | undefined;

  if (!userId) {
    res.status(401).json({ error: 'Missing x-user-id header' });
    return;
  }

  if (!apiKey && config.nodeEnv !== 'production') {
    (req as any).userId = userId;
    next();
    return;
  }

  if (!apiKey) {
    res.status(401).json({ error: 'Missing x-api-key header' });
    return;
  }

  (req as any).userId = userId;
  logger.debug('Ingestion request authorised', { userId });
  next();
}
