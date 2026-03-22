export enum EnvironmentType {
  DEVELOPMENT = 'development',
  STAGING = 'staging',
  PRODUCTION = 'production',
}

export enum SecretType {
  PASSWORD = 'password',
  API_KEY = 'api_key',
  TOKEN = 'token',
  URL = 'url',
  JWT = 'jwt',
}

export interface SecretConfig {
  DATABASE_URL?: string;
  POSTGRES_PASSWORD?: string;
  MONGO_URI?: string;
  REDIS_PASSWORD?: string;
  REDIS_URL?: string;
  JWT_SECRET?: string;
  CYREX_API_KEY?: string;
  OPENAI_API_KEY?: string;
  MINIO_ROOT_USER?: string;
  MINIO_ROOT_PASSWORD?: string;
  INFLUXDB_TOKEN?: string;
  INFLUXDB_PASSWORD?: string;
  VAPID_PRIVATE_KEY?: string;
  VAPID_PUBLIC_KEY?: string;
  _required?: string[];
}

export interface ValidationError {
  field: string;
  message: string;
  severity: 'error' | 'warning';
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
  warnings: ValidationError[];
}
