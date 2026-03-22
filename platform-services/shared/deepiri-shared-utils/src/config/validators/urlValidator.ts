import { EnvironmentType } from '../types';

export class UrlValidator {
  private readonly environment: EnvironmentType;

  constructor(environment?: EnvironmentType) {
    this.environment = environment || this.detectEnvironment();
  }

  validate(url: string, fieldName: string, requireHttps = false): string {
    if (!url) {
      throw new Error(`${fieldName}: URL is required`);
    }

    let parsed: URL;
    try {
      parsed = new URL(url);
    } catch {
      throw new Error(`${fieldName}: Invalid URL format for '${url}'`);
    }

    if (requireHttps &&
        this.environment === EnvironmentType.PRODUCTION &&
        parsed.protocol !== 'https:') {
      throw new Error(
        `${fieldName}: HTTPS is required in production (got ${parsed.protocol.replace(':', '')}). ` +
        'Update your URL to use https://'
      );
    }

    return url;
  }

  private detectEnvironment(): EnvironmentType {
    const env = process.env.NODE_ENV || process.env.ENVIRONMENT || 'development';
    const normalized = env.toLowerCase();
    if (normalized === 'production' || normalized === 'prod') return EnvironmentType.PRODUCTION;
    if (normalized === 'staging' || normalized === 'stage') return EnvironmentType.STAGING;
    return EnvironmentType.DEVELOPMENT;
  }
}
