import { AppLogger } from '../core/logging/AppLogger'

export class AppInitializer {
  private static initialized: boolean = false

  static initialize(): void {
    if (AppInitializer.initialized) {
      return
    }

    AppInitializer.initialized = true
    AppLogger.info('AppInitializer', 'Application foundation initialized')
  }
}
