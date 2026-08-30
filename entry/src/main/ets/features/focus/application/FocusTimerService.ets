import { util } from '@kit.ArkTS'
import { AppInitializer } from '../../../app/AppInitializer'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { AppLogger } from '../../../core/logging/AppLogger'
import { FocusTimerCoordinator } from './FocusTimerCoordinator'
import { RewardSettlementService } from '../../rewards/application/RewardSettlementService'
import { ProfileContext } from '../../sync/application/ProfileContext'

export class FocusTimerService {
  private static coordinator: FocusTimerCoordinator | null = null
  private static profileId: string = ''

  static async guest(): Promise<FocusTimerCoordinator> {
    await AppInitializer.whenReady()
    const profileId: string = ProfileContext.currentProfileId()
    if (FocusTimerService.coordinator === null || FocusTimerService.profileId !== profileId) {
      FocusTimerService.profileId = profileId
      const idFactory = (): string => util.generateRandomUUID(true)
      const settlement: RewardSettlementService = new RewardSettlementService(
        RepositoryRegistry.focusSessions(), RepositoryRegistry.rewards(), idFactory,
        (timestamp: number) => -new Date(timestamp).getTimezoneOffset())
      try {
        await settlement.reconcileProfile(profileId)
      } catch (error) {
        AppLogger.warn('FocusTimerService', 'Pending rewards will be reconciled later')
      }
      FocusTimerService.coordinator = new FocusTimerCoordinator(
        RepositoryRegistry.timerState(), RepositoryRegistry.focusSessions(), profileId,
        () => Date.now(), idFactory, settlement)
    }
    return FocusTimerService.coordinator
  }
}
