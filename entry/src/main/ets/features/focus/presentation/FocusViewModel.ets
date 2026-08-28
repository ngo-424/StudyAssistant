import { AppInitializer } from '../../../app/AppInitializer'
import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { StudyTask, TaskCategory, TaskStatus, TimerConfig } from '../../../domain/model/StudyModels'
import { FocusTimerCoordinator } from '../application/FocusTimerCoordinator'
import { FocusTimerService } from '../application/FocusTimerService'
import { TimerRuntimeState } from '../domain/TimerModels'

export interface FocusScreenData {
  runtime: TimerRuntimeState
  tasks: StudyTask[]
  categories: TaskCategory[]
}

export class FocusViewModel {
  private coordinator: FocusTimerCoordinator | null = null

  async load(): Promise<FocusScreenData> {
    await AppInitializer.whenReady()
    const coordinator: FocusTimerCoordinator = await this.getCoordinator()
    const tasks: StudyTask[] = (await RepositoryRegistry.tasks().findAll(GUEST_PROFILE_ID))
      .filter((task: StudyTask) => task.deletedAt === null && task.status === TaskStatus.TODO)
    const categories: TaskCategory[] = (await RepositoryRegistry.categories().findAll(GUEST_PROFILE_ID))
      .filter((category: TaskCategory) => category.deletedAt === null)
    return { runtime: await coordinator.restore(), tasks: tasks, categories: categories }
  }

  async observe(): Promise<TimerRuntimeState> {
    return (await this.getCoordinator()).observe()
  }

  async start(task: StudyTask | null): Promise<TimerRuntimeState> {
    return (await this.getCoordinator()).start(task?.id ?? null, task?.categoryId ?? null)
  }

  async pause(): Promise<TimerRuntimeState> {
    return (await this.getCoordinator()).pause()
  }

  async resume(): Promise<TimerRuntimeState> {
    return (await this.getCoordinator()).resume()
  }

  async finishEarly(): Promise<TimerRuntimeState> {
    return (await this.getCoordinator()).finishEarly()
  }

  async abandon(): Promise<TimerRuntimeState> {
    return (await this.getCoordinator()).abandon()
  }

  async startNextPhase(): Promise<TimerRuntimeState> {
    return (await this.getCoordinator()).startNextPhase()
  }

  async dismissTerminal(): Promise<void> {
    return (await this.getCoordinator()).dismissTerminal()
  }

  async saveConfig(config: TimerConfig): Promise<TimerConfig> {
    return (await this.getCoordinator()).saveConfig(config)
  }

  private async getCoordinator(): Promise<FocusTimerCoordinator> {
    if (this.coordinator === null) {
      this.coordinator = await FocusTimerService.guest()
    }
    return this.coordinator
  }
}
