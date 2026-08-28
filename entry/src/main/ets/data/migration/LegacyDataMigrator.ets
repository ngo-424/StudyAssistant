import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { util } from '@kit.ArkTS'
import { fileIo } from '@kit.CoreFileKit'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { DatabaseTable } from '../database/DatabaseSchema'
import { LegacyDataParser, LegacyTaskCandidate } from './LegacyDataParser'

const LEGACY_MIGRATION_KEY: string = 'legacy_study_data_json_v1'
const LEGACY_FILE_NAME: string = 'study_data.json'

export enum LegacyMigrationStatus {
  SKIPPED = 'skipped',
  NO_FILE = 'no_file',
  MIGRATED = 'migrated',
  FAILED = 'failed'
}

export interface LegacyMigrationResult {
  status: LegacyMigrationStatus
  importedCount: number
}

export class LegacyDataMigrator {
  static async migrate(context: common.UIAbilityContext,
    store: relationalStore.RdbStore): Promise<LegacyMigrationResult> {
    if (await LegacyDataMigrator.hasCompleted(store)) {
      return { status: LegacyMigrationStatus.SKIPPED, importedCount: 0 }
    }

    const legacyPath: string = `${context.filesDir}/${LEGACY_FILE_NAME}`
    if (!await LegacyDataMigrator.fileExists(legacyPath)) {
      await LegacyDataMigrator.markCompleted(store, LegacyMigrationStatus.NO_FILE, 0)
      return { status: LegacyMigrationStatus.NO_FILE, importedCount: 0 }
    }

    try {
      const jsonText: string = await fileIo.readText(legacyPath)
      const migratedAt: number = Date.now()
      const candidates: LegacyTaskCandidate[] = LegacyDataParser.parse(
        jsonText, migratedAt, () => util.generateRandomUUID(true))
      await LegacyDataMigrator.importCandidates(store, candidates, migratedAt)
      return { status: LegacyMigrationStatus.MIGRATED, importedCount: candidates.length }
    } catch (error) {
      return { status: LegacyMigrationStatus.FAILED, importedCount: 0 }
    }
  }

  private static async hasCompleted(store: relationalStore.RdbStore): Promise<boolean> {
    let resultSet: relationalStore.ResultSet | null = null
    try {
      resultSet = await store.querySql(
        `SELECT migration_key FROM ${DatabaseTable.MIGRATION_HISTORY} WHERE migration_key = ? LIMIT 1`,
        [LEGACY_MIGRATION_KEY])
      return resultSet.goToFirstRow()
    } catch (error) {
      throw new AppError(AppErrorCode.MIGRATION,
        `Unable to read migration history: ${JSON.stringify(error)}`)
    } finally {
      if (resultSet !== null) {
        try {
          resultSet.close()
        } catch (closeError) {
        }
      }
    }
  }

  private static async fileExists(path: string): Promise<boolean> {
    try {
      await fileIo.access(path)
      return true
    } catch (error) {
      return false
    }
  }

  private static async markCompleted(store: relationalStore.RdbStore,
    status: LegacyMigrationStatus, importedCount: number): Promise<void> {
    try {
      await store.executeSql(
        `INSERT OR REPLACE INTO ${DatabaseTable.MIGRATION_HISTORY}
         (migration_key, completed_at, details) VALUES (?, ?, ?)`,
        [LEGACY_MIGRATION_KEY, Date.now(), `${status}:${importedCount}`])
    } catch (error) {
      throw new AppError(AppErrorCode.MIGRATION,
        `Unable to record migration status: ${JSON.stringify(error)}`)
    }
  }

  private static async importCandidates(store: relationalStore.RdbStore,
    candidates: LegacyTaskCandidate[], migratedAt: number): Promise<void> {
    let transaction: relationalStore.Transaction | null = null
    try {
      transaction = await store.createTransaction({
        transactionType: relationalStore.TransactionType.IMMEDIATE
      })
      for (let index: number = 0; index < candidates.length; index++) {
        const candidate: LegacyTaskCandidate = candidates[index]
        await transaction.execute(
          `INSERT OR IGNORE INTO ${DatabaseTable.TASKS}
           (id, profile_id, title, notes, category_id, planned_minutes, due_at, status, completed_at,
            created_at, updated_at, deleted_at, revision, sync_state, legacy_code)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            candidate.task.id, candidate.task.profileId, candidate.task.title, candidate.task.notes,
            candidate.task.categoryId, candidate.task.plannedMinutes, candidate.task.dueAt,
            candidate.task.status, candidate.task.completedAt, candidate.task.createdAt,
            candidate.task.updatedAt, candidate.task.deletedAt, candidate.task.revision,
            candidate.task.syncState, candidate.legacyCode
          ])
      }
      await transaction.execute(
        `INSERT OR REPLACE INTO ${DatabaseTable.MIGRATION_HISTORY}
         (migration_key, completed_at, details) VALUES (?, ?, ?)`,
        [LEGACY_MIGRATION_KEY, migratedAt, `${LegacyMigrationStatus.MIGRATED}:${candidates.length}`])
      await transaction.commit()
    } catch (error) {
      if (transaction !== null) {
        try {
          await transaction.rollback()
        } catch (rollbackError) {
        }
      }
      throw new AppError(AppErrorCode.MIGRATION, `Legacy import transaction failed: ${JSON.stringify(error)}`)
    }
  }
}
