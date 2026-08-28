import { AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'

@Component
struct MetricCard {
  @Prop value: string
  @Prop label: ResourceStr

  build() {
    Column({ space: AppSpacing.SM }) {
      Text(this.value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Text(this.label)
        .fontSize(AppTypography.CAPTION)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}

@Component
export struct InsightsPage {
  @Prop isWide: boolean = false

  build() {
    Scroll() {
      Column() {
        Column({ space: AppSpacing.XS }) {
          Text($r('app.string.insights_title'))
            .fontSize(AppTypography.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.insights_subtitle'))
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: AppSpacing.XL })

        if (this.isWide) {
          Row({ space: AppSpacing.MD }) {
            Column() {
              MetricCard({ value: '0 min', label: $r('app.string.today_focus') })
            }
            .layoutWeight(1)
            Column() {
              MetricCard({ value: '0', label: $r('app.string.completed_rounds') })
            }
            .layoutWeight(1)
            Column() {
              MetricCard({ value: '0 天', label: $r('app.string.current_streak') })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .margin({ bottom: AppSpacing.LG })
        } else {
          Column({ space: AppSpacing.MD }) {
            MetricCard({ value: '0 min', label: $r('app.string.today_focus') })
            MetricCard({ value: '0', label: $r('app.string.completed_rounds') })
            MetricCard({ value: '0 天', label: $r('app.string.current_streak') })
          }
          .width('100%')
          .margin({ bottom: AppSpacing.LG })
        }

        Column({ space: AppSpacing.XL }) {
          Text($r('app.string.weekly_trend'))
            .width('100%')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Row({ space: AppSpacing.SM }) {
            ForEach([1, 2, 3, 4, 5, 6, 7], () => {
              Column()
                .layoutWeight(1)
                .height(8)
                .backgroundColor($r('app.color.surface_emphasis'))
                .borderRadius(AppRadius.PILL)
            })
          }
          .width('100%')

          Text($r('app.string.insights_empty'))
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
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
