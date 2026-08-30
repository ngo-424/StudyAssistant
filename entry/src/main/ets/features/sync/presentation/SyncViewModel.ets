import { AppInitializer } from '../../../app/AppInitializer'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { SyncConflict, SyncStatus } from '../../../domain/model/StudyModels'
import { AuthService } from '../../auth/application/AuthService'
import { AccountSession } from '../../auth/domain/AuthModels'
import { HarmonyAuthApi } from '../../auth/infrastructure/HarmonyAuthApi'
import { ProfileContext } from '../application/ProfileContext'
import { SyncCoordinator } from '../application/SyncCoordinator'
import { HarmonySyncApi } from '../infrastructure/HarmonySyncApi'

export interface SyncScreenData {
  status: SyncStatus
  conflicts: SyncConflict[]
}

export class SyncViewModel {
  private coordinator: SyncCoordinator | null = null
  private authService: AuthService | null = null

  async load(): Promise<SyncScreenData> {
    await this.ensureReady()
    const profileId: string = ProfileContext.currentProfileId()
    return {
      status: {
        syncing: false,
        offline: false,
        pendingCount: await this.sync().pendingCount(profileId),
        conflictCount: await this.sync().conflictCount(profileId),
        lastSyncedAt: await this.sync().lastSyncedAt(profileId),
        errorMessage: ''
      },
      conflicts: await this.sync().listConflicts(profileId)
    }
  }

  async synchronize(): Promise<SyncScreenData> {
    await this.ensureReady()
    const session: AccountSession = await this.auth().sessionForRequest()
    await this.sync().synchronize(session)
    return this.load()
  }

  async resolveUsingCloud(conflict: SyncConflict): Promise<SyncScreenData> {
    await this.ensureReady()
    await this.sync().resolveUsingCloud(conflict)
    return this.load()
  }

  async resolveUsingLocal(conflict: SyncConflict): Promise<SyncScreenData> {
    await this.ensureReady()
    await this.sync().resolveUsingLocal(conflict)
    return this.load()
  }

  private async ensureReady(): Promise<void> {
    await AppInitializer.whenReady()
    if (this.coordinator === null) {
      this.coordinator = new SyncCoordinator(
        new HarmonySyncApi(), RepositoryRegistry.sync(), RepositoryRegistry.tasks(),
        RepositoryRegistry.categories(), RepositoryRegistry.focusSessions(),
        RepositoryRegistry.rewards(), RepositoryRegistry.settings())
    }
    if (this.authService === null) {
      this.authService = new AuthService(
        new HarmonyAuthApi(), RepositoryRegistry.accountSession(),
        () => RepositoryRegistry.timerState().getOrCreateDeviceId(
          ProfileContext.currentProfileId(), () => AuthService.fallbackDeviceId()))
    }
  }

  private sync(): SyncCoordinator {
    if (this.coordinator === null) {
      throw new Error('Sync coordinator is unavailable')
    }
    return this.coordinator
  }

  private auth(): AuthService {
    if (this.authService === null) {
      throw new Error('Authentication service is unavailable')
    }
    return this.authService
  }
}
