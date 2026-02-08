import { SecretValidator, createSecretValidator } from '../SecretValidator';
import { EnvironmentType } from '../types';

describe('SecretValidator', () => {
  describe('factory function', () => {
    it('creates a validator instance', () => {
      const validator = createSecretValidator(EnvironmentType.DEVELOPMENT);
      expect(validator).toBeInstanceOf(SecretValidator);
    });
  });

  describe('Development Environment', () => {
    const validator = createSecretValidator(EnvironmentType.DEVELOPMENT);

    it('validates all weak secrets without errors', () => {
      const result = validator.validateAll({
        POSTGRES_PASSWORD: 'password',
        JWT_SECRET: 'short',
        CYREX_API_KEY: 'change-me',
      });
      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });
  });

  describe('Production Environment', () => {
    const validator = createSecretValidator(EnvironmentType.PRODUCTION);

    it('reports errors for weak passwords', () => {
      const result = validator.validateAll({
        POSTGRES_PASSWORD: 'password',
      });
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
      expect(result.errors[0].field).toBe('POSTGRES_PASSWORD');
    });

    it('reports errors for weak JWT secrets', () => {
      const result = validator.validateAll({
        JWT_SECRET: 'default-secret-change-in-production',
      });
      expect(result.valid).toBe(false);
      expect(result.errors[0].field).toBe('JWT_SECRET');
    });

    it('reports errors for weak API keys', () => {
      const result = validator.validateAll({
        CYREX_API_KEY: 'change-me',
      });
      expect(result.valid).toBe(false);
      expect(result.errors[0].field).toBe('CYREX_API_KEY');
    });

    it('accepts strong secrets', () => {
      const result = validator.validateAll({
        POSTGRES_PASSWORD: 'SuperSecret123!@#',
        JWT_SECRET: 'a'.repeat(32) + 'B1!',
        CYREX_API_KEY: 'sk-1234567890abcdefghij1234567890',
      });
      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it('skips null optional fields', () => {
      const result = validator.validateAll({
        OPENAI_API_KEY: undefined,
      });
      expect(result.valid).toBe(true);
    });

    it('validates URLs', () => {
      const result = validator.validateAll({
        DATABASE_URL: 'not-a-url',
      });
      expect(result.valid).toBe(false);
      expect(result.errors[0].field).toBe('DATABASE_URL');
    });

    it('collects multiple errors', () => {
      const result = validator.validateAll({
        POSTGRES_PASSWORD: 'weak',
        JWT_SECRET: 'short',
        CYREX_API_KEY: 'change-me',
      });
      expect(result.errors.length).toBe(3);
    });
  });

  describe('individual validators', () => {
    const validator = createSecretValidator(EnvironmentType.PRODUCTION);

    it('validatePassword works directly', () => {
      expect(() => validator.validatePassword('weak', 'TEST')).toThrow();
    });

    it('validateApiKey works directly', () => {
      expect(() => validator.validateApiKey('change-me', 'TEST')).toThrow();
    });

    it('validateJwt works directly', () => {
      expect(() => validator.validateJwt('short', 'TEST')).toThrow();
    });

    it('validateUrl works directly', () => {
      expect(() => validator.validateUrl('bad', 'TEST')).toThrow();
    });
  });
});
