import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { FocusPhase, FocusResult, FocusSession, SyncState } from '../../domain/model/StudyModels'
import { FocusSessionRepository } from '../../domain/repository/StudyRepositories'
import { DatabaseTable } from '../database/DatabaseSchema'
import { ResultSetReader } from '../database/ResultSetReader'

const SESSION_COLUMNS: string = `id, profile_id, task_id, category_id, device_id, phase,
  planned_seconds, focused_seconds, started_at, ended_at, result, created_at, updated_at,
  deleted_at, revision, sync_state`

export class LocalFocusSessionRepository implements FocusSessionRepository {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  async save(session: FocusSession): Promise<void> {
    try {
      await this.store.executeSql(
        `INSERT INTO ${DatabaseTable.FOCUS_SESSIONS}
         (id, profile_id, task_id, category_id, device_id, phase, planned_seconds,
          focused_seconds, started_at, ended_at, result, created_at, updated_at,
          deleted_at, revision, sync_state)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
          task_id=excluded.task_id, category_id=excluded.category_id,
          focused_seconds=excluded.focused_seconds, ended_at=excluded.ended_at,
          result=excluded.result, updated_at=excluded.updated_at,
          revision=excluded.revision, sync_state=excluded.sync_state`,
        [
          session.id, session.profileId, session.taskId, session.categoryId, session.deviceId,
          session.phase, session.plannedSeconds, session.focusedSeconds, session.startedAt,
          session.endedAt, session.result, session.createdAt, session.updatedAt, session.deletedAt,
          session.revision, session.syncState
        ])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to save focus session: ${JSON.stringify(error)}`)
    }
  }

  async findAll(profileId: string): Promise<FocusSession[]> {
    let resultSet: relationalStore.ResultSet | null = null
    const sessions: FocusSession[] = []
    try {
      resultSet = await this.store.querySql(
        `SELECT ${SESSION_COLUMNS} FROM ${DatabaseTable.FOCUS_SESSIONS}
         WHERE profile_id = ? AND deleted_at IS NULL ORDER BY started_at DESC`, [profileId])
      while (resultSet.goToNextRow()) {
        sessions.push(this.map(resultSet))
      }
      return sessions
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to list focus sessions: ${JSON.stringify(error)}`)
    } finally {
      if (resultSet !== null) {
        try {
          resultSet.close()
        } catch (closeError) {
        }
      }
    }
  }

  private map(resultSet: relationalStore.ResultSet): FocusSession {
    return {
      id: ResultSetReader.string(resultSet, 'id'),
      profileId: ResultSetReader.string(resultSet, 'profile_id'),
      taskId: ResultSetReader.nullableString(resultSet, 'task_id'),
      categoryId: ResultSetReader.nullableString(resultSet, 'category_id'),
      deviceId: ResultSetReader.string(resultSet, 'device_id'),
      phase: ResultSetReader.string(resultSet, 'phase') as FocusPhase,
      plannedSeconds: ResultSetReader.number(resultSet, 'planned_seconds'),
      focusedSeconds: ResultSetReader.number(resultSet, 'focused_seconds'),
      startedAt: ResultSetReader.number(resultSet, 'started_at'),
      endedAt: ResultSetReader.number(resultSet, 'ended_at'),
      result: ResultSetReader.string(resultSet, 'result') as FocusResult,
      createdAt: ResultSetReader.number(resultSet, 'created_at'),
      updatedAt: ResultSetReader.number(resultSet, 'updated_at'),
      deletedAt: ResultSetReader.nullableNumber(resultSet, 'deleted_at'),
      revision: ResultSetReader.number(resultSet, 'revision'),
      syncState: ResultSetReader.string(resultSet, 'sync_state') as SyncState
    }
  }
}
