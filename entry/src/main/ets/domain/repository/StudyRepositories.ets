import {
  AchievementProgress,
  FocusSession,
  RewardEvent,
  SettingEntry,
  StudyTask,
  SyncMetadata,
  TaskCategory
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
}

export interface SettingsRepository {
  save(entry: SettingEntry): Promise<void>
  find(profileId: string, key: string): Promise<SettingEntry | null>
}

export interface SyncMetadataRepository {
  save(metadata: SyncMetadata): Promise<void>
  find(profileId: string, key: string): Promise<SyncMetadata | null>
}
