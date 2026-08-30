import { AppInitializer } from '../../../app/AppInitializer'
import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { AuthService } from '../application/AuthService'
import { AuthApiError } from '../domain/AuthApi'
import { AccountSession, LoginPreparation, RequestCodeResult } from '../domain/AuthModels'
import { HarmonyAuthApi } from '../infrastructure/HarmonyAuthApi'
import { GuestDataSummary } from '../../../domain/model/StudyModels'
import { GuestMergeService } from '../../sync/application/GuestMergeService'
import { ProfileContext } from '../../sync/application/ProfileContext'
import { SyncCoordinator } from '../../sync/application/SyncCoordinator'
import { HarmonySyncApi } from '../../sync/infrastructure/HarmonySyncApi'

const SYSTEM_PROFILE_ID: string = 'system'
const PENDING_ACCOUNT_KEY: string = 'pending_account_id'

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

  async prepareLogin(session: AccountSession): Promise<LoginPreparation> {
    await this.ensureReady()
    const summary: GuestDataSummary = await RepositoryRegistry.sync().guestSummary()
    const requiresDecision: boolean = summary.taskCount > 0 || summary.focusCount > 0 || summary.points > 0
    if (requiresDecision) {
      await RepositoryRegistry.sync().saveMetadata({
        profileId: SYSTEM_PROFILE_ID, key: PENDING_ACCOUNT_KEY,
        value: session.accountId, updatedAt: Date.now()
      })
      ProfileContext.activateGuest()
    } else {
      ProfileContext.activateAccount(session.accountId)
      await RepositoryRegistry.sync().removeMetadata(SYSTEM_PROFILE_ID, PENDING_ACCOUNT_KEY)
    }
    return {
      requiresGuestDecision: requiresDecision,
      taskCount: summary.taskCount,
      focusCount: summary.focusCount,
      points: summary.points
    }
  }

  async guestSummary(): Promise<GuestDataSummary> {
    await this.ensureReady()
    return RepositoryRegistry.sync().guestSummary()
  }

  async mergeGuestAndLogin(session: AccountSession): Promise<void> {
    await this.ensureReady()
    const profileId: string = ProfileContext.accountProfileId(session.accountId)
    const merger: GuestMergeService = new GuestMergeService(
      RepositoryRegistry.tasks(), RepositoryRegistry.categories(), RepositoryRegistry.focusSessions(),
      RepositoryRegistry.rewards(), RepositoryRegistry.settings(), RepositoryRegistry.sync())
    await merger.merge(profileId)
    ProfileContext.activateAccount(session.accountId)
    await RepositoryRegistry.sync().removeMetadata(SYSTEM_PROFILE_ID, PENDING_ACCOUNT_KEY)
    await this.syncCoordinator().synchronize(session)
  }

  async keepGuestAndLogin(session: AccountSession): Promise<void> {
    await this.ensureReady()
    ProfileContext.activateAccount(session.accountId)
    await RepositoryRegistry.sync().removeMetadata(SYSTEM_PROFILE_ID, PENDING_ACCOUNT_KEY)
    await this.syncCoordinator().synchronize(session)
  }

  async cancelVerifiedLogin(): Promise<void> {
    await this.ensureReady()
    try {
      await this.auth().logout()
    } catch (error) {
    } finally {
      ProfileContext.activateGuest()
      await RepositoryRegistry.sync().removeMetadata(SYSTEM_PROFILE_ID, PENDING_ACCOUNT_KEY)
    }
  }

  async importGuestData(session: AccountSession): Promise<void> {
    await this.mergeGuestAndLogin(session)
  }

  async deleteGuestData(): Promise<void> {
    await this.ensureReady()
    await RepositoryRegistry.sync().deleteGuestData()
  }

  async logout(): Promise<void> {
    await this.ensureReady()
    try {
      await this.auth().logout()
    } finally {
      ProfileContext.activateGuest()
      await RepositoryRegistry.sync().removeMetadata(SYSTEM_PROFILE_ID, PENDING_ACCOUNT_KEY)
    }
  }

  async deleteAccount(): Promise<void> {
    await this.ensureReady()
    await this.auth().deleteAccount()
    ProfileContext.activateGuest()
    await RepositoryRegistry.sync().removeMetadata(SYSTEM_PROFILE_ID, PENDING_ACCOUNT_KEY)
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

  private syncCoordinator(): SyncCoordinator {
    return new SyncCoordinator(
      new HarmonySyncApi(), RepositoryRegistry.sync(), RepositoryRegistry.tasks(),
      RepositoryRegistry.categories(), RepositoryRegistry.focusSessions(),
      RepositoryRegistry.rewards(), RepositoryRegistry.settings())
  }
}
