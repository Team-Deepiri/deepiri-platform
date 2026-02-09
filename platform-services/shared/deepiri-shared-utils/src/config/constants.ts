export const WEAK_PASSWORDS = new Set([
  'password',
  'admin',
  'deepiripassword',
  'redispassword',
  'minioadmin',
  'adminpassword',
  'change-me',
  'default',
  'postgres',
  'root',
  'test',
  'dev',
  'development',
  'secret',
  'pass',
  'qwerty',
  'letmein',
  'welcome',
  '123456',
]);

export const WEAK_API_KEYS = new Set([
  'change-me',
  'your-api-key-here',
  'your_api_key',
  'api_key_here',
]);

export const WEAK_TOKENS = new Set([
  'default-secret-change-in-production',
  'your-jwt-secret-here',
]);

export const MIN_PASSWORD_LENGTH = 12;
export const MIN_API_KEY_LENGTH = 20;
export const MIN_JWT_LENGTH = 32;
export const MIN_TOKEN_LENGTH = 48;
