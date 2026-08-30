import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import {
  GuestDataSummary,
  SyncConflict,
  SyncEntityType,
  SyncMetadata,
  SyncMutation,
  SyncMutationState,
  SyncOperation
} from '../../domain/model/StudyModels'
import { SyncRepository } from '../../domain/repository/SyncRepository'
import { DatabaseTable, GUEST_PROFILE_ID } from '../database/DatabaseSchema'
import { ResultSetReader } from '../database/ResultSetReader'

export class LocalSyncRepository implements SyncRepository {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  async saveMetadata(metadata: SyncMetadata): Promise<void> {
    try {
      await this.store.executeSql(
        `INSERT INTO ${DatabaseTable.SYNC_METADATA} (profile_id, metadata_key, metadata_value, updated_at)
         VALUES (?, ?, ?, ?) ON CONFLICT(profile_id, metadata_key) DO UPDATE SET
         metadata_value=excluded.metadata_value, updated_at=excluded.updated_at`,
        [metadata.profileId, metadata.key, metadata.value, metadata.updatedAt])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to save sync metadata: ${JSON.stringify(error)}`)
    }
  }

  async findMetadata(profileId: string, key: string): Promise<SyncMetadata | null> {
    let resultSet: relationalStore.ResultSet | null = null
    try {
      resultSet = await this.store.querySql(
        `SELECT profile_id, metadata_key, metadata_value, updated_at FROM ${DatabaseTable.SYNC_METADATA}
         WHERE profile_id = ? AND metadata_key = ? LIMIT 1`, [profileId, key])
      if (!resultSet.goToFirstRow()) {
        return null
      }
      return {
        profileId: ResultSetReader.string(resultSet, 'profile_id'),
        key: ResultSetReader.string(resultSet, 'metadata_key'),
        value: ResultSetReader.string(resultSet, 'metadata_value'),
        updatedAt: ResultSetReader.number(resultSet, 'updated_at')
      }
    } finally {
      this.close(resultSet)
    }
  }

  async guestSummary(): Promise<GuestDataSummary> {
    const taskCount: number = await this.scalar(
      `SELECT COUNT(*) AS total FROM ${DatabaseTable.TASKS} WHERE profile_id = ? AND deleted_at IS NULL`,
      [GUEST_PROFILE_ID])
    const focusCount: number = await this.scalar(
      `SELECT COUNT(*) AS total FROM ${DatabaseTable.FOCUS_SESSIONS}
       WHERE profile_id = ? AND deleted_at IS NULL AND phase = 'focus' AND result = 'completed'`,
      [GUEST_PROFILE_ID])
    const points: number = await this.scalar(
      `SELECT COALESCE(SUM(awarded_points), 0) AS total FROM ${DatabaseTable.REWARD_EVENTS}
       WHERE profile_id = ?`, [GUEST_PROFILE_ID])
    return { taskCount: taskCount, focusCount: focusCount, points: points }
  }

  async removeMetadata(profileId: string, key: string): Promise<void> {
    await this.store.executeSql(
      `DELETE FROM ${DatabaseTable.SYNC_METADATA} WHERE profile_id = ? AND metadata_key = ?`,
      [profileId, key])
  }

  async saveMutation(mutation: SyncMutation): Promise<void> {
    await this.store.executeSql(
      `INSERT INTO ${DatabaseTable.SYNC_MUTATIONS} (
       mutation_id, profile_id, entity_type, entity_id, base_revision, operation, payload,
       state, attempt_count, last_error, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(mutation_id) DO UPDATE SET payload=excluded.payload, state=excluded.state,
       attempt_count=excluded.attempt_count, last_error=excluded.last_error, updated_at=excluded.updated_at`,
      [mutation.mutationId, mutation.profileId, mutation.entityType, mutation.entityId,
        mutation.baseRevision, mutation.operation, mutation.payload, mutation.state,
        mutation.attemptCount, mutation.lastError, mutation.createdAt, mutation.updatedAt])
  }

  async findMutations(profileId: string): Promise<SyncMutation[]> {
    let resultSet: relationalStore.ResultSet | null = null
    const mutations: SyncMutation[] = []
    try {
      resultSet = await this.store.querySql(
        `SELECT mutation_id, profile_id, entity_type, entity_id, base_revision, operation, payload,
         state, attempt_count, last_error, created_at, updated_at FROM ${DatabaseTable.SYNC_MUTATIONS}
         WHERE profile_id = ? ORDER BY created_at ASC`, [profileId])
      while (resultSet.goToNextRow()) {
        mutations.push(this.mapMutation(resultSet))
      }
      return mutations
    } finally {
      this.close(resultSet)
    }
  }

  async findMutation(profileId: string, entityType: string, entityId: string): Promise<SyncMutation | null> {
    let resultSet: relationalStore.ResultSet | null = null
    try {
      resultSet = await this.store.querySql(
        `SELECT mutation_id, profile_id, entity_type, entity_id, base_revision, operation, payload,
         state, attempt_count, last_error, created_at, updated_at FROM ${DatabaseTable.SYNC_MUTATIONS}
         WHERE profile_id = ? AND entity_type = ? AND entity_id = ? LIMIT 1`,
        [profileId, entityType, entityId])
      return resultSet.goToFirstRow() ? this.mapMutation(resultSet) : null
    } finally {
      this.close(resultSet)
    }
  }

  async removeMutation(mutationId: string): Promise<void> {
    await this.store.executeSql(
      `DELETE FROM ${DatabaseTable.SYNC_MUTATIONS} WHERE mutation_id = ?`, [mutationId])
  }

  async saveConflict(conflict: SyncConflict): Promise<void> {
    await this.store.executeSql(
      `INSERT OR REPLACE INTO ${DatabaseTable.SYNC_CONFLICTS} (
       id, profile_id, mutation_id, entity_type, entity_id, local_payload, server_payload,
       server_revision, created_at, resolved_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [conflict.id, conflict.profileId, conflict.mutationId, conflict.entityType, conflict.entityId,
        conflict.localPayload, conflict.serverPayload, conflict.serverRevision,
        conflict.createdAt, conflict.resolvedAt])
  }

  async findConflicts(profileId: string): Promise<SyncConflict[]> {
    let resultSet: relationalStore.ResultSet | null = null
    const conflicts: SyncConflict[] = []
    try {
      resultSet = await this.store.querySql(
        `SELECT id, profile_id, mutation_id, entity_type, entity_id, local_payload,
         server_payload, server_revision, created_at, resolved_at FROM ${DatabaseTable.SYNC_CONFLICTS}
         WHERE profile_id = ? AND resolved_at IS NULL ORDER BY created_at DESC`, [profileId])
      while (resultSet.goToNextRow()) {
        conflicts.push({
          id: ResultSetReader.string(resultSet, 'id'),
          profileId: ResultSetReader.string(resultSet, 'profile_id'),
          mutationId: ResultSetReader.nullableString(resultSet, 'mutation_id'),
          entityType: ResultSetReader.string(resultSet, 'entity_type') as SyncEntityType,
          entityId: ResultSetReader.string(resultSet, 'entity_id'),
          localPayload: ResultSetReader.string(resultSet, 'local_payload'),
          serverPayload: ResultSetReader.string(resultSet, 'server_payload'),
          serverRevision: ResultSetReader.number(resultSet, 'server_revision'),
          createdAt: ResultSetReader.number(resultSet, 'created_at'),
          resolvedAt: ResultSetReader.nullableNumber(resultSet, 'resolved_at')
        })
      }
      return conflicts
    } finally {
      this.close(resultSet)
    }
  }

  async resolveConflict(id: string, resolvedAt: number): Promise<void> {
    await this.store.executeSql(
      `UPDATE ${DatabaseTable.SYNC_CONFLICTS} SET resolved_at = ? WHERE id = ?`, [resolvedAt, id])
  }

  async deleteGuestData(): Promise<void> {
    let transaction: relationalStore.Transaction | null = null
    try {
      transaction = await this.store.createTransaction({
        transactionType: relationalStore.TransactionType.IMMEDIATE
      })
      await transaction.execute(`DELETE FROM ${DatabaseTable.ACHIEVEMENTS} WHERE profile_id = ?`,
        [GUEST_PROFILE_ID])
      await transaction.execute(`DELETE FROM ${DatabaseTable.REWARD_EVENTS} WHERE profile_id = ?`,
        [GUEST_PROFILE_ID])
      await transaction.execute(`DELETE FROM ${DatabaseTable.FOCUS_SESSIONS} WHERE profile_id = ?`,
        [GUEST_PROFILE_ID])
      await transaction.execute(`DELETE FROM ${DatabaseTable.TASKS} WHERE profile_id = ?`, [GUEST_PROFILE_ID])
      await transaction.execute(`DELETE FROM ${DatabaseTable.CATEGORIES} WHERE profile_id = ?`, [GUEST_PROFILE_ID])
      await transaction.execute(`DELETE FROM ${DatabaseTable.SETTINGS} WHERE profile_id = ?`, [GUEST_PROFILE_ID])
      await transaction.commit()
    } catch (error) {
      if (transaction !== null) {
        try {
          await transaction.rollback()
        } catch (rollbackError) {
        }
      }
      throw new AppError(AppErrorCode.DATABASE, `Unable to delete guest data: ${JSON.stringify(error)}`)
    }
  }

  private async scalar(sql: string, args: relationalStore.ValueType[]): Promise<number> {
    let resultSet: relationalStore.ResultSet | null = null
    try {
      resultSet = await this.store.querySql(sql, args)
      return resultSet.goToFirstRow() ? ResultSetReader.number(resultSet, 'total') : 0
    } finally {
      this.close(resultSet)
    }
  }

  private mapMutation(resultSet: relationalStore.ResultSet): SyncMutation {
    return {
      mutationId: ResultSetReader.string(resultSet, 'mutation_id'),
      profileId: ResultSetReader.string(resultSet, 'profile_id'),
      entityType: ResultSetReader.string(resultSet, 'entity_type') as SyncEntityType,
      entityId: ResultSetReader.string(resultSet, 'entity_id'),
      baseRevision: ResultSetReader.number(resultSet, 'base_revision'),
      operation: ResultSetReader.string(resultSet, 'operation') as SyncOperation,
      payload: ResultSetReader.string(resultSet, 'payload'),
      state: ResultSetReader.string(resultSet, 'state') as SyncMutationState,
      attemptCount: ResultSetReader.number(resultSet, 'attempt_count'),
      lastError: ResultSetReader.string(resultSet, 'last_error'),
      createdAt: ResultSetReader.number(resultSet, 'created_at'),
      updatedAt: ResultSetReader.number(resultSet, 'updated_at')
    }
  }

  private close(resultSet: relationalStore.ResultSet | null): void {
    if (resultSet !== null) {
      try {
        resultSet.close()
      } catch (error) {
      }
    }
  }
}
