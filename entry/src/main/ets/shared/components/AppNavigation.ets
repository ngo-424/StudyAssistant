import { AppTab } from '../../app/AppTab'
import { AppControl, AppRadius, AppSpacing, AppTypography } from '../../core/design/DesignTokens'

@Component
struct NavigationButton {
  @Prop tab: AppTab
  @Prop selectedTab: AppTab
  @Prop symbol: Resource
  @Prop label: ResourceStr
  @Prop compact: boolean = false
  onSelect: (tab: AppTab) => void = () => {}

  build() {
    if (this.compact) {
      Column({ space: AppSpacing.XS }) {
        SymbolGlyph(this.symbol)
          .fontSize(21)
          .fontColor([this.selectedTab === this.tab ?
            $r('app.color.brand_primary') : $r('app.color.text_secondary')])

        Text(this.label)
          .fontSize(AppTypography.CAPTION)
          .fontWeight(this.selectedTab === this.tab ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selectedTab === this.tab ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
      }
      .width(64)
      .height(56)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.selectedTab === this.tab ? $r('app.color.brand_container') : Color.Transparent)
      .borderRadius(AppRadius.MD)
      .onClick(() => this.onSelect(this.tab))
    } else {
      Row({ space: AppSpacing.MD }) {
        SymbolGlyph(this.symbol)
          .width(28)
          .fontSize(22)
          .fontColor([this.selectedTab === this.tab ?
            $r('app.color.brand_primary') : $r('app.color.text_secondary')])

        Text(this.label)
          .fontSize(AppTypography.BODY)
          .fontWeight(this.selectedTab === this.tab ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selectedTab === this.tab ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
      }
      .width('100%')
      .height(AppControl.PRIMARY_HEIGHT)
      .padding({ left: AppSpacing.MD, right: AppSpacing.MD })
      .backgroundColor(this.selectedTab === this.tab ? $r('app.color.brand_container') : Color.Transparent)
      .borderRadius(AppRadius.MD)
      .onClick(() => this.onSelect(this.tab))
    }
  }
}

@Component
export struct AppNavigation {
  @Prop selectedTab: AppTab
  @Prop isWide: boolean = false
  onSelect: (tab: AppTab) => void = () => {}

  build() {
    if (this.isWide) {
      Column({ space: AppSpacing.SM }) {
        Row({ space: AppSpacing.SM }) {
          SymbolGlyph($r('sys.symbol.leaf_fill'))
            .width(36)
            .height(36)
            .fontSize(20)
            .fontColor([$r('app.color.brand_on_primary')])
            .backgroundColor($r('app.color.brand_primary'))
            .borderRadius(AppRadius.SM)

          Text($r('app.string.app_brand_name'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .margin({ bottom: AppSpacing.XL })

        NavigationButton({
          tab: AppTab.FOCUS,
          selectedTab: this.selectedTab,
          symbol: $r('sys.symbol.timer'),
          label: $r('app.string.tab_focus'),
          onSelect: this.onSelect
        })
        NavigationButton({
          tab: AppTab.INSIGHTS,
          selectedTab: this.selectedTab,
          symbol: $r('sys.symbol.waveform'),
          label: $r('app.string.tab_insights'),
          onSelect: this.onSelect
        })
        NavigationButton({
          tab: AppTab.TASKS,
          selectedTab: this.selectedTab,
          symbol: $r('sys.symbol.list_checkmask'),
          label: $r('app.string.tab_tasks'),
          onSelect: this.onSelect
        })
        NavigationButton({
          tab: AppTab.SETTINGS,
          selectedTab: this.selectedTab,
          symbol: $r('sys.symbol.person_crop_circle_fill'),
          label: $r('app.string.tab_settings'),
          onSelect: this.onSelect
        })

        Blank()

        Text($r('app.string.brand_tagline'))
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width(224)
      .height('100%')
      .padding(AppSpacing.XL)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.surface_primary'))
      .border({ width: { right: 1 }, color: $r('app.color.border_subtle') })
    } else {
      Row() {
        NavigationButton({
          tab: AppTab.FOCUS,
          selectedTab: this.selectedTab,
          symbol: $r('sys.symbol.timer'),
          label: $r('app.string.tab_focus'),
          compact: true,
          onSelect: this.onSelect
        })
        NavigationButton({
          tab: AppTab.INSIGHTS,
          selectedTab: this.selectedTab,
          symbol: $r('sys.symbol.waveform'),
          label: $r('app.string.tab_insights'),
          compact: true,
          onSelect: this.onSelect
        })
        NavigationButton({
          tab: AppTab.TASKS,
          selectedTab: this.selectedTab,
          symbol: $r('sys.symbol.list_checkmask'),
          label: $r('app.string.tab_tasks'),
          compact: true,
          onSelect: this.onSelect
        })
        NavigationButton({
          tab: AppTab.SETTINGS,
          selectedTab: this.selectedTab,
          symbol: $r('sys.symbol.person_crop_circle_fill'),
          label: $r('app.string.tab_settings'),
          compact: true,
          onSelect: this.onSelect
        })
      }
      .width('100%')
      .height(72)
      .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.SM, bottom: AppSpacing.SM })
      .justifyContent(FlexAlign.SpaceAround)
      .backgroundColor($r('app.color.surface_primary'))
      .border({ width: { top: 1 }, color: $r('app.color.border_subtle') })
    }
  }
}
