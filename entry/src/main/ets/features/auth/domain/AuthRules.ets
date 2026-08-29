import { AccountSession, AuthSessionPayload } from './AuthModels'

export class AuthRules {
  static normalizeEmail(email: string): string {
    return email.trim().toLowerCase()
  }

  static validEmail(email: string): boolean {
    const normalized: string = AuthRules.normalizeEmail(email)
    return normalized.length >= 3 && normalized.length <= 320 &&
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)
  }

  static validCode(code: string): boolean {
    return /^\d{6}$/.test(code.trim())
  }

  static fromPayload(payload: AuthSessionPayload, deviceId: string, now: number): AccountSession {
    const accessExpiresAt: number = Date.parse(payload.tokens.accessExpiresAt)
    const refreshExpiresAt: number = Date.parse(payload.tokens.refreshExpiresAt)
    if (payload.account.id.length === 0 || !AuthRules.validEmail(payload.account.email) ||
      payload.tokens.accessToken.length === 0 || payload.tokens.refreshToken.length === 0 ||
      !Number.isFinite(accessExpiresAt) || !Number.isFinite(refreshExpiresAt) ||
      refreshExpiresAt <= accessExpiresAt || accessExpiresAt <= now) {
      throw new Error('Authentication response is invalid')
    }
    return {
      accountId: payload.account.id,
      email: AuthRules.normalizeEmail(payload.account.email),
      accessToken: payload.tokens.accessToken,
      refreshToken: payload.tokens.refreshToken,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      deviceId: deviceId,
      updatedAt: now
    }
  }

  static accessNeedsRefresh(session: AccountSession, now: number): boolean {
    return session.accessExpiresAt <= now + 60_000
  }

  static refreshExpired(session: AccountSession, now: number): boolean {
    return session.refreshExpiresAt <= now
  }
}
