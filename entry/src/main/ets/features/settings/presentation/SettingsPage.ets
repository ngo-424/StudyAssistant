import { AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'

@Component
struct SettingRow {
  @Prop icon: string
  @Prop title: ResourceStr
  @Prop description: ResourceStr

  build() {
    Row({ space: AppSpacing.MD }) {
      Text(this.icon)
        .width(42)
        .height(42)
        .fontSize(18)
        .fontColor($r('app.color.brand_primary'))
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.brand_container'))
        .borderRadius(AppRadius.SM)

      Column({ space: AppSpacing.XS }) {
        Text(this.title)
          .fontSize(AppTypography.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))

        Text(this.description)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(24)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}

@Component
export struct SettingsPage {
  @Prop isWide: boolean = false

  build() {
    Scroll() {
      Column() {
        Column({ space: AppSpacing.XS }) {
          Text($r('app.string.settings_title'))
            .fontSize(AppTypography.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.settings_subtitle'))
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: AppSpacing.XL })

        Column({ space: AppSpacing.MD }) {
          SettingRow({
            icon: '○',
            title: $r('app.string.guest_mode'),
            description: $r('app.string.guest_mode_desc')
          })
          SettingRow({
            icon: '◷',
            title: $r('app.string.focus_settings'),
            description: $r('app.string.focus_settings_desc')
          })
          SettingRow({
            icon: '◐',
            title: $r('app.string.appearance'),
            description: $r('app.string.appearance_desc')
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding(this.isWide ? AppSpacing.XXL : AppSpacing.LG)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
