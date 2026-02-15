import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';

// Auth is handled by API Gateway
// This middleware just extracts user context from headers
export interface AuthUser {
  id: string;
  email?: string;
  organizationId?: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export function authenticate(req: Request, res: Response, next: NextFunction): void {
  try {
    // API Gateway sets these headers after validating JWT
    const userId = req.headers['x-user-id'] as string;
    const userEmail = req.headers['x-user-email'] as string | undefined;
    const organizationId = req.headers['x-organization-id'] as string | undefined;

    if (!userId) {
      throw new UnauthorizedError('User ID not found in request headers');
    }

    req.user = {
      id: userId,
      email: userEmail,
      organizationId,
    };

    next();
  } catch (error: any) {
    if (error instanceof UnauthorizedError) {
      res.status(401).json({ error: error.message });
      return;
    }
    next(error);
  }
}

