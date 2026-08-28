import { TimerConfig } from '../../../domain/model/StudyModels'
import { FocusTimerCoordinator } from '../../focus/application/FocusTimerCoordinator'
import { FocusTimerService } from '../../focus/application/FocusTimerService'

export class FocusSettingsViewModel {
  private coordinator: FocusTimerCoordinator | null = null

  async load(): Promise<TimerConfig> {
    const coordinator: FocusTimerCoordinator = await this.getCoordinator()
    return (await coordinator.restore()).config
  }

  async save(config: TimerConfig): Promise<TimerConfig> {
    return (await this.getCoordinator()).saveConfig(config)
  }

  private async getCoordinator(): Promise<FocusTimerCoordinator> {
    if (this.coordinator === null) {
      this.coordinator = await FocusTimerService.guest()
    }
    return this.coordinator
  }
}
