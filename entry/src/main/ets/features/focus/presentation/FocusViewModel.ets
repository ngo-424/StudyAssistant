import { AppInitializer } from '../../../app/AppInitializer'
import { common } from '@kit.AbilityKit'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { StudyTask, TaskCategory, TaskStatus, TimerConfig, TimerRunState } from '../../../domain/model/StudyModels'
import { FocusTimerCoordinator } from '../application/FocusTimerCoordinator'
import { FocusTimerService } from '../application/FocusTimerService'
import { FocusSystemExperienceService } from '../application/FocusSystemExperienceService'
import { TimerRuntimeState } from '../domain/TimerModels'
import { CategoryColor } from '../../tasks/domain/CategoryColor'
import { FocusSystemDescriptor, FocusSystemStatus } from '../system/FocusSystemModels'
import { ProfileContext } from '../../sync/application/ProfileContext'

export interface FocusScreenData {
  runtime: TimerRuntimeState
  tasks: StudyTask[]
  categories: TaskCategory[]
}

export class FocusViewModel {
  private coordinator: FocusTimerCoordinator | null = null
  private systemExperience: FocusSystemExperienceService | null = null
  private tasks: StudyTask[] = []
  private categories: TaskCategory[] = []
  private profileId: string = ''

  async load(): Promise<FocusScreenData> {
    await AppInitializer.whenReady()
    const coordinator: FocusTimerCoordinator = await this.getCoordinator()
    const profileId: string = ProfileContext.currentProfileId()
    if (this.profileId !== profileId) {
      this.profileId = profileId
      this.coordinator = null
      this.systemExperience = null
    }
    const tasks: StudyTask[] = (await RepositoryRegistry.tasks().findAll(profileId))
      .filter((task: StudyTask) => task.deletedAt === null && task.status === TaskStatus.TODO)
    const categories: TaskCategory[] = (await RepositoryRegistry.categories().findAll(profileId))
      .filter((category: TaskCategory) => category.deletedAt === null)
    this.tasks = tasks
    this.categories = categories
    const runtime: TimerRuntimeState = await coordinator.restore()
    await this.systemController().synchronize(runtime, this.descriptor(runtime))
    return { runtime: runtime, tasks: tasks, categories: categories }
  }

  async observe(): Promise<TimerRuntimeState> {
    const runtime: TimerRuntimeState = await (await this.getCoordinator()).observe()
    if (runtime.snapshot?.state === TimerRunState.COMPLETED ||
      runtime.snapshot?.state === TimerRunState.ABANDONED) {
      await this.systemController().synchronize(runtime, this.descriptor(runtime))
    }
    return runtime
  }

  async start(task: StudyTask | null): Promise<TimerRuntimeState> {
    const runtime: TimerRuntimeState = await (await this.getCoordinator())
      .start(task?.id ?? null, task?.categoryId ?? null)
    await this.systemController().synchronize(runtime, this.descriptor(runtime))
    return runtime
  }

  async pause(): Promise<TimerRuntimeState> {
    return this.synchronize(await (await this.getCoordinator()).pause())
  }

  async resume(): Promise<TimerRuntimeState> {
    return this.synchronize(await (await this.getCoordinator()).resume())
  }

  async finishEarly(): Promise<TimerRuntimeState> {
    return this.synchronize(await (await this.getCoordinator()).finishEarly())
  }

  async abandon(): Promise<TimerRuntimeState> {
    return this.synchronize(await (await this.getCoordinator()).abandon())
  }

  async startNextPhase(): Promise<TimerRuntimeState> {
    return this.synchronize(await (await this.getCoordinator()).startNextPhase())
  }

  async dismissTerminal(): Promise<void> {
    const runtime: TimerRuntimeState = await (await this.getCoordinator()).restore()
    if (runtime.snapshot !== null) {
      await this.systemController().stop(runtime.snapshot.flowId)
    }
    return (await this.getCoordinator()).dismissTerminal()
  }

  async saveConfig(config: TimerConfig): Promise<TimerConfig> {
    return (await this.getCoordinator()).saveConfig(config)
  }

  async requestNotificationPermission(context: common.UIAbilityContext): Promise<FocusSystemStatus> {
    return this.systemController().requestNotificationPermission(context)
  }

  systemStatus(): FocusSystemStatus {
    return this.systemController().currentStatus()
  }

  private async getCoordinator(): Promise<FocusTimerCoordinator> {
    if (this.coordinator === null) {
      this.coordinator = await FocusTimerService.guest()
    }
    return this.coordinator
  }

  private systemController(): FocusSystemExperienceService {
    if (this.systemExperience === null) {
      this.systemExperience = FocusSystemExperienceService.guest()
    }
    return this.systemExperience
  }

  private async synchronize(runtime: TimerRuntimeState): Promise<TimerRuntimeState> {
    await this.systemController().synchronize(runtime, this.descriptor(runtime))
    return runtime
  }

  private descriptor(runtime: TimerRuntimeState): FocusSystemDescriptor {
    const task: StudyTask | undefined = this.tasks.find((item: StudyTask) =>
      item.id === runtime.snapshot?.taskId)
    const category: TaskCategory | undefined = this.categories.find((item: TaskCategory) =>
      item.id === runtime.snapshot?.categoryId)
    return {
      taskTitle: task?.title ?? '',
      colorSeed: category?.colorSeed ?? CategoryColor.NEUTRAL
    }
  }
}
