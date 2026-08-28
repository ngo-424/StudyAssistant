import { AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'

@Component
export struct TasksPage {
  @Prop isWide: boolean = false

  build() {
    Scroll() {
      Column() {
        Column({ space: AppSpacing.XS }) {
          Text($r('app.string.tasks_title'))
            .fontSize(AppTypography.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.tasks_subtitle'))
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: AppSpacing.XL })

        Column({ space: AppSpacing.MD }) {
          Text('✓')
            .width(56)
            .height(56)
            .fontSize(24)
            .fontColor($r('app.color.brand_primary'))
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.brand_container'))
            .borderRadius(AppRadius.MD)

          Text($r('app.string.tasks_empty_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.tasks_empty_body'))
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)

          Button($r('app.string.tasks_create'))
            .margin({ top: AppSpacing.SM })
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.brand_container'))
            .borderRadius(AppRadius.MD)
            .enabled(false)

          Text($r('app.string.coming_later'))
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .constraintSize({ minHeight: this.isWide ? 380 : 340 })
        .justifyContent(FlexAlign.Center)
        .padding(AppSpacing.XL)
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
