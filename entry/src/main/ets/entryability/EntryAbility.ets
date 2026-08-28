import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AppInitializer } from '../app/AppInitializer'
import { AppLogger } from '../core/logging/AppLogger'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppInitializer.initialize(this.context).catch((error: Error) => {
      AppLogger.error('EntryAbility', `Application initialization failed: ${error.message}`)
    })
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (error) {
      AppLogger.error('EntryAbility', `Failed to follow system color mode: ${JSON.stringify(error)}`)
    }
    AppLogger.info('EntryAbility', 'Ability created')
  }

  onDestroy(): void {
    AppLogger.info('EntryAbility', 'Ability destroyed')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    AppLogger.info('EntryAbility', 'Main window stage created')
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        AppLogger.error('EntryAbility', `Failed to load main content: ${JSON.stringify(error)}`)
        return
      }
      AppLogger.info('EntryAbility', 'Main content loaded')
    })
  }

  onWindowStageDestroy(): void {
    AppLogger.info('EntryAbility', 'Main window stage destroyed')
  }

  onForeground(): void {
    AppLogger.info('EntryAbility', 'Application entered foreground')
  }

  onBackground(): void {
    AppLogger.info('EntryAbility', 'Application entered background')
  }
}
