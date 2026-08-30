import { common } from '@kit.AbilityKit'
import { AppLogger } from '../core/logging/AppLogger'
import { AppDatabase } from '../data/database/AppDatabase'
import { RepositoryRegistry } from '../data/repository/RepositoryRegistry'
import {
  LegacyDataMigrator,
  LegacyMigrationResult,
  LegacyMigrationStatus
} from '../data/migration/LegacyDataMigrator'
import { SyncMetadata } from '../domain/model/StudyModels'
import { ProfileContext } from '../features/sync/application/ProfileContext'

const SYSTEM_PROFILE_ID: string = 'system'
const PENDING_ACCOUNT_KEY: string = 'pending_account_id'

export class AppInitializer {
  private static initialized: boolean = false
  private static initializationPromise: Promise<void> | null = null

  static initialize(context: common.UIAbilityContext): Promise<void> {
    if (AppInitializer.initialized) {
      return Promise.resolve()
    }
    if (AppInitializer.initializationPromise === null) {
      AppInitializer.initializationPromise = AppInitializer.performInitialize(context)
    }
    return AppInitializer.initializationPromise
  }

  static whenReady(): Promise<void> {
    if (AppInitializer.initialized) {
      return Promise.resolve()
    }
    if (AppInitializer.initializationPromise === null) {
      return Promise.reject(new Error('Application initialization has not started'))
    }
    return AppInitializer.initializationPromise
  }

  private static async performInitialize(context: common.UIAbilityContext): Promise<void> {
    const store = await AppDatabase.open(context)
    RepositoryRegistry.initialize(store)
    const migrationResult: LegacyMigrationResult = await LegacyDataMigrator.migrate(context, store)
    const session = await RepositoryRegistry.accountSession().current()
    const pending: SyncMetadata | null = await RepositoryRegistry.sync().findMetadata(
      SYSTEM_PROFILE_ID, PENDING_ACCOUNT_KEY)
    if (session !== null && pending?.value !== session.accountId) {
      ProfileContext.activateAccount(session.accountId)
    } else {
      ProfileContext.activateGuest()
    }
    AppInitializer.initialized = true
    if (migrationResult.status === LegacyMigrationStatus.FAILED) {
      AppLogger.warn('AppInitializer', 'Legacy data migration will be retried on the next launch')
    } else {
      AppLogger.info('AppInitializer',
        `Application data initialized; legacy status=${migrationResult.status}, imported=${migrationResult.importedCount}`)
    }
  }
}
