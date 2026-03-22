import { UrlValidator } from '../urlValidator';
import { EnvironmentType } from '../../types';

describe('UrlValidator', () => {
  it('accepts valid http URL', () => {
    const validator = new UrlValidator(EnvironmentType.DEVELOPMENT);
    expect(validator.validate('http://minio:9000', 'S3_URL')).toBe('http://minio:9000');
  });

  it('accepts valid https URL', () => {
    const validator = new UrlValidator(EnvironmentType.PRODUCTION);
    expect(validator.validate('https://s3.amazonaws.com', 'S3_URL')).toBe('https://s3.amazonaws.com');
  });

  it('rejects invalid URL', () => {
    const validator = new UrlValidator(EnvironmentType.PRODUCTION);
    expect(() => validator.validate('not-a-url', 'S3_URL')).toThrow('Invalid URL');
  });

  it('requires https in production when specified', () => {
    const validator = new UrlValidator(EnvironmentType.PRODUCTION);
    expect(() => validator.validate('http://example.com', 'API_URL', true)).toThrow('HTTPS is required');
  });

  it('allows http in development even with requireHttps', () => {
    const validator = new UrlValidator(EnvironmentType.DEVELOPMENT);
    expect(validator.validate('http://localhost:9000', 'S3_URL', true)).toBe('http://localhost:9000');
  });

  it('rejects empty URL', () => {
    const validator = new UrlValidator(EnvironmentType.PRODUCTION);
    expect(() => validator.validate('', 'S3_URL')).toThrow('required');
  });
});
