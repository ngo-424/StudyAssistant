import { AppError, AppErrorCode } from '../../../core/error/AppError'
import {
  ActiveTimerSnapshot,
  FocusPhase,
  FocusResult,
  TimerConfig,
  TimerRunState
} from '../../../domain/model/StudyModels'
import { TimerConfigRules } from './TimerConfigRules'
import { TimerPhaseOutcome, TimerReading, TimerStartContext, TimerTransition } from './TimerModels'

export class FocusTimerEngine {
  static startFocus(config: TimerConfig, context: TimerStartContext, now: number,
    flowId: string, sessionId: string): TimerTransition {
    const validConfig: TimerConfig = TimerConfigRules.validate(config)
    return FocusTimerEngine.startPhase(
      validConfig, context, FocusPhase.FOCUS, 0, now, flowId, sessionId)
  }

  static synchronize(snapshot: ActiveTimerSnapshot, now: number): TimerTransition {
    if (snapshot.state === TimerRunState.PAUSED || snapshot.state === TimerRunState.COMPLETED ||
      snapshot.state === TimerRunState.ABANDONED) {
      return {
        snapshot: snapshot,
        reading: FocusTimerEngine.read(snapshot, now),
        outcome: null
      }
    }

    const clockAdjusted: boolean = now < snapshot.lastObservedAt
    const remaining: number = clockAdjusted ? snapshot.lastKnownRemainingSeconds :
      FocusTimerEngine.remainingFromDeadline(snapshot.deadlineAt, now)
    if (remaining <= 0) {
      return FocusTimerEngine.complete(snapshot, now, FocusResult.COMPLETED, 0, clockAdjusted)
    }

    const adjustedDeadline: number = clockAdjusted ? now + remaining * 1000 : snapshot.deadlineAt
    const updated: ActiveTimerSnapshot = FocusTimerEngine.copy(snapshot, TimerRunState.RUNNING,
      adjustedDeadline, null, null, snapshot.accumulatedPausedMs, snapshot.completedFocusRounds,
      now, remaining, now, snapshot.terminalResult)
    return {
      snapshot: updated,
      reading: FocusTimerEngine.createReading(updated.plannedSeconds, remaining, clockAdjusted),
      outcome: null
    }
  }

  static pause(snapshot: ActiveTimerSnapshot, now: number): TimerTransition {
    if (snapshot.state !== TimerRunState.RUNNING) {
      throw new AppError(AppErrorCode.VALIDATION, 'TIMER_NOT_RUNNING')
    }
    const synchronized: TimerTransition = FocusTimerEngine.synchronize(snapshot, now)
    if (synchronized.outcome !== null) {
      return synchronized
    }
    const remaining: number = synchronized.reading.remainingSeconds
    const paused: ActiveTimerSnapshot = FocusTimerEngine.copy(
      synchronized.snapshot, TimerRunState.PAUSED, synchronized.snapshot.deadlineAt,
      now, remaining, synchronized.snapshot.accumulatedPausedMs,
      synchronized.snapshot.completedFocusRounds, now, remaining, now,
      synchronized.snapshot.terminalResult)
    return {
      snapshot: paused,
      reading: FocusTimerEngine.createReading(paused.plannedSeconds, remaining,
        synchronized.reading.clockAdjusted),
      outcome: null
    }
  }

  static resume(snapshot: ActiveTimerSnapshot, now: number): TimerTransition {
    if (snapshot.state !== TimerRunState.PAUSED) {
      throw new AppError(AppErrorCode.VALIDATION, 'TIMER_NOT_PAUSED')
    }
    const remaining: number = snapshot.remainingSecondsAtPause ?? snapshot.lastKnownRemainingSeconds
    const pausedDuration: number = snapshot.pausedAt === null ? 0 : Math.max(0, now - snapshot.pausedAt)
    const resumed: ActiveTimerSnapshot = FocusTimerEngine.copy(
      snapshot, TimerRunState.RUNNING, now + remaining * 1000, null, null,
      snapshot.accumulatedPausedMs + pausedDuration, snapshot.completedFocusRounds,
      now, remaining, now, snapshot.terminalResult)
    return {
      snapshot: resumed,
      reading: FocusTimerEngine.createReading(resumed.plannedSeconds, remaining, now < snapshot.lastObservedAt),
      outcome: null
    }
  }

  static finishEarly(snapshot: ActiveTimerSnapshot, now: number): TimerTransition {
    if (snapshot.state !== TimerRunState.RUNNING && snapshot.state !== TimerRunState.PAUSED) {
      throw new AppError(AppErrorCode.VALIDATION, 'TIMER_NOT_ACTIVE')
    }
    let active: ActiveTimerSnapshot = snapshot
    let clockAdjusted: boolean = false
    if (snapshot.state === TimerRunState.RUNNING) {
      const synchronized: TimerTransition = FocusTimerEngine.synchronize(snapshot, now)
      if (synchronized.outcome !== null) {
        return synchronized
      }
      active = synchronized.snapshot
      clockAdjusted = synchronized.reading.clockAdjusted
    }
    const remaining: number = active.state === TimerRunState.PAUSED ?
      active.remainingSecondsAtPause ?? active.lastKnownRemainingSeconds : active.lastKnownRemainingSeconds
    return FocusTimerEngine.complete(active, now, FocusResult.INTERRUPTED, remaining, clockAdjusted)
  }

  static abandon(snapshot: ActiveTimerSnapshot, now: number): TimerTransition {
    if (snapshot.state !== TimerRunState.RUNNING && snapshot.state !== TimerRunState.PAUSED) {
      throw new AppError(AppErrorCode.VALIDATION, 'TIMER_NOT_ACTIVE')
    }
    let active: ActiveTimerSnapshot = snapshot
    let clockAdjusted: boolean = false
    if (snapshot.state === TimerRunState.RUNNING) {
      const synchronized: TimerTransition = FocusTimerEngine.synchronize(snapshot, now)
      if (synchronized.outcome !== null) {
        return synchronized
      }
      active = synchronized.snapshot
      clockAdjusted = synchronized.reading.clockAdjusted
    }
    const remaining: number = active.state === TimerRunState.PAUSED ?
      active.remainingSecondsAtPause ?? active.lastKnownRemainingSeconds : active.lastKnownRemainingSeconds
    const elapsed: number = Math.max(0, active.plannedSeconds - remaining)
    const terminal: ActiveTimerSnapshot = FocusTimerEngine.copy(
      active, TimerRunState.ABANDONED, active.deadlineAt, null, null,
      active.accumulatedPausedMs, active.completedFocusRounds, now, remaining, now, FocusResult.ABANDONED)
    return {
      snapshot: terminal,
      reading: FocusTimerEngine.createReading(active.plannedSeconds, remaining, clockAdjusted),
      outcome: FocusTimerEngine.outcome(active, now, FocusResult.ABANDONED, elapsed)
    }
  }

  static startNextPhase(snapshot: ActiveTimerSnapshot, now: number, sessionId: string): TimerTransition {
    if (snapshot.state !== TimerRunState.COMPLETED) {
      throw new AppError(AppErrorCode.VALIDATION, 'TIMER_PHASE_NOT_COMPLETED')
    }
    let nextPhase: FocusPhase = FocusPhase.FOCUS
    if (snapshot.phase === FocusPhase.FOCUS) {
      const completedCurrentFocus: boolean = snapshot.terminalResult === FocusResult.COMPLETED
      const longBreakDue: boolean = completedCurrentFocus && snapshot.completedFocusRounds > 0 &&
        snapshot.completedFocusRounds % snapshot.config.longBreakEvery === 0
      nextPhase = longBreakDue ?
        FocusPhase.LONG_BREAK : FocusPhase.SHORT_BREAK
    }
    const context: TimerStartContext = {
      profileId: snapshot.profileId,
      taskId: snapshot.taskId,
      categoryId: snapshot.categoryId
    }
    return FocusTimerEngine.startPhase(snapshot.config, context, nextPhase,
      snapshot.completedFocusRounds, now, snapshot.flowId, sessionId)
  }

  static read(snapshot: ActiveTimerSnapshot, now: number): TimerReading {
    let remaining: number = snapshot.lastKnownRemainingSeconds
    let clockAdjusted: boolean = false
    if (snapshot.state === TimerRunState.RUNNING) {
      clockAdjusted = now < snapshot.lastObservedAt
      remaining = clockAdjusted ? snapshot.lastKnownRemainingSeconds :
        FocusTimerEngine.remainingFromDeadline(snapshot.deadlineAt, now)
    } else if (snapshot.state === TimerRunState.PAUSED) {
      remaining = snapshot.remainingSecondsAtPause ?? snapshot.lastKnownRemainingSeconds
    } else if (snapshot.state === TimerRunState.COMPLETED) {
      remaining = 0
    }
    return FocusTimerEngine.createReading(snapshot.plannedSeconds, remaining, clockAdjusted)
  }

  private static startPhase(config: TimerConfig, context: TimerStartContext, phase: FocusPhase,
    completedFocusRounds: number, now: number, flowId: string, sessionId: string): TimerTransition {
    const plannedSeconds: number = FocusTimerEngine.durationSeconds(config, phase)
    const snapshot: ActiveTimerSnapshot = {
      flowId: flowId,
      phaseSessionId: sessionId,
      profileId: context.profileId,
      taskId: context.taskId,
      categoryId: context.categoryId,
      phase: phase,
      state: TimerRunState.RUNNING,
      terminalResult: null,
      config: config,
      plannedSeconds: plannedSeconds,
      startedAt: now,
      deadlineAt: now + plannedSeconds * 1000,
      pausedAt: null,
      remainingSecondsAtPause: null,
      accumulatedPausedMs: 0,
      completedFocusRounds: completedFocusRounds,
      lastObservedAt: now,
      lastKnownRemainingSeconds: plannedSeconds,
      updatedAt: now
    }
    return {
      snapshot: snapshot,
      reading: FocusTimerEngine.createReading(plannedSeconds, plannedSeconds, false),
      outcome: null
    }
  }

  private static complete(snapshot: ActiveTimerSnapshot, now: number, result: FocusResult,
    remaining: number, clockAdjusted: boolean): TimerTransition {
    const elapsed: number = Math.max(0, snapshot.plannedSeconds - remaining)
    const completedRounds: number = result === FocusResult.COMPLETED &&
      snapshot.phase === FocusPhase.FOCUS ? snapshot.completedFocusRounds + 1 : snapshot.completedFocusRounds
    const terminal: ActiveTimerSnapshot = FocusTimerEngine.copy(
      snapshot, TimerRunState.COMPLETED, snapshot.deadlineAt, null, null,
      snapshot.accumulatedPausedMs, completedRounds, now, 0, now, result)
    return {
      snapshot: terminal,
      reading: FocusTimerEngine.createReading(snapshot.plannedSeconds, 0, clockAdjusted),
      outcome: FocusTimerEngine.outcome(snapshot, now, result, elapsed)
    }
  }

  private static outcome(snapshot: ActiveTimerSnapshot, now: number,
    result: FocusResult, focusedSeconds: number): TimerPhaseOutcome {
    return {
      sessionId: snapshot.phaseSessionId,
      profileId: snapshot.profileId,
      taskId: snapshot.taskId,
      categoryId: snapshot.categoryId,
      phase: snapshot.phase,
      plannedSeconds: snapshot.plannedSeconds,
      focusedSeconds: focusedSeconds,
      startedAt: snapshot.startedAt,
      endedAt: Math.max(now, snapshot.startedAt),
      result: result
    }
  }

  private static durationSeconds(config: TimerConfig, phase: FocusPhase): number {
    if (phase === FocusPhase.FOCUS) {
      return config.focusMinutes * 60
    }
    return phase === FocusPhase.LONG_BREAK ? config.longBreakMinutes * 60 : config.shortBreakMinutes * 60
  }

  private static remainingFromDeadline(deadlineAt: number, now: number): number {
    return Math.max(0, Math.ceil((deadlineAt - now) / 1000))
  }

  private static createReading(plannedSeconds: number,
    remainingSeconds: number, clockAdjusted: boolean): TimerReading {
    const safeRemaining: number = Math.max(0, Math.min(plannedSeconds, remainingSeconds))
    const elapsed: number = plannedSeconds - safeRemaining
    return {
      remainingSeconds: safeRemaining,
      elapsedSeconds: elapsed,
      progress: plannedSeconds === 0 ? 1 : elapsed / plannedSeconds,
      clockAdjusted: clockAdjusted
    }
  }

  private static copy(snapshot: ActiveTimerSnapshot, state: TimerRunState, deadlineAt: number,
    pausedAt: number | null, remainingSecondsAtPause: number | null, accumulatedPausedMs: number,
    completedFocusRounds: number, lastObservedAt: number,
    lastKnownRemainingSeconds: number, updatedAt: number,
    terminalResult: FocusResult | null): ActiveTimerSnapshot {
    return {
      flowId: snapshot.flowId,
      phaseSessionId: snapshot.phaseSessionId,
      profileId: snapshot.profileId,
      taskId: snapshot.taskId,
      categoryId: snapshot.categoryId,
      phase: snapshot.phase,
      state: state,
      terminalResult: terminalResult,
      config: snapshot.config,
      plannedSeconds: snapshot.plannedSeconds,
      startedAt: snapshot.startedAt,
      deadlineAt: deadlineAt,
      pausedAt: pausedAt,
      remainingSecondsAtPause: remainingSecondsAtPause,
      accumulatedPausedMs: accumulatedPausedMs,
      completedFocusRounds: completedFocusRounds,
      lastObservedAt: lastObservedAt,
      lastKnownRemainingSeconds: lastKnownRemainingSeconds,
      updatedAt: updatedAt
    }
  }
}
