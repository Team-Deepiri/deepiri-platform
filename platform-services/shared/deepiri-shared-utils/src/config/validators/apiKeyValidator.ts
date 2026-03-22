import { EnvironmentType } from '../types';
import { WEAK_API_KEYS, MIN_API_KEY_LENGTH } from '../constants';

export class ApiKeyValidator {
  private readonly environment: EnvironmentType;

  constructor(environment?: EnvironmentType) {
    this.environment = environment || this.detectEnvironment();
  }

  validate(apiKey: string | null, fieldName: string, required = false): string | null {
    if (this.environment === EnvironmentType.DEVELOPMENT) {
      return apiKey;
    }

    if (required && !apiKey) {
      throw new Error(
        `${fieldName}: API key is required in ${this.environment} environment.`
      );
    }

    if (!apiKey) {
      return null;
    }

    if (WEAK_API_KEYS.has(apiKey.toLowerCase())) {
      throw new Error(
        `${fieldName}: '${apiKey}' is a placeholder value, not a real API key.`
      );
    }

    if (apiKey.length < MIN_API_KEY_LENGTH) {
      throw new Error(
        `${fieldName}: API key must be at least ${MIN_API_KEY_LENGTH} characters ` +
        `(got ${apiKey.length}).`
      );
    }

    return apiKey;
  }

  private detectEnvironment(): EnvironmentType {
    const env = process.env.NODE_ENV || process.env.ENVIRONMENT || 'development';
    const normalized = env.toLowerCase();
    if (normalized === 'production' || normalized === 'prod') return EnvironmentType.PRODUCTION;
    if (normalized === 'staging' || normalized === 'stage') return EnvironmentType.STAGING;
    return EnvironmentType.DEVELOPMENT;
  }
}
