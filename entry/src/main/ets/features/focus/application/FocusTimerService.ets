import { util } from '@kit.ArkTS'
import { AppInitializer } from '../../../app/AppInitializer'
import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { AppLogger } from '../../../core/logging/AppLogger'
import { FocusTimerCoordinator } from './FocusTimerCoordinator'
import { RewardSettlementService } from '../../rewards/application/RewardSettlementService'

export class FocusTimerService {
  private static coordinator: FocusTimerCoordinator | null = null

  static async guest(): Promise<FocusTimerCoordinator> {
    await AppInitializer.whenReady()
    if (FocusTimerService.coordinator === null) {
      const idFactory = (): string => util.generateRandomUUID(true)
      const settlement: RewardSettlementService = new RewardSettlementService(
        RepositoryRegistry.focusSessions(), RepositoryRegistry.rewards(), idFactory,
        (timestamp: number) => -new Date(timestamp).getTimezoneOffset())
      try {
        await settlement.reconcileProfile(GUEST_PROFILE_ID)
      } catch (error) {
        AppLogger.warn('FocusTimerService', 'Pending rewards will be reconciled later')
      }
      FocusTimerService.coordinator = new FocusTimerCoordinator(
        RepositoryRegistry.timerState(), RepositoryRegistry.focusSessions(), GUEST_PROFILE_ID,
        () => Date.now(), idFactory, settlement)
    }
    return FocusTimerService.coordinator
  }
}
