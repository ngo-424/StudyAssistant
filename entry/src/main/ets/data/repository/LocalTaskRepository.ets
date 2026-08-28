import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { StudyTask, SyncState, TaskStatus } from '../../domain/model/StudyModels'
import { TaskRepository } from '../../domain/repository/StudyRepositories'
import { DatabaseTable } from '../database/DatabaseSchema'
import { ResultSetReader } from '../database/ResultSetReader'

const TASK_COLUMNS: string = `id, profile_id, title, notes, category_id, planned_minutes, due_at,
  status, completed_at, created_at, updated_at, deleted_at, revision, sync_state`

export class LocalTaskRepository implements TaskRepository {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  async save(task: StudyTask): Promise<void> {
    const sql: string = `INSERT INTO ${DatabaseTable.TASKS}
      (id, profile_id, title, notes, category_id, planned_minutes, due_at, status, completed_at,
       created_at, updated_at, deleted_at, revision, sync_state)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
       profile_id=excluded.profile_id, title=excluded.title, notes=excluded.notes,
       category_id=excluded.category_id, planned_minutes=excluded.planned_minutes,
       due_at=excluded.due_at, status=excluded.status, completed_at=excluded.completed_at,
       updated_at=excluded.updated_at, deleted_at=excluded.deleted_at,
       revision=excluded.revision, sync_state=excluded.sync_state`
    try {
      await this.store.executeSql(sql, [
        task.id, task.profileId, task.title, task.notes, task.categoryId, task.plannedMinutes,
        task.dueAt, task.status, task.completedAt, task.createdAt, task.updatedAt, task.deletedAt,
        task.revision, task.syncState
      ])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to save task: ${JSON.stringify(error)}`)
    }
  }

  async findById(id: string): Promise<StudyTask | null> {
    let resultSet: relationalStore.ResultSet | null = null
    try {
      resultSet = await this.store.querySql(
        `SELECT ${TASK_COLUMNS} FROM ${DatabaseTable.TASKS} WHERE id = ? LIMIT 1`, [id])
      return resultSet.goToFirstRow() ? this.map(resultSet) : null
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to find task: ${JSON.stringify(error)}`)
    } finally {
      this.close(resultSet)
    }
  }

  async findAll(profileId: string, includeDeleted: boolean = false): Promise<StudyTask[]> {
    let resultSet: relationalStore.ResultSet | null = null
    const tasks: StudyTask[] = []
    try {
      const deletedClause: string = includeDeleted ? '' : 'AND deleted_at IS NULL'
      resultSet = await this.store.querySql(
        `SELECT ${TASK_COLUMNS} FROM ${DatabaseTable.TASKS}
         WHERE profile_id = ? ${deletedClause}
         ORDER BY CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, due_at ASC, created_at DESC`, [profileId])
      while (resultSet.goToNextRow()) {
        tasks.push(this.map(resultSet))
      }
      return tasks
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to list tasks: ${JSON.stringify(error)}`)
    } finally {
      this.close(resultSet)
    }
  }

  async softDelete(id: string, deletedAt: number): Promise<void> {
    try {
      await this.store.executeSql(
        `UPDATE ${DatabaseTable.TASKS}
         SET deleted_at = ?, updated_at = ?, revision = revision + 1,
         sync_state = CASE WHEN sync_state = 'local_only' THEN 'local_only' ELSE ? END WHERE id = ?`,
        [deletedAt, deletedAt, SyncState.PENDING, id])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to delete task: ${JSON.stringify(error)}`)
    }
  }

  private map(resultSet: relationalStore.ResultSet): StudyTask {
    return {
      id: ResultSetReader.string(resultSet, 'id'),
      profileId: ResultSetReader.string(resultSet, 'profile_id'),
      title: ResultSetReader.string(resultSet, 'title'),
      notes: ResultSetReader.string(resultSet, 'notes'),
      categoryId: ResultSetReader.nullableString(resultSet, 'category_id'),
      plannedMinutes: ResultSetReader.number(resultSet, 'planned_minutes'),
      dueAt: ResultSetReader.nullableNumber(resultSet, 'due_at'),
      status: ResultSetReader.string(resultSet, 'status') as TaskStatus,
      completedAt: ResultSetReader.nullableNumber(resultSet, 'completed_at'),
      createdAt: ResultSetReader.number(resultSet, 'created_at'),
      updatedAt: ResultSetReader.number(resultSet, 'updated_at'),
      deletedAt: ResultSetReader.nullableNumber(resultSet, 'deleted_at'),
      revision: ResultSetReader.number(resultSet, 'revision'),
      syncState: ResultSetReader.string(resultSet, 'sync_state') as SyncState
    }
  }

  private close(resultSet: relationalStore.ResultSet | null): void {
    if (resultSet === null) {
      return
    }
    try {
      resultSet.close()
    } catch (error) {
    }
  }
}
