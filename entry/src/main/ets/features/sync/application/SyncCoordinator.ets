import { util } from '@kit.ArkTS'
import {
  FocusSession,
  RewardEvent,
  SettingEntry,
  StudyTask,
  SyncConflict,
  SyncEntityType,
  SyncMetadata,
  SyncMutation,
  SyncMutationState,
  SyncOperation,
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
import { SyncRepository } from '../../../domain/repository/SyncRepository'
import { AccountSession } from '../../auth/domain/AuthModels'
import {
  PullChangePayload,
  PullSyncResult,
  PushMutationPayload,
  PushMutationResult,
  PushSyncBody,
  PushSyncResult,
  ServerRecordPayload,
  SyncApi
} from '../domain/SyncApi'

const CURSOR_KEY: string = 'server_cursor'
const LAST_SYNCED_KEY: string = 'last_synced_at'
const CONFIG_KEY: string = 'focus_timer_config_v1'

export class SyncCoordinator {
  private readonly api: SyncApi
  private readonly syncRepository: SyncRepository
  private readonly tasks: TaskRepository
  private readonly categories: CategoryRepository
  private readonly sessions: FocusSessionRepository
  private readonly rewards: RewardRepository
  private readonly settings: SettingsRepository

  constructor(api: SyncApi, syncRepository: SyncRepository,
    tasks: TaskRepository, categories: CategoryRepository,
    sessions: FocusSessionRepository, rewards: RewardRepository,
    settings: SettingsRepository) {
    this.api = api
    this.syncRepository = syncRepository
    this.tasks = tasks
    this.categories = categories
    this.sessions = sessions
    this.rewards = rewards
    this.settings = settings
  }

  async synchronize(session: AccountSession): Promise<void> {
    const profileId: string = `account:${session.accountId}`
    await this.stagePending(profileId)
    await this.push(session.accessToken, profileId)
    await this.pull(session.accessToken, profileId)
    await this.syncRepository.saveMetadata({
      profileId: profileId, key: LAST_SYNCED_KEY, value: `${Date.now()}`, updatedAt: Date.now()
    })
  }

  async stagePending(profileId: string): Promise<void> {
    const categories: TaskCategory[] = await this.categories.findAll(profileId, true)
    for (let index: number = 0; index < categories.length; index++) {
      if (categories[index].syncState === SyncState.PENDING) {
        await this.stage(profileId, SyncEntityType.CATEGORY, categories[index].id,
          categories[index].deletedAt === null ? SyncOperation.UPSERT : SyncOperation.DELETE,
          JSON.stringify(categories[index]), categories[index].updatedAt)
      }
    }
    const tasks: StudyTask[] = await this.tasks.findAll(profileId, true)
    for (let index: number = 0; index < tasks.length; index++) {
      if (tasks[index].syncState === SyncState.PENDING) {
        await this.stage(profileId, SyncEntityType.TASK, tasks[index].id,
          tasks[index].deletedAt === null ? SyncOperation.UPSERT : SyncOperation.DELETE,
          JSON.stringify(tasks[index]), tasks[index].updatedAt)
      }
    }
    const sessions: FocusSession[] = await this.sessions.findAll(profileId)
    for (let index: number = 0; index < sessions.length; index++) {
      if (sessions[index].syncState === SyncState.PENDING) {
        await this.stage(profileId, SyncEntityType.FOCUS_SESSION, sessions[index].id,
          SyncOperation.UPSERT, JSON.stringify(sessions[index]), sessions[index].updatedAt)
      }
    }
    const events: RewardEvent[] = await this.rewards.findEvents(profileId)
    for (let index: number = 0; index < events.length; index++) {
      if (events[index].syncState === SyncState.PENDING) {
        await this.stage(profileId, SyncEntityType.REWARD_EVENT, events[index].id,
          SyncOperation.UPSERT, JSON.stringify(events[index]), events[index].awardedAt)
      }
    }
    const config: SettingEntry | null = await this.settings.find(profileId, CONFIG_KEY)
    if (config !== null) {
      await this.stage(profileId, SyncEntityType.SETTING, config.key,
        SyncOperation.UPSERT, JSON.stringify(config), config.updatedAt, true)
    }
  }

  async pendingCount(profileId: string): Promise<number> {
    const mutations: SyncMutation[] = await this.syncRepository.findMutations(profileId)
    return mutations.filter((mutation: SyncMutation) => mutation.state !== SyncMutationState.CONFLICT).length
  }

  async conflictCount(profileId: string): Promise<number> {
    return (await this.syncRepository.findConflicts(profileId)).length
  }

  async lastSyncedAt(profileId: string): Promise<number | null> {
    const metadata: SyncMetadata | null = await this.syncRepository.findMetadata(profileId, LAST_SYNCED_KEY)
    if (metadata === null) {
      return null
    }
    const value: number = Number.parseInt(metadata.value)
    return Number.isFinite(value) ? value : null
  }

  listConflicts(profileId: string): Promise<SyncConflict[]> {
    return this.syncRepository.findConflicts(profileId)
  }

  async resolveUsingCloud(conflict: SyncConflict): Promise<void> {
    await this.applyPayload(conflict.profileId, conflict.entityType,
      conflict.serverPayload, conflict.serverRevision)
    await this.saveServerMetadata(conflict.profileId, conflict.entityType,
      conflict.entityId, conflict.serverRevision, conflict.serverPayload)
    await this.syncRepository.resolveConflict(conflict.id, Date.now())
  }

  async resolveUsingLocal(conflict: SyncConflict): Promise<void> {
    const now: number = Date.now()
    await this.syncRepository.saveMutation({
      mutationId: util.generateRandomUUID(true), profileId: conflict.profileId,
      entityType: conflict.entityType, entityId: conflict.entityId,
      baseRevision: conflict.serverRevision, operation: SyncOperation.UPSERT,
      payload: conflict.localPayload, state: SyncMutationState.PENDING,
      attemptCount: 0, lastError: '', createdAt: now, updatedAt: now
    })
    await this.syncRepository.resolveConflict(conflict.id, now)
  }

  private async stage(profileId: string, entityType: SyncEntityType, entityId: string,
    operation: SyncOperation, payload: string, updatedAt: number, skipWhenUnchanged: boolean = false): Promise<void> {
    const payloadKey: string = `payload:${entityType}:${entityId}`
    if (skipWhenUnchanged) {
      const savedPayload: SyncMetadata | null = await this.syncRepository.findMetadata(profileId, payloadKey)
      if (savedPayload?.value === payload) {
        return
      }
    }
    const existing: SyncMutation | null = await this.syncRepository.findMutation(profileId, entityType, entityId)
    if (existing !== null && existing.state === SyncMutationState.CONFLICT) {
      return
    }
    const revisionMetadata: SyncMetadata | null = await this.syncRepository.findMetadata(
      profileId, `revision:${entityType}:${entityId}`)
    const baseRevision: number = revisionMetadata === null ? 0 : Number.parseInt(revisionMetadata.value)
    const now: number = Date.now()
    await this.syncRepository.saveMutation({
      mutationId: existing?.mutationId ?? util.generateRandomUUID(true),
      profileId: profileId,
      entityType: entityType,
      entityId: entityId,
      baseRevision: Number.isFinite(baseRevision) ? baseRevision : 0,
      operation: operation,
      payload: payload,
      state: SyncMutationState.PENDING,
      attemptCount: existing?.attemptCount ?? 0,
      lastError: '',
      createdAt: existing?.createdAt ?? now,
      updatedAt: updatedAt
    })
  }

  private async push(accessToken: string, profileId: string): Promise<void> {
    const allMutations: SyncMutation[] = await this.syncRepository.findMutations(profileId)
    const mutations: SyncMutation[] = allMutations.filter((mutation: SyncMutation) =>
      mutation.state === SyncMutationState.PENDING || mutation.state === SyncMutationState.FAILED)
    if (mutations.length === 0) {
      return
    }
    const payloads: PushMutationPayload[] = []
    for (let index: number = 0; index < mutations.length; index++) {
      const mutation: SyncMutation = mutations[index]
      const payload: PushMutationPayload = {
        mutationId: mutation.mutationId,
        entityType: mutation.entityType,
        entityId: mutation.entityId,
        baseRevision: mutation.baseRevision,
        operation: mutation.operation,
        payload: JSON.parse(mutation.payload) as Object,
        updatedAt: mutation.updatedAt
      }
      payloads.push(payload)
    }
    try {
      const response: PushSyncResult = await this.api.push(accessToken, { mutations: payloads } as PushSyncBody)
      for (let index: number = 0; index < response.results.length; index++) {
        await this.handlePushResult(profileId, response.results[index])
      }
    } catch (error) {
      for (let index: number = 0; index < mutations.length; index++) {
        const mutation: SyncMutation = mutations[index]
        mutation.state = SyncMutationState.FAILED
        mutation.attemptCount++
        mutation.lastError = 'NETWORK_OR_SERVER_ERROR'
        await this.syncRepository.saveMutation(mutation)
      }
      throw new Error(error instanceof Error ? error.message : 'Synchronization failed')
    }
  }

  private async handlePushResult(profileId: string, result: PushMutationResult): Promise<void> {
    const mutations: SyncMutation[] = await this.syncRepository.findMutations(profileId)
    const mutation: SyncMutation | undefined = mutations.find((item: SyncMutation) =>
      item.mutationId === result.mutationId)
    if (mutation === undefined) {
      return
    }
    if (result.status === 'applied') {
      await this.applyPayload(profileId, mutation.entityType, mutation.payload, result.revision)
      await this.saveServerMetadata(profileId, mutation.entityType, mutation.entityId,
        result.revision, mutation.payload)
      await this.syncRepository.removeMutation(mutation.mutationId)
      return
    }
    if (result.serverRecord !== undefined) {
      await this.preserveConflict(profileId, mutation, result.serverRecord)
    }
  }

  private async pull(accessToken: string, profileId: string): Promise<void> {
    const cursorMetadata: SyncMetadata | null = await this.syncRepository.findMetadata(profileId, CURSOR_KEY)
    let cursor: string = cursorMetadata?.value ?? '0'
    let hasMore: boolean = true
    while (hasMore) {
      const response: PullSyncResult = await this.api.pull(accessToken, cursor)
      for (let index: number = 0; index < response.changes.length; index++) {
        await this.applyChange(profileId, response.changes[index])
      }
      cursor = response.nextCursor
      hasMore = response.hasMore
      await this.syncRepository.saveMetadata({
        profileId: profileId, key: CURSOR_KEY, value: cursor, updatedAt: Date.now()
      })
    }
  }

  private async applyChange(profileId: string, change: PullChangePayload): Promise<void> {
    const pending: SyncMutation | null = await this.syncRepository.findMutation(
      profileId, change.entityType, change.entityId)
    const serverPayload: string = JSON.stringify(change.payload)
    if (pending !== null) {
      await this.preserveConflict(profileId, pending, change)
      return
    }
    await this.applyPayload(profileId, change.entityType, serverPayload, change.revision)
    await this.saveServerMetadata(profileId, change.entityType, change.entityId,
      change.revision, serverPayload)
  }

  private async preserveConflict(profileId: string, mutation: SyncMutation,
    server: ServerRecordPayload): Promise<void> {
    const conflict: SyncConflict = {
      id: util.generateRandomUUID(true), profileId: profileId, mutationId: mutation.mutationId,
      entityType: mutation.entityType, entityId: mutation.entityId,
      localPayload: mutation.payload, serverPayload: JSON.stringify(server.payload),
      serverRevision: server.revision, createdAt: Date.now(), resolvedAt: null
    }
    await this.syncRepository.saveConflict(conflict)
    await this.syncRepository.removeMutation(mutation.mutationId)
  }

  private async saveServerMetadata(profileId: string, entityType: SyncEntityType, entityId: string,
    revision: number, payload: string): Promise<void> {
    const now: number = Date.now()
    await this.syncRepository.saveMetadata({
      profileId: profileId, key: `revision:${entityType}:${entityId}`,
      value: `${revision}`, updatedAt: now
    })
    await this.syncRepository.saveMetadata({
      profileId: profileId, key: `payload:${entityType}:${entityId}`,
      value: payload, updatedAt: now
    })
  }

  private async applyPayload(profileId: string, entityType: SyncEntityType,
    payload: string, revision: number): Promise<void> {
    if (entityType === SyncEntityType.TASK) {
      const task: StudyTask = JSON.parse(payload) as StudyTask
      task.profileId = profileId
      task.revision = revision
      task.syncState = SyncState.SYNCED
      await this.tasks.save(task)
    } else if (entityType === SyncEntityType.CATEGORY) {
      const category: TaskCategory = JSON.parse(payload) as TaskCategory
      category.profileId = profileId
      category.revision = revision
      category.syncState = SyncState.SYNCED
      await this.categories.save(category)
    } else if (entityType === SyncEntityType.FOCUS_SESSION) {
      const session: FocusSession = JSON.parse(payload) as FocusSession
      session.profileId = profileId
      session.revision = revision
      session.syncState = SyncState.SYNCED
      await this.sessions.save(session)
    } else if (entityType === SyncEntityType.REWARD_EVENT) {
      const event: RewardEvent = JSON.parse(payload) as RewardEvent
      event.profileId = profileId
      event.syncState = SyncState.SYNCED
      await this.rewards.saveEvent(event)
    } else if (entityType === SyncEntityType.SETTING) {
      const setting: SettingEntry = JSON.parse(payload) as SettingEntry
      setting.profileId = profileId
      await this.settings.save(setting)
    }
  }
}
