import { AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'

@Component
export struct FocusPage {
  @Prop isWide: boolean = false

  build() {
    Scroll() {
      Column() {
        Column({ space: AppSpacing.XS }) {
          Text($r('app.string.focus_title'))
            .fontSize(AppTypography.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.focus_subtitle'))
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: AppSpacing.XL })

        Column({ space: AppSpacing.LG }) {
          Text($r('app.string.focus_ready'))
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))

          Text('25:00')
            .fontSize(this.isWide ? 76 : AppTypography.DISPLAY)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.focus_free'))
            .fontSize(AppTypography.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.category_neutral'))
            .backgroundColor($r('app.color.surface_secondary'))
            .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: AppSpacing.SM, bottom: AppSpacing.SM })
            .borderRadius(AppRadius.PILL)

          Button($r('app.string.focus_start'))
            .width(this.isWide ? 260 : '100%')
            .height(52)
            .fontSize(AppTypography.BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .borderRadius(AppRadius.MD)
            .enabled(false)

          Text($r('app.string.focus_module_hint'))
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .constraintSize({ minHeight: this.isWide ? 440 : 400 })
        .justifyContent(FlexAlign.Center)
        .padding(this.isWide ? AppSpacing.XXL : AppSpacing.XL)
        .backgroundColor($r('app.color.surface_primary'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.border_subtle') })
      }
      .width('100%')
      .padding(this.isWide ? AppSpacing.XXL : AppSpacing.LG)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
