import {
  ActiveTimerSnapshot,
  AchievementProgress,
  FocusSession,
  RewardEvent,
  SettingEntry,
  StudyTask,
  SyncMetadata,
  TaskCategory,
  TimerConfig
} from '../model/StudyModels'

export interface TaskRepository {
  save(task: StudyTask): Promise<void>
  findById(id: string): Promise<StudyTask | null>
  findAll(profileId: string, includeDeleted?: boolean): Promise<StudyTask[]>
  softDelete(id: string, deletedAt: number): Promise<void>
}

export interface CategoryRepository {
  save(category: TaskCategory): Promise<void>
  findAll(profileId: string, includeDeleted?: boolean): Promise<TaskCategory[]>
  softDelete(id: string, deletedAt: number): Promise<void>
}

export interface FocusSessionRepository {
  save(session: FocusSession): Promise<void>
  findAll(profileId: string): Promise<FocusSession[]>
}

export interface RewardRepository {
  saveEvent(event: RewardEvent): Promise<void>
  saveAchievement(progress: AchievementProgress): Promise<void>
  findEvents(profileId: string): Promise<RewardEvent[]>
}

export interface SettingsRepository {
  save(entry: SettingEntry): Promise<void>
  find(profileId: string, key: string): Promise<SettingEntry | null>
  remove(profileId: string, key: string): Promise<void>
}

export interface TimerStateRepository {
  saveConfig(profileId: string, config: TimerConfig): Promise<void>
  loadConfig(profileId: string): Promise<TimerConfig | null>
  saveSnapshot(snapshot: ActiveTimerSnapshot): Promise<void>
  loadSnapshot(profileId: string): Promise<ActiveTimerSnapshot | null>
  clearSnapshot(profileId: string): Promise<void>
  getOrCreateDeviceId(profileId: string, idFactory: () => string): Promise<string>
}

export interface SyncMetadataRepository {
  save(metadata: SyncMetadata): Promise<void>
  find(profileId: string, key: string): Promise<SyncMetadata | null>
}
