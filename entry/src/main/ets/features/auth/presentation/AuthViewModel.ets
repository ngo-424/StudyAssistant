import { AppInitializer } from '../../../app/AppInitializer'
import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { AuthService } from '../application/AuthService'
import { AuthApiError } from '../domain/AuthApi'
import { AccountSession, RequestCodeResult } from '../domain/AuthModels'
import { HarmonyAuthApi } from '../infrastructure/HarmonyAuthApi'

export class AuthViewModel {
  private service: AuthService | null = null

  async load(): Promise<AccountSession | null> {
    await this.ensureReady()
    return this.auth().current()
  }

  async requestCode(email: string): Promise<RequestCodeResult> {
    await this.ensureReady()
    return this.auth().requestCode(email)
  }

  async verifyCode(email: string, code: string): Promise<AccountSession> {
    await this.ensureReady()
    return this.auth().verifyCode(email, code)
  }

  async logout(): Promise<void> {
    await this.ensureReady()
    await this.auth().logout()
  }

  async deleteAccount(): Promise<void> {
    await this.ensureReady()
    await this.auth().deleteAccount()
  }

  errorCode(error: Object): string {
    if (error instanceof AuthApiError) {
      return error.errorCode
    }
    return 'AUTH_REQUEST_FAILED'
  }

  private async ensureReady(): Promise<void> {
    await AppInitializer.whenReady()
    if (this.service === null) {
      this.service = new AuthService(
        new HarmonyAuthApi(), RepositoryRegistry.accountSession(),
        () => RepositoryRegistry.timerState().getOrCreateDeviceId(
          GUEST_PROFILE_ID, () => AuthService.fallbackDeviceId()))
    }
  }

  private auth(): AuthService {
    if (this.service === null) {
      throw new Error('Authentication service is unavailable')
    }
    return this.service
  }
}
