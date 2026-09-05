import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

export class FocusWindowGuideStore {
  private static readonly STORE: string = 'focus_window_guide'
  private static readonly SHOWN: string = 'shown'

  static async wasShown(context: common.UIAbilityContext): Promise<boolean> {
    const store: preferences.Preferences = await preferences.getPreferences(context, { name: FocusWindowGuideStore.STORE })
    return (await store.get(FocusWindowGuideStore.SHOWN, false)) as boolean
  }

  static async markShown(context: common.UIAbilityContext): Promise<void> {
    const store: preferences.Preferences = await preferences.getPreferences(context, { name: FocusWindowGuideStore.STORE })
    await store.put(FocusWindowGuideStore.SHOWN, true)
    await store.flush()
  }
}
