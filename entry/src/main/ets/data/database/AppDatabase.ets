import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { DATABASE_NAME } from './DatabaseSchema'
import { DatabaseMigrations } from './DatabaseMigrations'

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: DATABASE_NAME,
  securityLevel: relationalStore.SecurityLevel.S2,
  encrypt: true,
  allowRebuild: false
}

export class AppDatabase {
  private static store: relationalStore.RdbStore | null = null

  static async open(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    if (AppDatabase.store !== null) {
      return AppDatabase.store
    }

    try {
      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG)
      await DatabaseMigrations.migrate(store)
      AppDatabase.store = store
      return store
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to open application database: ${JSON.stringify(error)}`)
    }
  }

  static getStore(): relationalStore.RdbStore {
    if (AppDatabase.store === null) {
      throw new AppError(AppErrorCode.INITIALIZATION, 'Database has not been initialized')
    }
    return AppDatabase.store
  }
}
