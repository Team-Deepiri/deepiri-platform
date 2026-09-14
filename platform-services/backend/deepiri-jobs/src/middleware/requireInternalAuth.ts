import { NextFunction, Request, Response } from 'express';
import { secureLog } from '@team-deepiri/shared-utils';

/**
 * Requires the internal service secret on internal endpoints. The secret is
 * read at request time (not module load) so dotenv.config() has already run.
 *
 * Fail-closed: if the secret is not configured in production, every request is
 * rejected with 500 instead of silently passing through unauthenticated.
 */
export function requireInternalAuth(req: Request, res: Response, next: NextFunction): void {
  const internalSecret = process.env.INTERNAL_SERVICE_SECRET?.trim() || '';
  if (!internalSecret) {
    if (process.env.NODE_ENV === 'production') {
      secureLog('error', 'INTERNAL_SERVICE_SECRET is not configured; rejecting job request');
      res.status(500).json({ error: 'Internal service secret is not configured' });
      return;
    }
    return next();
  }

  const provided = (req.headers['x-internal-secret'] as string) || (req.headers['x-api-key'] as string) || '';
  if (provided !== internalSecret) {
    res.status(401).json({ error: 'Invalid or missing internal secret' });
    return;
  }
  next();
}