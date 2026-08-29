import { RefreshTokenEntity } from '../database/entities/refresh-token.entity';
import { AuthSecurity } from './auth-security';

export enum RefreshTokenDecision {
  ACCEPT = 'accept',
  REPLAYED = 'replayed',
  EXPIRED = 'expired',
  WRONG_DEVICE = 'wrong_device',
}

export class RefreshTokenSecurity {
  static evaluate(token: RefreshTokenEntity, deviceId: string, pepper: string,
    now: Date): RefreshTokenDecision {
    if (token.revokedAt !== null) {
      return RefreshTokenDecision.REPLAYED;
    }
    if (token.expiresAt.getTime() <= now.getTime()) {
      return RefreshTokenDecision.EXPIRED;
    }
    const expectedDevice = AuthSecurity.digest(deviceId, pepper);
    return AuthSecurity.safeEqual(token.deviceHash, expectedDevice) ?
      RefreshTokenDecision.ACCEPT : RefreshTokenDecision.WRONG_DEVICE;
  }
}
