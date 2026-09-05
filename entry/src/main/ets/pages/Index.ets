import { common } from '@kit.AbilityKit'
import { AppTab } from '../app/AppTab'
import { AppLogger } from '../core/logging/AppLogger'
import { AppBreakpoint } from '../core/design/DesignTokens'
import { WindowLayoutPolicy } from '../core/design/WindowLayoutPolicy'
import { FocusPage } from '../features/focus/presentation/FocusPage'
import { FocusWindowGuideStore } from '../features/focus/infrastructure/FocusWindowGuideStore'
import { InsightsPage } from '../features/insights/presentation/InsightsPage'
import { SettingsPage } from '../features/settings/presentation/SettingsPage'
import { TasksPage } from '../features/tasks/presentation/TasksPage'
import { AppNavigation } from '../shared/components/AppNavigation'

@Entry
@Component
struct Index {
  @State selectedTab: AppTab = AppTab.FOCUS
  @State isWide: boolean = false
  @State isCompactWindow: boolean = false
  @State isFocusImmersive: boolean = false
  @State isFocusReady: boolean = false
  @State foregroundRevision: number = 0
  private isFocusActive: boolean = false
  private guideShown: boolean = false
  private backBusy: boolean = false

  onPageShow(): void {
    this.foregroundRevision++
  }

  onBackPress(): boolean {
    if (this.backBusy) {
      return true
    }
    if (this.selectedTab !== AppTab.FOCUS || !this.isFocusActive || this.guideShown) {
      return false
    }
    this.backBusy = true
    this.offerWindowGuide()
    return true
  }

  private async offerWindowGuide(): Promise<void> {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    try {
      this.guideShown = await FocusWindowGuideStore.wasShown(context)
      if (this.guideShown || !this.isFocusActive) {
        await this.continueInBackground()
        return
      }
      this.guideShown = true
      // Preference failure must never prevent leaving the app.
      FocusWindowGuideStore.markShown(context).catch(() => {
        AppLogger.warn('FocusWindowGuide', 'Could not save the guide preference')
      })
      this.getUIContext().showAlertDialog({
        title: '用小窗继续专注',
        message: '离开应用后计时仍会继续。也可以使用系统悬浮小窗，边使用其他应用边查看剩余时间。',
        primaryButton: { value: '查看开启方法', action: () => this.showWindowInstructions() },
        secondaryButton: { value: '继续后台计时', action: () => this.continueInBackground() },
        cancel: () => { this.backBusy = false }
      })
    } catch (error) {
      this.guideShown = true
      await this.continueInBackground()
    }
  }

  private showWindowInstructions(): void {
    this.getUIContext().showAlertDialog({
      title: '开启系统悬浮小窗',
      message: '从屏幕左侧或右侧边缘向内滑动并停顿，打开“智慧多窗”应用栏，再点选“时芽”。\n\n也可从应用底部上滑至右上方的悬浮窗图标。具体操作以手机系统为准；若未提供小窗功能，可直接回桌面继续计时。',
      confirm: { value: '知道了', action: () => { this.backBusy = false } },
      cancel: () => { this.backBusy = false }
    })
  }

  private async continueInBackground(): Promise<void> {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      await context.moveAbilityToBackground()
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '可使用回桌面手势离开，计时会继续' })
    } finally {
      this.backBusy = false
    }
  }

  private showNavigation(): boolean {
    return this.selectedTab !== AppTab.FOCUS || (this.isFocusReady && !this.isFocusImmersive)
  }

  @Builder
  private PageContent() {
    if (this.selectedTab === AppTab.FOCUS) {
      FocusPage({
        isWide: this.isWide,
        isCompact: this.isCompactWindow,
        foregroundRevision: this.foregroundRevision,
        onImmersiveChange: (immersive: boolean) => {
          this.isFocusImmersive = immersive
          this.isFocusReady = true
        },
        onActiveChange: (active: boolean) => { this.isFocusActive = active }
      })
    } else if (this.selectedTab === AppTab.INSIGHTS) {
      InsightsPage({ isWide: this.isWide })
    } else if (this.selectedTab === AppTab.TASKS) {
      TasksPage({ isWide: this.isWide })
    } else {
      SettingsPage({ isWide: this.isWide })
    }
  }

  private selectTab(tab: AppTab): void {
    if (tab === this.selectedTab) {
      return
    }
    if (tab === AppTab.FOCUS) {
      this.isFocusReady = false
    }
    this.selectedTab = tab
  }

  build() {
    Row() {
      if (this.showNavigation() && this.isWide && !this.isCompactWindow) {
        AppNavigation({
          selectedTab: this.selectedTab,
          isWide: true,
          onSelect: (tab: AppTab) => this.selectTab(tab)
        })
      }

      Column() {
        Column() {
          this.PageContent()
        }
        .width('100%')
        .layoutWeight(1)

        if (this.showNavigation() && !this.isWide) {
          AppNavigation({
            selectedTab: this.selectedTab,
            isWide: false,
            onSelect: (tab: AppTab) => this.selectTab(tab)
          })
        }
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width: number = Number(newArea.width)
      const height: number = Number(newArea.height)
      this.isWide = width >= AppBreakpoint.TABLET
      this.isCompactWindow = WindowLayoutPolicy.isCompact(width, height)
    })
  }
}
