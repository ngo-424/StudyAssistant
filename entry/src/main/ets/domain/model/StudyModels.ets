export enum TaskStatus {
  TODO = 'todo',
  COMPLETED = 'completed'
}

export enum FocusPhase {
  FOCUS = 'focus',
  SHORT_BREAK = 'short_break',
  LONG_BREAK = 'long_break'
}

export enum FocusResult {
  COMPLETED = 'completed',
  ABANDONED = 'abandoned',
  INTERRUPTED = 'interrupted'
}

export enum SyncState {
  LOCAL_ONLY = 'local_only',
  PENDING = 'pending',
  SYNCED = 'synced',
  CONFLICT = 'conflict'
}

export enum TimerRunState {
  IDLE = 'idle',
  RUNNING = 'running',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  ABANDONED = 'abandoned'
}

export interface TimerConfig {
  focusMinutes: number
  shortBreakMinutes: number
  longBreakMinutes: number
  longBreakEvery: number
}

export interface ActiveTimerSnapshot {
  flowId: string
  phaseSessionId: string
  profileId: string
  taskId: string | null
  categoryId: string | null
  phase: FocusPhase
  state: TimerRunState
  terminalResult: FocusResult | null
  config: TimerConfig
  plannedSeconds: number
  startedAt: number
  deadlineAt: number
  pausedAt: number | null
  remainingSecondsAtPause: number | null
  accumulatedPausedMs: number
  completedFocusRounds: number
  lastObservedAt: number
  lastKnownRemainingSeconds: number
  updatedAt: number
}

export interface TaskCategory {
  id: string
  profileId: string
  name: string
  colorSeed: string
  createdAt: number
  updatedAt: number
  deletedAt: number | null
  revision: number
  syncState: SyncState
}

export interface StudyTask {
  id: string
  profileId: string
  title: string
  notes: string
  categoryId: string | null
  plannedMinutes: number
  dueAt: number | null
  status: TaskStatus
  completedAt: number | null
  createdAt: number
  updatedAt: number
  deletedAt: number | null
  revision: number
  syncState: SyncState
}

export interface FocusSession {
  id: string
  profileId: string
  taskId: string | null
  categoryId: string | null
  deviceId: string
  phase: FocusPhase
  plannedSeconds: number
  focusedSeconds: number
  startedAt: number
  endedAt: number
  result: FocusResult
  createdAt: number
  updatedAt: number
  deletedAt: number | null
  revision: number
  syncState: SyncState
}

export interface RewardEvent {
  id: string
  profileId: string
  sessionId: string
  ruleVersion: number
  basePoints: number
  multiplier: number
  awardedPoints: number
  awardedAt: number
  syncState: SyncState
}

export interface AchievementProgress {
  id: string
  profileId: string
  achievementKey: string
  currentValue: number
  targetValue: number
  unlockedAt: number | null
  updatedAt: number
  syncState: SyncState
}

export interface SettingEntry {
  profileId: string
  key: string
  value: string
  updatedAt: number
}

export interface SyncMetadata {
  profileId: string
  key: string
  value: string
  updatedAt: number
}
