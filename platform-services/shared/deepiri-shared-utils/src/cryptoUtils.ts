import { createHash } from 'crypto';

/**
 * Produces a deterministic SHA-256 hex digest of a raw API key.
 *
 * @param rawKey - The plaintext API key extracted from the request header.
 * @returns A 64-character hex string safe for storage.
 * @throws {TypeError} If rawKey is not a non-empty string.
 */
export function hashApiKey(rawKey: string): string {
  if (!rawKey || typeof rawKey !== 'string') {
    throw new TypeError('hashApiKey: rawKey must be a non-empty string.');
  }
  return createHash('sha256').update(rawKey, 'utf8').digest('hex');
}