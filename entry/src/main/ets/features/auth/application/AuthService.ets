import { util } from '@kit.ArkTS'
import { AccountSessionRepository } from '../../../domain/repository/AccountSessionRepository'
import { AuthApi, AuthApiError } from '../domain/AuthApi'
import { AccountSession, AuthSessionPayload, RequestCodeResult } from '../domain/AuthModels'
import { AuthRules } from '../domain/AuthRules'

export class AuthService {
  private readonly api: AuthApi
  private readonly sessions: AccountSessionRepository
  private readonly deviceIdProvider: () => Promise<string>
  private readonly clock: () => number

  constructor(api: AuthApi, sessions: AccountSessionRepository,
    deviceIdProvider: () => Promise<string>, clock: () => number = () => Date.now()) {
    this.api = api
    this.sessions = sessions
    this.deviceIdProvider = deviceIdProvider
    this.clock = clock
  }

  current(): Promise<AccountSession | null> {
    return this.sessions.current()
  }

  async requestCode(email: string): Promise<RequestCodeResult> {
    if (!AuthRules.validEmail(email)) {
      throw new AuthApiError(400, 'INVALID_EMAIL')
    }
    return this.api.requestCode(AuthRules.normalizeEmail(email), await this.deviceIdProvider())
  }

  async verifyCode(email: string, code: string): Promise<AccountSession> {
    if (!AuthRules.validEmail(email) || !AuthRules.validCode(code)) {
      throw new AuthApiError(400, 'INVALID_CODE')
    }
    const deviceId: string = await this.deviceIdProvider()
    const payload: AuthSessionPayload = await this.api.verifyCode(
      AuthRules.normalizeEmail(email), code.trim(), deviceId)
    const session: AccountSession = AuthRules.fromPayload(payload, deviceId, this.clock())
    await this.sessions.save(session)
    return session
  }

  async logout(): Promise<void> {
    const session: AccountSession | null = await this.sessions.current()
    if (session === null) {
      return
    }
    try {
      await this.api.logout(session.refreshToken)
    } finally {
      await this.sessions.clear()
    }
  }

  async deleteAccount(): Promise<void> {
    let session: AccountSession | null = await this.sessions.current()
    if (session === null) {
      return
    }
    if (AuthRules.refreshExpired(session, this.clock())) {
      await this.sessions.clear()
      throw new AuthApiError(401, 'SESSION_EXPIRED')
    }
    if (AuthRules.accessNeedsRefresh(session, this.clock())) {
      session = await this.rotate(session)
    }
    await this.api.deleteAccount(session.accessToken)
    await this.sessions.clear()
  }

  private async rotate(current: AccountSession): Promise<AccountSession> {
    const payload: AuthSessionPayload = await this.api.refresh(current.refreshToken, current.deviceId)
    const rotated: AccountSession = AuthRules.fromPayload(payload, current.deviceId, this.clock())
    await this.sessions.save(rotated)
    return rotated
  }

  static fallbackDeviceId(): string {
    return util.generateRandomUUID(true)
  }
}
