import { PasswordValidator } from '../passwordValidator';
import { EnvironmentType } from '../../types';

describe('PasswordValidator', () => {
  describe('Development Environment', () => {
    const validator = new PasswordValidator(EnvironmentType.DEVELOPMENT);

    it('allows weak passwords', () => {
      expect(() => validator.validate('password', 'TEST_PASSWORD')).not.toThrow();
    });

    it('allows short passwords', () => {
      expect(() => validator.validate('short', 'TEST_PASSWORD')).not.toThrow();
    });
  });

  describe('Production Environment', () => {
    const validator = new PasswordValidator(EnvironmentType.PRODUCTION);

    it('rejects empty passwords', () => {
      expect(() => validator.validate('', 'TEST_PASSWORD')).toThrow('Password is required');
    });

    it('rejects weak passwords', () => {
      expect(() => validator.validate('password', 'TEST_PASSWORD')).toThrow('known weak password');
    });

    it('rejects short passwords', () => {
      expect(() => validator.validate('short', 'TEST_PASSWORD')).toThrow('at least 12 characters');
    });

    it('requires complexity', () => {
      expect(() => validator.validate('simplelowercase', 'TEST_PASSWORD')).toThrow('must contain');
    });

    it('accepts strong passwords', () => {
      const strong = 'SuperSecret123!';
      expect(validator.validate(strong, 'TEST_PASSWORD')).toBe(strong);
    });
  });

  describe('Staging Environment', () => {
    const validator = new PasswordValidator(EnvironmentType.STAGING);

    it('rejects weak passwords', () => {
      expect(() => validator.validate('password', 'TEST_PASSWORD')).toThrow('known weak password');
    });

    it('rejects short passwords', () => {
      expect(() => validator.validate('short', 'TEST_PASSWORD')).toThrow('at least 12 characters');
    });

    it('does not require complexity', () => {
      expect(() => validator.validate('simplelowercase', 'TEST_PASSWORD')).not.toThrow();
    });
  });
});
