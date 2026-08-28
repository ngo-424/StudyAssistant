import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { SyncState, TaskCategory } from '../../domain/model/StudyModels'
import { CategoryRepository } from '../../domain/repository/StudyRepositories'
import { DatabaseTable } from '../database/DatabaseSchema'
import { ResultSetReader } from '../database/ResultSetReader'

const CATEGORY_COLUMNS: string =
  'id, profile_id, name, color_seed, created_at, updated_at, deleted_at, revision, sync_state'

export class LocalCategoryRepository implements CategoryRepository {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  async save(category: TaskCategory): Promise<void> {
    const sql: string = `INSERT INTO ${DatabaseTable.CATEGORIES}
      (id, profile_id, name, color_seed, created_at, updated_at, deleted_at, revision, sync_state)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
       profile_id=excluded.profile_id, name=excluded.name, color_seed=excluded.color_seed,
       updated_at=excluded.updated_at, deleted_at=excluded.deleted_at,
       revision=excluded.revision, sync_state=excluded.sync_state`
    try {
      await this.store.executeSql(sql, [
        category.id, category.profileId, category.name, category.colorSeed, category.createdAt,
        category.updatedAt, category.deletedAt, category.revision, category.syncState
      ])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to save category: ${JSON.stringify(error)}`)
    }
  }

  async findAll(profileId: string): Promise<TaskCategory[]> {
    let resultSet: relationalStore.ResultSet | null = null
    const categories: TaskCategory[] = []
    try {
      resultSet = await this.store.querySql(
        `SELECT ${CATEGORY_COLUMNS} FROM ${DatabaseTable.CATEGORIES}
         WHERE profile_id = ? AND deleted_at IS NULL ORDER BY created_at ASC`, [profileId])
      while (resultSet.goToNextRow()) {
        categories.push({
          id: ResultSetReader.string(resultSet, 'id'),
          profileId: ResultSetReader.string(resultSet, 'profile_id'),
          name: ResultSetReader.string(resultSet, 'name'),
          colorSeed: ResultSetReader.string(resultSet, 'color_seed'),
          createdAt: ResultSetReader.number(resultSet, 'created_at'),
          updatedAt: ResultSetReader.number(resultSet, 'updated_at'),
          deletedAt: ResultSetReader.nullableNumber(resultSet, 'deleted_at'),
          revision: ResultSetReader.number(resultSet, 'revision'),
          syncState: ResultSetReader.string(resultSet, 'sync_state') as SyncState
        })
      }
      return categories
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to list categories: ${JSON.stringify(error)}`)
    } finally {
      this.close(resultSet)
    }
  }

  async softDelete(id: string, deletedAt: number): Promise<void> {
    try {
      await this.store.executeSql(
        `UPDATE ${DatabaseTable.CATEGORIES}
         SET deleted_at = ?, updated_at = ?, revision = revision + 1, sync_state = ? WHERE id = ?`,
        [deletedAt, deletedAt, SyncState.PENDING, id])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to delete category: ${JSON.stringify(error)}`)
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
