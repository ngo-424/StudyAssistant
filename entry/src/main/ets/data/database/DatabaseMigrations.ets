import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { DATABASE_V1_STATEMENTS, DATABASE_V2_STATEMENTS, DATABASE_VERSION } from './DatabaseSchema'

export class DatabaseMigrations {
  static async migrate(store: relationalStore.RdbStore): Promise<void> {
    const sourceVersion: number = store.version
    if (sourceVersion > DATABASE_VERSION) {
      throw new AppError(AppErrorCode.DATABASE,
        `Database version ${sourceVersion} is newer than supported version ${DATABASE_VERSION}`)
    }
    if (sourceVersion === DATABASE_VERSION) {
      return
    }

    let transaction: relationalStore.Transaction | null = null
    try {
      transaction = await store.createTransaction({
        transactionType: relationalStore.TransactionType.IMMEDIATE
      })
      if (sourceVersion < 1) {
        for (let index: number = 0; index < DATABASE_V1_STATEMENTS.length; index++) {
          await transaction.execute(DATABASE_V1_STATEMENTS[index])
        }
      }
      if (sourceVersion < 2) {
        for (let index: number = 0; index < DATABASE_V2_STATEMENTS.length; index++) {
          await transaction.execute(DATABASE_V2_STATEMENTS[index])
        }
      }
      await transaction.commit()
      store.version = DATABASE_VERSION
      await store.executeSql('PRAGMA foreign_keys = ON')
    } catch (error) {
      if (transaction !== null) {
        try {
          await transaction.rollback()
        } catch (rollbackError) {
        }
      }
      throw new AppError(AppErrorCode.MIGRATION, `Database migration failed: ${JSON.stringify(error)}`)
    }
  }
}
