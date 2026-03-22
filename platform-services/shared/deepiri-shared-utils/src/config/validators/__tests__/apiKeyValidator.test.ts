import { ApiKeyValidator } from '../apiKeyValidator';
import { EnvironmentType } from '../../types';

describe('ApiKeyValidator', () => {
  describe('Development Environment', () => {
    const validator = new ApiKeyValidator(EnvironmentType.DEVELOPMENT);

    it('allows any key', () => {
      expect(validator.validate('short', 'TEST_KEY')).toBe('short');
    });

    it('allows null when optional', () => {
      expect(validator.validate(null, 'TEST_KEY')).toBeNull();
    });
  });

  describe('Production Environment', () => {
    const validator = new ApiKeyValidator(EnvironmentType.PRODUCTION);

    it('rejects placeholder keys', () => {
      expect(() => validator.validate('change-me', 'TEST_KEY')).toThrow('placeholder');
    });

    it('rejects short keys', () => {
      expect(() => validator.validate('short', 'TEST_KEY')).toThrow('at least 20 characters');
    });

    it('accepts valid keys', () => {
      const key = 'sk-1234567890abcdefghij1234567890';
      expect(validator.validate(key, 'TEST_KEY')).toBe(key);
    });

    it('allows null when not required', () => {
      expect(validator.validate(null, 'TEST_KEY')).toBeNull();
    });

    it('rejects null when required', () => {
      expect(() => validator.validate(null, 'TEST_KEY', true)).toThrow('required');
    });
  });
});
