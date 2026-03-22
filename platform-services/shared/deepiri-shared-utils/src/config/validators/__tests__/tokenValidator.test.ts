import { TokenValidator } from '../tokenValidator';
import { EnvironmentType } from '../../types';

describe('TokenValidator', () => {
  describe('Development Environment', () => {
    const validator = new TokenValidator(EnvironmentType.DEVELOPMENT);

    it('allows weak JWT secrets', () => {
      expect(() => validator.validateJwt('short', 'JWT_SECRET')).not.toThrow();
    });

    it('allows weak tokens', () => {
      expect(() => validator.validateToken('short', 'INFLUXDB_TOKEN')).not.toThrow();
    });
  });

  describe('Production Environment', () => {
    const validator = new TokenValidator(EnvironmentType.PRODUCTION);

    it('rejects empty JWT', () => {
      expect(() => validator.validateJwt('', 'JWT_SECRET')).toThrow('required');
    });

    it('rejects weak JWT secrets', () => {
      expect(() => validator.validateJwt('default-secret-change-in-production', 'JWT_SECRET'))
        .toThrow('known weak');
    });

    it('rejects short JWT secrets', () => {
      expect(() => validator.validateJwt('tooshort', 'JWT_SECRET'))
        .toThrow('at least 32 characters');
    });

    it('accepts valid JWT secrets', () => {
      const secret = 'a'.repeat(32) + 'B1!';
      expect(validator.validateJwt(secret, 'JWT_SECRET')).toBe(secret);
    });

    it('rejects short tokens', () => {
      expect(() => validator.validateToken('short', 'INFLUXDB_TOKEN'))
        .toThrow('at least 48 characters');
    });

    it('accepts valid tokens', () => {
      const token = 'a'.repeat(50);
      expect(validator.validateToken(token, 'INFLUXDB_TOKEN')).toBe(token);
    });
  });
});
