import { AppTab } from '../app/AppTab'
import { AppBreakpoint } from '../core/design/DesignTokens'
import { FocusPage } from '../features/focus/presentation/FocusPage'
import { InsightsPage } from '../features/insights/presentation/InsightsPage'
import { SettingsPage } from '../features/settings/presentation/SettingsPage'
import { TasksPage } from '../features/tasks/presentation/TasksPage'
import { AppNavigation } from '../shared/components/AppNavigation'

@Entry
@Component
struct Index {
  @State selectedTab: AppTab = AppTab.FOCUS
  @State isWide: boolean = false

  @Builder
  private PageContent() {
    if (this.selectedTab === AppTab.FOCUS) {
      FocusPage({ isWide: this.isWide })
    } else if (this.selectedTab === AppTab.INSIGHTS) {
      InsightsPage({ isWide: this.isWide })
    } else if (this.selectedTab === AppTab.TASKS) {
      TasksPage({ isWide: this.isWide })
    } else {
      SettingsPage({ isWide: this.isWide })
    }
  }

  private selectTab(tab: AppTab): void {
    this.selectedTab = tab
  }

  build() {
    Row() {
      if (this.isWide) {
        AppNavigation({
          selectedTab: this.selectedTab,
          isWide: true,
          onSelect: (tab: AppTab) => this.selectTab(tab)
        })
      }

      Column() {
        this.PageContent()

        if (!this.isWide) {
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
      this.isWide = Number(newArea.width) >= AppBreakpoint.TABLET
    })
  }
}
