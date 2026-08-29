import { createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { VerificationCodeEntity } from '../database/entities/verification-code.entity';
import { VerificationDecision } from './auth.contracts';

export class AuthSecurity {
  static normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
  }

  static sixDigitCode(): string {
    return randomInt(0, 1_000_000).toString().padStart(6, '0');
  }

  static opaqueToken(): string {
    return randomBytes(48).toString('base64url');
  }

  static digest(value: string, pepper: string): string {
    return createHmac('sha256', pepper).update(value).digest('hex');
  }

  static codeDigest(email: string, code: string, pepper: string): string {
    return AuthSecurity.digest(`${AuthSecurity.normalizeEmail(email)}:${code}`, pepper);
  }

  static safeEqual(leftHex: string, rightHex: string): boolean {
    if (leftHex.length !== rightHex.length) {
      return false;
    }
    return timingSafeEqual(Buffer.from(leftHex, 'hex'), Buffer.from(rightHex, 'hex'));
  }

  static evaluateCode(record: VerificationCodeEntity, suppliedHash: string, now: Date): VerificationDecision {
    if (record.consumedAt !== null || record.attemptCount >= 5) {
      return VerificationDecision.LOCKED;
    }
    if (record.expiresAt.getTime() <= now.getTime()) {
      return VerificationDecision.EXPIRED;
    }
    return AuthSecurity.safeEqual(record.codeHash, suppliedHash) ?
      VerificationDecision.ACCEPT : VerificationDecision.INVALID;
  }
}
