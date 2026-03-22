import { EnvironmentType } from '../types';
import { WEAK_PASSWORDS, MIN_PASSWORD_LENGTH } from '../constants';

export class PasswordValidator {
  private readonly environment: EnvironmentType;

  constructor(environment?: EnvironmentType) {
    this.environment = environment || this.detectEnvironment();
  }

  validate(password: string, fieldName: string): string {
    if (this.environment === EnvironmentType.DEVELOPMENT) {
      return password;
    }

    if (!password) {
      throw new Error(
        `${fieldName}: Password is required in ${this.environment} environment. ` +
        'Generate with: openssl rand -base64 32'
      );
    }

    if (WEAK_PASSWORDS.has(password.toLowerCase())) {
      throw new Error(
        `${fieldName}: '${password}' is a known weak password. ` +
        'Generate a secure password with: openssl rand -base64 32'
      );
    }

    if (password.length < MIN_PASSWORD_LENGTH) {
      throw new Error(
        `${fieldName}: Password must be at least ${MIN_PASSWORD_LENGTH} characters ` +
        `(got ${password.length}). Generate with: openssl rand -base64 32`
      );
    }

    if (this.environment === EnvironmentType.PRODUCTION) {
      this.validateComplexity(password, fieldName);
    }

    return password;
  }

  private validateComplexity(password: string, fieldName: string): void {
    const checks: Record<string, boolean> = {
      uppercase: /[A-Z]/.test(password),
      lowercase: /[a-z]/.test(password),
      digit: /\d/.test(password),
      special: /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?`~]/.test(password),
    };

    const missing = Object.entries(checks)
      .filter(([, passed]) => !passed)
      .map(([name]) => name);

    if (missing.length > 0) {
      throw new Error(
        `${fieldName}: Production password must contain ${missing.join(', ')}. ` +
        'Generate with: openssl rand -base64 32'
      );
    }
  }

  private detectEnvironment(): EnvironmentType {
    const env = process.env.NODE_ENV || process.env.ENVIRONMENT || 'development';
    const normalized = env.toLowerCase();

    if (normalized === 'production' || normalized === 'prod') {
      return EnvironmentType.PRODUCTION;
    }
    if (normalized === 'staging' || normalized === 'stage') {
      return EnvironmentType.STAGING;
    }
    return EnvironmentType.DEVELOPMENT;
  }
}
