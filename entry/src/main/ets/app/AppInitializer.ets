import { common } from '@kit.AbilityKit'
import { AppLogger } from '../core/logging/AppLogger'
import { AppDatabase } from '../data/database/AppDatabase'
import { RepositoryRegistry } from '../data/repository/RepositoryRegistry'
import {
  LegacyDataMigrator,
  LegacyMigrationResult,
  LegacyMigrationStatus
} from '../data/migration/LegacyDataMigrator'

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
    AppInitializer.initialized = true
    if (migrationResult.status === LegacyMigrationStatus.FAILED) {
      AppLogger.warn('AppInitializer', 'Legacy data migration will be retried on the next launch')
    } else {
      AppLogger.info('AppInitializer',
        `Application data initialized; legacy status=${migrationResult.status}, imported=${migrationResult.importedCount}`)
    }
  }
}
