import {
  AchievementProgress,
  FocusSession,
  RewardEvent,
  SettingEntry,
  StudyTask,
  TaskCategory
} from '../../../domain/model/StudyModels'

export interface ExportedFocusSession {
  id: string
  taskId: string | null
  categoryId: string | null
  phase: string
  plannedSeconds: number
  focusedSeconds: number
  startedAt: number
  endedAt: number
  result: string
  createdAt: number
  updatedAt: number
}

export interface DataExportDocument {
  schemaVersion: number
  application: string
  generatedAt: number
  profileType: string
  categories: TaskCategory[]
  tasks: StudyTask[]
  focusSessions: ExportedFocusSession[]
  rewardEvents: RewardEvent[]
  achievements: AchievementProgress[]
  settings: SettingEntry[]
}

export class DataExportSerializer {
  static build(profileType: string, generatedAt: number,
    categories: TaskCategory[], tasks: StudyTask[], sessions: FocusSession[],
    rewards: RewardEvent[], achievements: AchievementProgress[], settings: SettingEntry[]): DataExportDocument {
    return {
      schemaVersion: 1,
      application: '时芽',
      generatedAt: generatedAt,
      profileType: profileType,
      categories: categories,
      tasks: tasks,
      focusSessions: sessions.map((session: FocusSession): ExportedFocusSession => ({
        id: session.id,
        taskId: session.taskId,
        categoryId: session.categoryId,
        phase: session.phase,
        plannedSeconds: session.plannedSeconds,
        focusedSeconds: session.focusedSeconds,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        result: session.result,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt
      })),
      rewardEvents: rewards,
      achievements: achievements,
      settings: settings.filter((entry: SettingEntry): boolean =>
        entry.key === 'focus_timer_config_v1')
    }
  }

  static serialize(document: DataExportDocument): string {
    return JSON.stringify(document, null, 2)
  }
}
