import { EnvironmentType } from '../types';
import { WEAK_TOKENS, MIN_JWT_LENGTH, MIN_TOKEN_LENGTH } from '../constants';

export class TokenValidator {
  private readonly environment: EnvironmentType;

  constructor(environment?: EnvironmentType) {
    this.environment = environment || this.detectEnvironment();
  }

  validateJwt(secret: string, fieldName: string): string {
    if (this.environment === EnvironmentType.DEVELOPMENT) {
      return secret;
    }

    if (!secret) {
      throw new Error(
        `${fieldName}: JWT secret is required in ${this.environment} environment. ` +
        'Generate with: openssl rand -base64 48'
      );
    }

    if (WEAK_TOKENS.has(secret.toLowerCase())) {
      throw new Error(
        `${fieldName}: '${secret}' is a known weak secret. ` +
        'Generate with: openssl rand -base64 48'
      );
    }

    if (secret.length < MIN_JWT_LENGTH) {
      throw new Error(
        `${fieldName}: JWT secret must be at least ${MIN_JWT_LENGTH} characters ` +
        `(got ${secret.length}). Generate with: openssl rand -base64 48`
      );
    }

    return secret;
  }

  validateToken(token: string, fieldName: string): string {
    if (this.environment === EnvironmentType.DEVELOPMENT) {
      return token;
    }

    if (!token) {
      throw new Error(
        `${fieldName}: Token is required in ${this.environment} environment.`
      );
    }

    if (token.length < MIN_TOKEN_LENGTH) {
      throw new Error(
        `${fieldName}: Token must be at least ${MIN_TOKEN_LENGTH} characters ` +
        `(got ${token.length}).`
      );
    }

    return token;
  }

  private detectEnvironment(): EnvironmentType {
    const env = process.env.NODE_ENV || process.env.ENVIRONMENT || 'development';
    const normalized = env.toLowerCase();
    if (normalized === 'production' || normalized === 'prod') return EnvironmentType.PRODUCTION;
    if (normalized === 'staging' || normalized === 'stage') return EnvironmentType.STAGING;
    return EnvironmentType.DEVELOPMENT;
  }
}
