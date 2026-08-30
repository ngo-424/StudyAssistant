import { util } from '@kit.ArkTS'
import {
  FocusSession,
  RewardEvent,
  SettingEntry,
  StudyTask,
  SyncMetadata,
  SyncState,
  TaskCategory
} from '../../../domain/model/StudyModels'
import {
  CategoryRepository,
  FocusSessionRepository,
  RewardRepository,
  SettingsRepository,
  TaskRepository
} from '../../../domain/repository/StudyRepositories'
import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'
import { SyncRepository } from '../../../domain/repository/SyncRepository'

const CONFIG_KEY: string = 'focus_timer_config_v1'

export interface GuestMergeResult {
  tasks: number
  sessions: number
  rewards: number
}

export class GuestMergeService {
  private readonly tasks: TaskRepository
  private readonly categories: CategoryRepository
  private readonly sessions: FocusSessionRepository
  private readonly rewards: RewardRepository
  private readonly settings: SettingsRepository
  private readonly syncRepository: SyncRepository

  constructor(tasks: TaskRepository, categories: CategoryRepository,
    sessions: FocusSessionRepository, rewards: RewardRepository, settings: SettingsRepository,
    syncRepository: SyncRepository) {
    this.tasks = tasks
    this.categories = categories
    this.sessions = sessions
    this.rewards = rewards
    this.settings = settings
    this.syncRepository = syncRepository
  }

  async merge(accountProfileId: string): Promise<GuestMergeResult> {
    const categoryMap: Map<string, string> = new Map<string, string>()
    const taskMap: Map<string, string> = new Map<string, string>()
    const sessionMap: Map<string, string> = new Map<string, string>()
    const accountCategories: TaskCategory[] = await this.categories.findAll(accountProfileId, true)
    const categories: TaskCategory[] = await this.categories.findAll(GUEST_PROFILE_ID, true)
    for (let index: number = 0; index < categories.length; index++) {
      const source: TaskCategory = categories[index]
      const id: string = await this.mappedId(accountProfileId, 'category', source.id)
      const existing: TaskCategory | undefined = accountCategories.find((item: TaskCategory) => item.id === id)
      categoryMap.set(source.id, id)
      await this.categories.save({
        id: id, profileId: accountProfileId, name: source.name, colorSeed: source.colorSeed,
        createdAt: source.createdAt, updatedAt: source.updatedAt, deletedAt: source.deletedAt,
        revision: existing?.revision ?? 0, syncState: SyncState.PENDING
      })
    }

    const tasks: StudyTask[] = await this.tasks.findAll(GUEST_PROFILE_ID, true)
    for (let index: number = 0; index < tasks.length; index++) {
      const source: StudyTask = tasks[index]
      const id: string = await this.mappedId(accountProfileId, 'task', source.id)
      const existing: StudyTask | null = await this.tasks.findById(id)
      taskMap.set(source.id, id)
      await this.tasks.save({
        id: id, profileId: accountProfileId, title: source.title, notes: source.notes,
        categoryId: source.categoryId === null ? null : categoryMap.get(source.categoryId) ?? null,
        plannedMinutes: source.plannedMinutes, dueAt: source.dueAt, status: source.status,
        completedAt: source.completedAt, createdAt: source.createdAt, updatedAt: source.updatedAt,
        deletedAt: source.deletedAt, revision: existing?.revision ?? 0, syncState: SyncState.PENDING
      })
    }

    const accountSessions: FocusSession[] = await this.sessions.findAll(accountProfileId)
    const sessions: FocusSession[] = await this.sessions.findAll(GUEST_PROFILE_ID)
    for (let index: number = 0; index < sessions.length; index++) {
      const source: FocusSession = sessions[index]
      const id: string = await this.mappedId(accountProfileId, 'focus_session', source.id)
      const existing: FocusSession | undefined = accountSessions.find((item: FocusSession) => item.id === id)
      sessionMap.set(source.id, id)
      await this.sessions.save({
        id: id, profileId: accountProfileId,
        taskId: source.taskId === null ? null : taskMap.get(source.taskId) ?? null,
        categoryId: source.categoryId === null ? null : categoryMap.get(source.categoryId) ?? null,
        deviceId: source.deviceId, phase: source.phase, plannedSeconds: source.plannedSeconds,
        focusedSeconds: source.focusedSeconds, startedAt: source.startedAt, endedAt: source.endedAt,
        result: source.result, createdAt: source.createdAt, updatedAt: source.updatedAt,
        deletedAt: source.deletedAt, revision: existing?.revision ?? 0, syncState: SyncState.PENDING
      })
    }

    const events: RewardEvent[] = await this.rewards.findEvents(GUEST_PROFILE_ID)
    let rewardCount: number = 0
    for (let index: number = 0; index < events.length; index++) {
      const source: RewardEvent = events[index]
      const sessionId: string | undefined = sessionMap.get(source.sessionId)
      if (sessionId === undefined) {
        continue
      }
      const id: string = await this.mappedId(accountProfileId, 'reward_event', source.id)
      await this.rewards.saveEvent({
        id: id, profileId: accountProfileId, sessionId: sessionId,
        ruleVersion: source.ruleVersion, basePoints: source.basePoints, multiplier: source.multiplier,
        awardedPoints: source.awardedPoints, awardedAt: source.awardedAt, syncState: SyncState.PENDING
      })
      rewardCount++
    }

    const config: SettingEntry | null = await this.settings.find(GUEST_PROFILE_ID, CONFIG_KEY)
    if (config !== null) {
      await this.settings.save({
        profileId: accountProfileId, key: config.key, value: config.value, updatedAt: config.updatedAt
      })
    }
    return { tasks: tasks.length, sessions: sessions.length, rewards: rewardCount }
  }

  private async mappedId(profileId: string, entityType: string, sourceId: string): Promise<string> {
    const key: string = `guest_map:${entityType}:${sourceId}`
    const existing: SyncMetadata | null = await this.syncRepository.findMetadata(profileId, key)
    if (existing !== null) {
      return existing.value
    }
    const id: string = util.generateRandomUUID(true)
    await this.syncRepository.saveMetadata({
      profileId: profileId, key: key, value: id, updatedAt: Date.now()
    })
    return id
  }
}
