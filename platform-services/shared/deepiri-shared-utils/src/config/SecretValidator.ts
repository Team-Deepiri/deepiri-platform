import { EnvironmentType, SecretConfig, ValidationResult, ValidationError } from './types';
import { PasswordValidator } from './validators/passwordValidator';
import { ApiKeyValidator } from './validators/apiKeyValidator';
import { TokenValidator } from './validators/tokenValidator';
import { UrlValidator } from './validators/urlValidator';

type ValidatorFn = (value: string | undefined, field: string) => void;

const PASSWORD_FIELDS = ['POSTGRES_PASSWORD', 'REDIS_PASSWORD', 'MINIO_ROOT_PASSWORD', 'INFLUXDB_PASSWORD'];
const API_KEY_FIELDS = ['CYREX_API_KEY', 'OPENAI_API_KEY'];
const JWT_FIELDS = ['JWT_SECRET'];
const TOKEN_FIELDS = ['INFLUXDB_TOKEN', 'VAPID_PRIVATE_KEY', 'VAPID_PUBLIC_KEY'];
const URL_FIELDS = ['DATABASE_URL', 'REDIS_URL', 'MONGO_URI'];

export class SecretValidator {
  private readonly passwordValidator: PasswordValidator;
  private readonly apiKeyValidator: ApiKeyValidator;
  private readonly tokenValidator: TokenValidator;
  private readonly urlValidator: UrlValidator;

  constructor(environment?: EnvironmentType) {
    this.passwordValidator = new PasswordValidator(environment);
    this.apiKeyValidator = new ApiKeyValidator(environment);
    this.tokenValidator = new TokenValidator(environment);
    this.urlValidator = new UrlValidator(environment);
  }

  validatePassword(password: string, fieldName: string): string {
    return this.passwordValidator.validate(password, fieldName);
  }

  validateApiKey(key: string | null, fieldName: string, required = false): string | null {
    return this.apiKeyValidator.validate(key, fieldName, required);
  }

  validateJwt(secret: string, fieldName: string): string {
    return this.tokenValidator.validateJwt(secret, fieldName);
  }

  validateToken(token: string, fieldName: string): string {
    return this.tokenValidator.validateToken(token, fieldName);
  }

  validateUrl(url: string, fieldName: string, requireHttps = false): string {
    return this.urlValidator.validate(url, fieldName, requireHttps);
  }

  validateAll(config: Partial<SecretConfig>): ValidationResult {
    const errors: ValidationError[] = [];
    const warnings: ValidationError[] = [];

    const fieldValidators: Record<string, ValidatorFn> = {};

    for (const field of PASSWORD_FIELDS) {
      fieldValidators[field] = (v, f) => {
        if (v !== undefined && v !== null) this.passwordValidator.validate(v, f);
      };
    }

    for (const field of API_KEY_FIELDS) {
      fieldValidators[field] = (v, f) => {
        if (v !== undefined && v !== null) this.apiKeyValidator.validate(v, f);
      };
    }

    for (const field of JWT_FIELDS) {
      fieldValidators[field] = (v, f) => {
        if (v !== undefined && v !== null) this.tokenValidator.validateJwt(v, f);
      };
    }

    for (const field of TOKEN_FIELDS) {
      fieldValidators[field] = (v, f) => {
        if (v !== undefined && v !== null) this.tokenValidator.validateToken(v, f);
      };
    }

    for (const field of URL_FIELDS) {
      fieldValidators[field] = (v, f) => {
        if (v !== undefined && v !== null) this.urlValidator.validate(v, f);
      };
    }

    for (const [field, value] of Object.entries(config)) {
      if (field.startsWith('_')) continue;

      const validator = fieldValidators[field];
      if (!validator) continue;

      try {
        validator(value as string | undefined, field);
      } catch (err) {
        errors.push({
          field,
          message: err instanceof Error ? err.message : String(err),
          severity: 'error',
        });
      }
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings,
    };
  }
}

export function createSecretValidator(environment?: EnvironmentType): SecretValidator {
  return new SecretValidator(environment);
}
