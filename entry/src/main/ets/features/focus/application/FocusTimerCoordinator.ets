import { AppError, AppErrorCode } from '../../../core/error/AppError'
import {
  ActiveTimerSnapshot,
  FocusSession,
  SyncState,
  TimerConfig,
  TimerRunState
} from '../../../domain/model/StudyModels'
import { FocusSessionRepository, TimerStateRepository } from '../../../domain/repository/StudyRepositories'
import { FocusTimerEngine } from '../domain/FocusTimerEngine'
import {
  TimerPhaseOutcome,
  TimerRuntimeState,
  TimerStartContext,
  TimerTransition
} from '../domain/TimerModels'
import { TimerConfigRules } from '../domain/TimerConfigRules'

const CHECKPOINT_INTERVAL_MS: number = 30000

export class FocusTimerCoordinator {
  private readonly timerState: TimerStateRepository
  private readonly sessions: FocusSessionRepository
  private readonly profileId: string
  private readonly clock: () => number
  private readonly idFactory: () => string

  constructor(timerState: TimerStateRepository, sessions: FocusSessionRepository,
    profileId: string, clock: () => number, idFactory: () => string) {
    this.timerState = timerState
    this.sessions = sessions
    this.profileId = profileId
    this.clock = clock
    this.idFactory = idFactory
  }

  async restore(): Promise<TimerRuntimeState> {
    const config: TimerConfig = await this.loadConfig()
    const saved: ActiveTimerSnapshot | null = await this.timerState.loadSnapshot(this.profileId)
    if (saved === null) {
      return { config: config, snapshot: null, reading: null }
    }
    const transition: TimerTransition = FocusTimerEngine.synchronize(saved, this.clock())
    if (transition.outcome !== null || transition.reading.clockAdjusted) {
      await this.persist(transition)
    }
    return { config: config, snapshot: transition.snapshot, reading: transition.reading }
  }

  async saveConfig(config: TimerConfig): Promise<TimerConfig> {
    const validated: TimerConfig = TimerConfigRules.validate(config)
    await this.timerState.saveConfig(this.profileId, validated)
    return validated
  }

  async start(taskId: string | null, categoryId: string | null): Promise<TimerRuntimeState> {
    const existing: ActiveTimerSnapshot | null = await this.timerState.loadSnapshot(this.profileId)
    if (existing !== null && (existing.state === TimerRunState.RUNNING ||
      existing.state === TimerRunState.PAUSED)) {
      throw new AppError(AppErrorCode.VALIDATION, 'TIMER_ALREADY_ACTIVE')
    }
    const config: TimerConfig = await this.loadConfig()
    const context: TimerStartContext = {
      profileId: this.profileId,
      taskId: taskId,
      categoryId: categoryId
    }
    const transition: TimerTransition = FocusTimerEngine.startFocus(
      config, context, this.clock(), this.idFactory(), this.idFactory())
    await this.timerState.saveSnapshot(transition.snapshot)
    return { config: config, snapshot: transition.snapshot, reading: transition.reading }
  }

  async observe(): Promise<TimerRuntimeState> {
    const config: TimerConfig = await this.loadConfig()
    const snapshot: ActiveTimerSnapshot = await this.requireSnapshot()
    const now: number = this.clock()
    const transition: TimerTransition = FocusTimerEngine.synchronize(snapshot, now)
    if (transition.outcome !== null || transition.reading.clockAdjusted ||
      now - snapshot.updatedAt >= CHECKPOINT_INTERVAL_MS) {
      await this.persist(transition)
    }
    return { config: config, snapshot: transition.snapshot, reading: transition.reading }
  }

  async pause(): Promise<TimerRuntimeState> {
    return this.apply(FocusTimerEngine.pause(await this.requireSnapshot(), this.clock()))
  }

  async resume(): Promise<TimerRuntimeState> {
    return this.apply(FocusTimerEngine.resume(await this.requireSnapshot(), this.clock()))
  }

  async finishEarly(): Promise<TimerRuntimeState> {
    return this.apply(FocusTimerEngine.finishEarly(await this.requireSnapshot(), this.clock()))
  }

  async abandon(): Promise<TimerRuntimeState> {
    return this.apply(FocusTimerEngine.abandon(await this.requireSnapshot(), this.clock()))
  }

  async startNextPhase(): Promise<TimerRuntimeState> {
    const transition: TimerTransition = FocusTimerEngine.startNextPhase(
      await this.requireSnapshot(), this.clock(), this.idFactory())
    return this.apply(transition)
  }

  async dismissTerminal(): Promise<void> {
    const snapshot: ActiveTimerSnapshot | null = await this.timerState.loadSnapshot(this.profileId)
    if (snapshot !== null && (snapshot.state === TimerRunState.RUNNING ||
      snapshot.state === TimerRunState.PAUSED)) {
      throw new AppError(AppErrorCode.VALIDATION, 'TIMER_STILL_ACTIVE')
    }
    await this.timerState.clearSnapshot(this.profileId)
  }

  private async apply(transition: TimerTransition): Promise<TimerRuntimeState> {
    await this.persist(transition)
    return {
      config: await this.loadConfig(),
      snapshot: transition.snapshot,
      reading: transition.reading
    }
  }

  private async persist(transition: TimerTransition): Promise<void> {
    if (transition.outcome !== null) {
      await this.sessions.save(await this.toSession(transition.outcome))
    }
    await this.timerState.saveSnapshot(transition.snapshot)
  }

  private async toSession(outcome: TimerPhaseOutcome): Promise<FocusSession> {
    const deviceId: string = await this.timerState.getOrCreateDeviceId(this.profileId, this.idFactory)
    const syncState: SyncState = outcome.profileId === 'guest' ? SyncState.LOCAL_ONLY : SyncState.PENDING
    return {
      id: outcome.sessionId,
      profileId: outcome.profileId,
      taskId: outcome.taskId,
      categoryId: outcome.categoryId,
      deviceId: deviceId,
      phase: outcome.phase,
      plannedSeconds: outcome.plannedSeconds,
      focusedSeconds: outcome.focusedSeconds,
      startedAt: outcome.startedAt,
      endedAt: outcome.endedAt,
      result: outcome.result,
      createdAt: outcome.endedAt,
      updatedAt: outcome.endedAt,
      deletedAt: null,
      revision: 0,
      syncState: syncState
    }
  }

  private async loadConfig(): Promise<TimerConfig> {
    const stored: TimerConfig | null = await this.timerState.loadConfig(this.profileId)
    return stored ?? TimerConfigRules.defaults()
  }

  private async requireSnapshot(): Promise<ActiveTimerSnapshot> {
    const snapshot: ActiveTimerSnapshot | null = await this.timerState.loadSnapshot(this.profileId)
    if (snapshot === null) {
      throw new AppError(AppErrorCode.VALIDATION, 'TIMER_NOT_FOUND')
    }
    return snapshot
  }
}
