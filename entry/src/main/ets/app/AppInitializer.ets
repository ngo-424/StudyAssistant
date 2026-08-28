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

  static async initialize(context: common.UIAbilityContext): Promise<void> {
    if (AppInitializer.initialized) {
      return
    }

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
