import { StudyTask, SyncState, TaskStatus } from '../../domain/model/StudyModels'
import { GUEST_PROFILE_ID } from '../database/DatabaseSchema'

interface LegacyTaskItem {
  code?: string
  title?: string
  subtitle?: string
  status?: string
}

interface LegacyStudyData {
  focusMinutes?: number
  completedCount?: number
  tasks?: LegacyTaskItem[]
}

export interface LegacyTaskCandidate {
  task: StudyTask
  legacyCode: string | null
}

export class LegacyDataParser {
  static parse(jsonText: string, migratedAt: number, idFactory: () => string): LegacyTaskCandidate[] {
    const legacyData: LegacyStudyData = JSON.parse(jsonText) as LegacyStudyData
    if (legacyData.tasks === undefined || !Array.isArray(legacyData.tasks)) {
      return []
    }

    const candidates: LegacyTaskCandidate[] = []
    for (let index: number = 0; index < legacyData.tasks.length; index++) {
      const source: LegacyTaskItem = legacyData.tasks[index]
      const title: string = source.title?.trim() ?? ''
      if (title.length === 0) {
        continue
      }

      const completed: boolean = source.status === '已完成'
      const task: StudyTask = {
        id: idFactory(),
        profileId: GUEST_PROFILE_ID,
        title: title.substring(0, 120),
        notes: '',
        categoryId: null,
        plannedMinutes: LegacyDataParser.readMinutes(source.subtitle ?? ''),
        dueAt: null,
        status: completed ? TaskStatus.COMPLETED : TaskStatus.TODO,
        completedAt: completed ? migratedAt : null,
        createdAt: migratedAt,
        updatedAt: migratedAt,
        deletedAt: null,
        revision: 0,
        syncState: SyncState.LOCAL_ONLY
      }
      candidates.push({
        task: task,
        legacyCode: LegacyDataParser.cleanLegacyCode(source.code)
      })
    }
    return candidates
  }

  private static readMinutes(subtitle: string): number {
    const match: RegExpMatchArray | null = subtitle.match(/(\d+)\s*分钟/)
    if (match === null || match.length < 2) {
      return 25
    }
    const minutes: number = Number(match[1])
    if (!Number.isFinite(minutes)) {
      return 25
    }
    return Math.min(90, Math.max(5, Math.round(minutes)))
  }

  private static cleanLegacyCode(code: string | undefined): string | null {
    const cleanCode: string = code?.trim() ?? ''
    return cleanCode.length === 0 ? null : cleanCode.substring(0, 64)
  }
}
