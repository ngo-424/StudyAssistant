import { RefreshTokenEntity } from '../src/database/entities/refresh-token.entity';
import { VerificationCodeEntity } from '../src/database/entities/verification-code.entity';
import { AuthSecurity } from '../src/auth/auth-security';
import { VerificationDecision } from '../src/auth/auth.contracts';
import { RefreshTokenDecision, RefreshTokenSecurity } from '../src/auth/refresh-token-security';

const pepper = 'test-pepper-with-sufficient-entropy';

function verificationRecord(code: string, now: Date): VerificationCodeEntity {
  const record = new VerificationCodeEntity();
  record.id = '00000000-0000-4000-8000-000000000001';
  record.emailNormalized = 'learner@example.com';
  record.codeHash = AuthSecurity.codeDigest(record.emailNormalized, code, pepper);
  record.expiresAt = new Date(now.getTime() + 10 * 60 * 1000);
  record.consumedAt = null;
  record.attemptCount = 0;
  record.requestIpHash = '0'.repeat(64);
  record.deviceHash = AuthSecurity.digest('device-12345678', pepper);
  record.createdAt = now;
  return record;
}

describe('AuthSecurity', () => {
  const now = new Date('2026-08-29T08:00:00.000Z');

  it('normalizes an email without exposing it through hashes', () => {
    expect(AuthSecurity.normalizeEmail('  Learner@Example.COM ')).toBe('learner@example.com');
    expect(AuthSecurity.digest('learner@example.com', pepper)).not.toContain('learner');
  });

  it('accepts a matching unexpired verification code', () => {
    const record = verificationRecord('123456', now);
    const supplied = AuthSecurity.codeDigest(record.emailNormalized, '123456', pepper);
    expect(AuthSecurity.evaluateCode(record, supplied, now)).toBe(VerificationDecision.ACCEPT);
  });

  it('rejects expired, consumed, incorrect, and locked codes', () => {
    const expired = verificationRecord('123456', now);
    expired.expiresAt = now;
    expect(AuthSecurity.evaluateCode(expired, expired.codeHash, now)).toBe(VerificationDecision.EXPIRED);

    const consumed = verificationRecord('123456', now);
    consumed.consumedAt = now;
    expect(AuthSecurity.evaluateCode(consumed, consumed.codeHash, now)).toBe(VerificationDecision.LOCKED);

    const locked = verificationRecord('123456', now);
    locked.attemptCount = 5;
    expect(AuthSecurity.evaluateCode(locked, locked.codeHash, now)).toBe(VerificationDecision.LOCKED);

    const incorrect = verificationRecord('123456', now);
    const wrongHash = AuthSecurity.codeDigest(incorrect.emailNormalized, '654321', pepper);
    expect(AuthSecurity.evaluateCode(incorrect, wrongHash, now)).toBe(VerificationDecision.INVALID);
  });

  it('generates fixed-width codes and high-entropy opaque tokens', () => {
    expect(AuthSecurity.sixDigitCode()).toMatch(/^\d{6}$/);
    const first = AuthSecurity.opaqueToken();
    const second = AuthSecurity.opaqueToken();
    expect(first.length).toBeGreaterThanOrEqual(64);
    expect(first).not.toBe(second);
  });
});

describe('RefreshTokenSecurity', () => {
  const now = new Date('2026-08-29T08:00:00.000Z');
  const deviceId = 'device-12345678';

  function token(): RefreshTokenEntity {
    const entity = new RefreshTokenEntity();
    entity.id = '00000000-0000-4000-8000-000000000002';
    entity.userId = '00000000-0000-4000-8000-000000000003';
    entity.tokenHash = '2'.repeat(64);
    entity.deviceHash = AuthSecurity.digest(deviceId, pepper);
    entity.familyId = '00000000-0000-4000-8000-000000000004';
    entity.expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    entity.revokedAt = null;
    entity.rotatedToId = null;
    entity.createdAt = now;
    return entity;
  }

  it('accepts only the original device and rejects a rotated token replay', () => {
    const active = token();
    expect(RefreshTokenSecurity.evaluate(active, deviceId, pepper, now)).toBe(RefreshTokenDecision.ACCEPT);
    expect(RefreshTokenSecurity.evaluate(active, 'another-device', pepper, now))
      .toBe(RefreshTokenDecision.WRONG_DEVICE);
    active.revokedAt = now;
    expect(RefreshTokenSecurity.evaluate(active, deviceId, pepper, now)).toBe(RefreshTokenDecision.REPLAYED);
  });

  it('rejects a token at its expiration boundary', () => {
    const expired = token();
    expired.expiresAt = now;
    expect(RefreshTokenSecurity.evaluate(expired, deviceId, pepper, now)).toBe(RefreshTokenDecision.EXPIRED);
  });
});
