import {
  ActiveTimerSnapshot,
  FocusPhase,
  FocusResult,
  TimerConfig,
  TimerRunState
} from '../../domain/model/StudyModels'

export class TimerStateCodec {
  static encodeConfig(config: TimerConfig): string {
    return JSON.stringify(config)
  }

  static decodeConfig(value: string): TimerConfig | null {
    try {
      const config: TimerConfig = JSON.parse(value) as TimerConfig
      return TimerStateCodec.isConfig(config) ? config : null
    } catch (error) {
      return null
    }
  }

  static encodeSnapshot(snapshot: ActiveTimerSnapshot): string {
    return JSON.stringify(snapshot)
  }

  static decodeSnapshot(value: string): ActiveTimerSnapshot | null {
    try {
      const snapshot: ActiveTimerSnapshot = JSON.parse(value) as ActiveTimerSnapshot
      if (!TimerStateCodec.isSnapshot(snapshot)) {
        return null
      }
      return snapshot
    } catch (error) {
      return null
    }
  }

  static isConfig(config: TimerConfig): boolean {
    return config !== null &&
      TimerStateCodec.validInteger(config.focusMinutes, 1, 480) &&
      TimerStateCodec.validInteger(config.shortBreakMinutes, 1, 120) &&
      TimerStateCodec.validInteger(config.longBreakMinutes, 1, 180) &&
      TimerStateCodec.validInteger(config.longBreakEvery, 2, 12)
  }

  private static isSnapshot(snapshot: ActiveTimerSnapshot): boolean {
    const validPhase: boolean = snapshot.phase === FocusPhase.FOCUS ||
      snapshot.phase === FocusPhase.SHORT_BREAK || snapshot.phase === FocusPhase.LONG_BREAK
    const validState: boolean = snapshot.state === TimerRunState.RUNNING ||
      snapshot.state === TimerRunState.PAUSED || snapshot.state === TimerRunState.COMPLETED ||
      snapshot.state === TimerRunState.ABANDONED
    const validTerminalResult: boolean = snapshot.terminalResult === null ||
      snapshot.terminalResult === FocusResult.COMPLETED ||
      snapshot.terminalResult === FocusResult.INTERRUPTED ||
      snapshot.terminalResult === FocusResult.ABANDONED
    const activeState: boolean = snapshot.state === TimerRunState.RUNNING || snapshot.state === TimerRunState.PAUSED
    const terminalMatchesState: boolean = activeState ? snapshot.terminalResult === null :
      snapshot.terminalResult !== null
    return snapshot !== null && snapshot.flowId.length > 0 && snapshot.phaseSessionId.length > 0 &&
      snapshot.profileId.length > 0 && validPhase && validState && validTerminalResult && terminalMatchesState &&
      TimerStateCodec.isConfig(snapshot.config) &&
      TimerStateCodec.validInteger(snapshot.plannedSeconds, 1, 28800) &&
      Number.isFinite(snapshot.startedAt) && Number.isFinite(snapshot.deadlineAt) &&
      Number.isFinite(snapshot.accumulatedPausedMs) && snapshot.accumulatedPausedMs >= 0 &&
      TimerStateCodec.validInteger(snapshot.completedFocusRounds, 0, 1000000) &&
      Number.isFinite(snapshot.lastObservedAt) &&
      TimerStateCodec.validInteger(snapshot.lastKnownRemainingSeconds, 0, snapshot.plannedSeconds) &&
      Number.isFinite(snapshot.updatedAt)
  }

  private static validInteger(value: number, minimum: number, maximum: number): boolean {
    return Number.isFinite(value) && Math.round(value) === value && value >= minimum && value <= maximum
  }
}
