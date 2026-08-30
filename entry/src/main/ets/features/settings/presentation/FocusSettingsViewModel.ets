import { TimerConfig } from '../../../domain/model/StudyModels'
import { FocusTimerCoordinator } from '../../focus/application/FocusTimerCoordinator'
import { FocusTimerService } from '../../focus/application/FocusTimerService'
import { ProfileContext } from '../../sync/application/ProfileContext'

export class FocusSettingsViewModel {
  private coordinator: FocusTimerCoordinator | null = null
  private profileId: string = ''

  async load(): Promise<TimerConfig> {
    const coordinator: FocusTimerCoordinator = await this.getCoordinator()
    return (await coordinator.restore()).config
  }

  async save(config: TimerConfig): Promise<TimerConfig> {
    return (await this.getCoordinator()).saveConfig(config)
  }

  private async getCoordinator(): Promise<FocusTimerCoordinator> {
    const profileId: string = ProfileContext.currentProfileId()
    if (this.coordinator === null || this.profileId !== profileId) {
      this.profileId = profileId
      this.coordinator = await FocusTimerService.guest()
    }
    return this.coordinator
  }
}
