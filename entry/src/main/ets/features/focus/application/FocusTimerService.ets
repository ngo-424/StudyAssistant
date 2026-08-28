import { util } from '@kit.ArkTS'
import { AppInitializer } from '../../../app/AppInitializer'
import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { FocusTimerCoordinator } from './FocusTimerCoordinator'

export class FocusTimerService {
  private static coordinator: FocusTimerCoordinator | null = null

  static async guest(): Promise<FocusTimerCoordinator> {
    await AppInitializer.whenReady()
    if (FocusTimerService.coordinator === null) {
      FocusTimerService.coordinator = new FocusTimerCoordinator(
        RepositoryRegistry.timerState(), RepositoryRegistry.focusSessions(), GUEST_PROFILE_ID,
        () => Date.now(), () => util.generateRandomUUID(true))
    }
    return FocusTimerService.coordinator
  }
}
