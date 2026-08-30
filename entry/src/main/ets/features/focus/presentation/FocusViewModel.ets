import { AppInitializer } from '../../../app/AppInitializer'
import { AbilityConstant, common } from '@kit.AbilityKit'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { StudyTask, TaskCategory, TaskStatus, TimerConfig, TimerRunState } from '../../../domain/model/StudyModels'
import { FocusTimerCoordinator } from '../application/FocusTimerCoordinator'
import { FocusTimerService } from '../application/FocusTimerService'
import { FocusSystemExperienceService } from '../application/FocusSystemExperienceService'
import { TimerRuntimeState } from '../domain/TimerModels'
import { CategoryColor } from '../../tasks/domain/CategoryColor'
import { FocusSystemDescriptor, FocusSystemStatus } from '../system/FocusSystemModels'
import { ProfileContext } from '../../sync/application/ProfileContext'
import { FocusContinuationService } from '../../continuation/application/FocusContinuationService'
import {
  ContinuationControlState,
  ContinuationStatus
} from '../../continuation/domain/ContinuationModels'

export interface FocusScreenData {
  runtime: TimerRuntimeState
  tasks: StudyTask[]
  categories: TaskCategory[]
  continuation: ContinuationStatus
}

export class FocusViewModel {
  private coordinator: FocusTimerCoordinator | null = null
  private systemExperience: FocusSystemExperienceService | null = null
  private tasks: StudyTask[] = []
  private categories: TaskCategory[] = []
  private profileId: string = ''
  private continuationStatus: ContinuationStatus = {
    state: ContinuationControlState.IDLE,
    message: '开始计时后可使用跨设备接续',
    canRetry: false,
    isController: true
  }

  async load(): Promise<FocusScreenData> {
    await AppInitializer.whenReady()
    await this.continuation().acceptPending()
    const profileId: string = ProfileContext.currentProfileId()
    if (this.profileId !== profileId) {
      this.profileId = profileId
      this.coordinator = null
      this.systemExperience = null
    }
    const coordinator: FocusTimerCoordinator = await this.getCoordinator()
    const tasks: StudyTask[] = (await RepositoryRegistry.tasks().findAll(profileId))
      .filter((task: StudyTask) => task.deletedAt === null && task.status === TaskStatus.TODO)
    const categories: TaskCategory[] = (await RepositoryRegistry.categories().findAll(profileId))
      .filter((category: TaskCategory) => category.deletedAt === null)
    this.tasks = tasks
    this.categories = categories
    const preview: TimerRuntimeState = await coordinator.peek()
    this.continuationStatus = await this.continuation().update(preview, false)
    const runtime: TimerRuntimeState = this.continuationStatus.isController ?
      await coordinator.restore() : preview
    await this.synchronizeSystem(runtime)
    return { runtime: runtime, tasks: tasks, categories: categories,
      continuation: this.continuationStatus }
  }

  async observe(): Promise<TimerRuntimeState> {
    const coordinator: FocusTimerCoordinator = await this.getCoordinator()
    const preview: TimerRuntimeState = await coordinator.peek()
    this.continuationStatus = await this.continuation().update(preview, true)
    const runtime: TimerRuntimeState = this.continuationStatus.isController ?
      await coordinator.observe() : preview
    if (runtime.snapshot?.state === TimerRunState.COMPLETED ||
      runtime.snapshot?.state === TimerRunState.ABANDONED || !this.continuationStatus.isController) {
      await this.synchronizeSystem(runtime)
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

  continuationState(): ContinuationStatus {
    return this.continuationStatus
  }

  async retryContinuation(): Promise<void> {
    await this.continuation().acceptPending()
  }

  async updateContinuationAvailability(context: common.UIAbilityContext,
    runtime: TimerRuntimeState): Promise<void> {
    const active: boolean = runtime.snapshot !== null &&
      (runtime.snapshot.state === TimerRunState.RUNNING || runtime.snapshot.state === TimerRunState.PAUSED) &&
      !ProfileContext.isGuest() && this.continuationStatus.isController
    try {
      await context.setMissionContinueState(active ? AbilityConstant.ContinueState.ACTIVE :
        AbilityConstant.ContinueState.INACTIVE)
    } catch (error) {
    }
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

  private continuation(): FocusContinuationService {
    return FocusContinuationService.shared()
  }

  private async synchronize(runtime: TimerRuntimeState): Promise<TimerRuntimeState> {
    this.continuationStatus = await this.continuation().update(runtime, false)
    await this.synchronizeSystem(runtime)
    return runtime
  }

  private async synchronizeSystem(runtime: TimerRuntimeState): Promise<void> {
    if (!this.continuationStatus.isController && runtime.snapshot !== null) {
      await this.systemController().stop(runtime.snapshot.flowId)
      return
    }
    await this.systemController().synchronize(runtime, this.descriptor(runtime))
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
