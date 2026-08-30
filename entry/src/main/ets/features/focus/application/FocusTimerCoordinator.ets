import { AppError, AppErrorCode } from '../../../core/error/AppError'
import { AppLogger } from '../../../core/logging/AppLogger'
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
  TimerControlGuard,
  TimerStartContext,
  TimerTransition
} from '../domain/TimerModels'
import { TimerConfigRules } from '../domain/TimerConfigRules'
import { RewardSettlementService } from '../../rewards/application/RewardSettlementService'

const CHECKPOINT_INTERVAL_MS: number = 30000

export class FocusTimerCoordinator {
  private readonly timerState: TimerStateRepository
  private readonly sessions: FocusSessionRepository
  private readonly profileId: string
  private readonly clock: () => number
  private readonly idFactory: () => string
  private readonly rewards: RewardSettlementService | null
  private readonly controlGuard: TimerControlGuard | null

  constructor(timerState: TimerStateRepository, sessions: FocusSessionRepository,
    profileId: string, clock: () => number, idFactory: () => string,
    rewards: RewardSettlementService | null = null, controlGuard: TimerControlGuard | null = null) {
    this.timerState = timerState
    this.sessions = sessions
    this.profileId = profileId
    this.clock = clock
    this.idFactory = idFactory
    this.rewards = rewards
    this.controlGuard = controlGuard
  }

  async restore(): Promise<TimerRuntimeState> {
    const config: TimerConfig = await this.loadConfig()
    const saved: ActiveTimerSnapshot | null = await this.timerState.loadSnapshot(this.profileId)
    if (saved === null) {
      return { config: config, snapshot: null, reading: null }
    }
    if (!await this.canControl(saved)) {
      return { config: config, snapshot: saved, reading: FocusTimerEngine.read(saved, this.clock()) }
    }
    const transition: TimerTransition = FocusTimerEngine.synchronize(saved, this.clock())
    if (transition.outcome !== null || transition.reading.clockAdjusted) {
      await this.persist(transition)
    }
    if (transition.outcome === null && transition.snapshot.state === TimerRunState.COMPLETED) {
      await this.reconcileReward(transition.snapshot.phaseSessionId)
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
    await this.assertControl(snapshot)
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
    let session: FocusSession | null = null
    if (transition.outcome !== null) {
      session = await this.toSession(transition.outcome)
      await this.sessions.save(session)
    }
    await this.timerState.saveSnapshot(transition.snapshot)
    if (session !== null) {
      await this.settleReward(session)
    }
  }

  async peek(): Promise<TimerRuntimeState> {
    const config: TimerConfig = await this.loadConfig()
    const snapshot: ActiveTimerSnapshot | null = await this.timerState.loadSnapshot(this.profileId)
    return {
      config: config,
      snapshot: snapshot,
      reading: snapshot === null ? null : FocusTimerEngine.read(snapshot, this.clock())
    }
  }

  private async reconcileReward(sessionId: string): Promise<void> {
    if (this.rewards === null) {
      return
    }
    const sessions: FocusSession[] = await this.sessions.findAll(this.profileId)
    const session: FocusSession | undefined = sessions.find((item: FocusSession) => item.id === sessionId)
    if (session !== undefined) {
      await this.settleReward(session)
    }
  }

  private async settleReward(session: FocusSession): Promise<void> {
    if (this.rewards === null) {
      return
    }
    try {
      await this.rewards.settle(session)
    } catch (error) {
      AppLogger.warn('FocusTimerCoordinator', 'Reward settlement deferred for retry')
    }
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
    await this.assertControl(snapshot)
    return snapshot
  }

  private async canControl(snapshot: ActiveTimerSnapshot): Promise<boolean> {
    return this.controlGuard === null || await this.controlGuard.canControl(snapshot)
  }

  private async assertControl(snapshot: ActiveTimerSnapshot): Promise<void> {
    if (!await this.canControl(snapshot)) {
      throw new AppError(AppErrorCode.VALIDATION, 'TIMER_CONTROL_TRANSFERRED')
    }
  }
}
