import { AbilityConstant, ConfigurationConstant, UIAbility, Want, wantConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AppInitializer } from '../app/AppInitializer'
import { AppLogger } from '../core/logging/AppLogger'
import { ContinuationBridge } from '../features/continuation/application/ContinuationBridge'
import { FocusContinuationService } from '../features/continuation/application/FocusContinuationService'
import {
  CONTINUATION_PAYLOAD_KEY
} from '../features/continuation/domain/ContinuationModels'
import { ContinuationRules } from '../features/continuation/domain/ContinuationRules'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      ContinuationBridge.receive(want.parameters)
    }
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
    this.loadMainContent(windowStage)
  }

  onWindowStageRestore(windowStage: window.WindowStage): void {
    AppLogger.info('EntryAbility', 'Main window stage restored after continuation')
    this.loadMainContent(windowStage)
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      ContinuationBridge.receive(want.parameters)
    }
  }

  async onContinue(wantParam: Record<string, Object>): Promise<AbilityConstant.OnContinueResult> {
    if (!ContinuationRules.compatibleTargetVersion(wantParam['version'])) {
      AppLogger.warn('EntryAbility', 'Continuation rejected because target version is incompatible')
      return AbilityConstant.OnContinueResult.MISMATCH
    }
    try {
      const payload: string = await FocusContinuationService.shared().createTransferPayload()
      wantParam[CONTINUATION_PAYLOAD_KEY] = payload
      wantParam[wantConstant.Params.SUPPORT_CONTINUE_SOURCE_EXIT_KEY] = false
      AppLogger.info('EntryAbility', 'Continuation payload prepared')
      return AbilityConstant.OnContinueResult.AGREE
    } catch (error) {
      AppLogger.warn('EntryAbility', 'Continuation rejected; source timer remains active')
      return AbilityConstant.OnContinueResult.REJECT
    }
  }

  private loadMainContent(windowStage: window.WindowStage): void {
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
