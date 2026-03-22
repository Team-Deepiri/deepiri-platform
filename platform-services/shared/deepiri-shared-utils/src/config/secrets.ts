import { config } from 'dotenv';

config();

/** interface SecretsConfig {
  jwtSecret: string;
  databaseUrl: string;
  redisUrl: string;
  apiKeys: {
    openai?: string;
    [key: string]: string | undefined;
  };
} */

export function validateSecret(name: string, value: string | undefined, minLength: number = 32): string {
  if (!value) {
    throw new Error(
      `${name} must be set in environment variables. ` +
      'This is required for security.'
    );
  }
  
  if (value.length < minLength) {
    throw new Error(
      `${name} must be at least ${minLength} characters long. ` +
      `Current length: ${value.length}`
    );
  }

  // Check for common weak secrets
  const weakSecrets = ['secret', 'password', 'changeme', 'default'];
  if (weakSecrets.some(weak => value.toLowerCase().includes(weak))) {
    throw new Error(
      `${name} appears to be a weak secret. Please use a strong, randomly generated secret.`
    );
  }

  return value;
}

export function validateDatabaseUrl(url: string | undefined): string {
  if (!url) {
    throw new Error('DATABASE_URL must be set in environment variables');
  }

  // Validate URL format
  try {
    const parsed = new URL(url);
    if (!parsed.protocol.startsWith('postgres')) {
      throw new Error('DATABASE_URL must be a PostgreSQL connection string');
    }
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Invalid DATABASE_URL format: ${error.message}`);
    }

    throw new Error('Invalid DATABASE_URL format');
  }

  return url;
}

//Disabled for now, since shared-utils does not have access to .env
/** export const secrets: SecretsConfig = {
  jwtSecret: validateSecret('JWT_SECRET', process.env.JWT_SECRET, 32),
  databaseUrl: validateDatabaseUrl(process.env.DATABASE_URL),
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  apiKeys: {
    openai: process.env.OPENAI_API_KEY,
    // Add other API keys as needed
  },
};

// Log secret configuration status (without values)
secureLog('info', 'Secrets configuration:');
secureLog('info', `- JWT Secret: ${secrets.jwtSecret ? '✓ Set' : '✗ Missing'}`);
secureLog('info', `- Database URL: ${secrets.databaseUrl ? '✓ Set' : '✗ Missing'}`);
secureLog('info', `- Redis URL: ${secrets.redisUrl ? '✓ Set' : '✗ Missing'}`); */