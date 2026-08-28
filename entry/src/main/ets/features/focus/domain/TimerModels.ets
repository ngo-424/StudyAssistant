import {
  ActiveTimerSnapshot,
  FocusPhase,
  FocusResult,
  TimerConfig
} from '../../../domain/model/StudyModels'

export interface TimerStartContext {
  profileId: string
  taskId: string | null
  categoryId: string | null
}

export interface TimerReading {
  remainingSeconds: number
  elapsedSeconds: number
  progress: number
  clockAdjusted: boolean
}

export interface TimerPhaseOutcome {
  sessionId: string
  profileId: string
  taskId: string | null
  categoryId: string | null
  phase: FocusPhase
  plannedSeconds: number
  focusedSeconds: number
  startedAt: number
  endedAt: number
  result: FocusResult
}

export interface TimerTransition {
  snapshot: ActiveTimerSnapshot
  reading: TimerReading
  outcome: TimerPhaseOutcome | null
}

export interface TimerRuntimeState {
  config: TimerConfig
  snapshot: ActiveTimerSnapshot | null
  reading: TimerReading | null
}
