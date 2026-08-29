import { AppBreakpoint, AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { CategoryFocusSegment, CategoryFocusShare, HeatmapDay, InsightsDashboard, TrendPoint } from '../domain/InsightsModels'
import { InsightsAggregator } from '../domain/InsightsAggregator'
import { InsightsPresentation } from './InsightsPresentation'
import { InsightsViewModel } from './InsightsViewModel'

@Component
struct MetricCard {
  @Prop value: string
  @Prop label: string
  @Prop hint: string = ''

  build() {
    Column({ space: AppSpacing.XS }) {
      Text(this.value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.label)
        .fontSize(AppTypography.CAPTION)
        .fontColor($r('app.color.text_secondary'))
      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
      }
    }
    .width('100%')
    .height(112)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}

@Component
export struct InsightsPage {
  @Prop isWide: boolean = false
  @State loading: boolean = true
  @State errorMessage: string = ''
  @State dashboard: InsightsDashboard = InsightsAggregator.empty(Date.now())
  private readonly viewModel: InsightsViewModel = new InsightsViewModel()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    try {
      this.dashboard = await this.viewModel.load()
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = '暂时无法读取本地专注记录，请稍后重试'
    } finally {
      this.loading = false
    }
  }

  private trendMaximum(): number {
    let maximum: number = 0
    this.dashboard.trend.forEach((point: TrendPoint) => maximum = Math.max(maximum, point.focusSeconds))
    return Math.max(1, maximum)
  }

  private segmentHeight(segment: CategoryFocusSegment): number {
    return Math.max(2, segment.focusSeconds / this.trendMaximum() * 104)
  }

  private heatOpacity(day: HeatmapDay): number {
    return day.level === 0 ? 1 : 0.25 + day.level * 0.18
  }

  private weeklySeconds(): number {
    let total: number = 0
    this.dashboard.trend.forEach((point: TrendPoint) => total += point.focusSeconds)
    return total
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.LG }) {
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

        if (this.loading) {
          Column({ space: AppSpacing.MD }) {
            LoadingProgress().width(52).height(52).color($r('app.color.brand_primary'))
            Text('正在汇总本地专注记录')
              .fontSize(AppTypography.BODY).fontColor($r('app.color.text_secondary'))
          }
          .width('100%').height(320).justifyContent(FlexAlign.Center)
        } else if (this.errorMessage.length > 0) {
          Column({ space: AppSpacing.MD }) {
            Text(this.errorMessage)
              .fontSize(AppTypography.BODY).fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
            Button('重新读取')
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .onClick(() => this.load())
          }
          .width('100%').padding(AppSpacing.XL)
          .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
        } else {
          this.Metrics()

          if (!this.dashboard.hasFocusData) {
            Column({ space: AppSpacing.SM }) {
              Text('从第一次专注开始')
                .fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text($r('app.string.insights_empty'))
                .fontSize(AppTypography.BODY).fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            .width('100%').padding(AppSpacing.XXL)
            .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
            .border({ width: 1, color: $r('app.color.border_subtle') })
          } else {
            this.WeeklyTrend()
            this.Heatmap()
            this.CategoryDistribution()
          }
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: AppBreakpoint.CONTENT_MAX })
      .padding(this.isWide ? AppSpacing.XXL : AppSpacing.LG)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private Metrics() {
    if (this.isWide) {
      Row({ space: AppSpacing.MD }) {
        Column() { MetricCard({ value: InsightsPresentation.focusMinutes(this.dashboard.today.focusSeconds), label: '今日专注' }) }.layoutWeight(1)
        Column() { MetricCard({ value: `${this.dashboard.today.completedRounds}`, label: '今日完成轮次' }) }.layoutWeight(1)
        Column() { MetricCard({ value: `${this.dashboard.currentStreak} 天`, label: '连续天数' }) }.layoutWeight(1)
        Column() { MetricCard({ value: `${this.dashboard.totalPoints}`, label: '积分', hint: '来自已结算奖励' }) }.layoutWeight(1)
      }
      .width('100%')
    } else {
      Column({ space: AppSpacing.MD }) {
        Row({ space: AppSpacing.MD }) {
          Column() { MetricCard({ value: InsightsPresentation.focusMinutes(this.dashboard.today.focusSeconds), label: '今日专注' }) }.layoutWeight(1)
          Column() { MetricCard({ value: `${this.dashboard.today.completedRounds}`, label: '今日完成轮次' }) }.layoutWeight(1)
        }
        .width('100%')
        Row({ space: AppSpacing.MD }) {
          Column() { MetricCard({ value: `${this.dashboard.currentStreak} 天`, label: '连续天数' }) }.layoutWeight(1)
          Column() { MetricCard({ value: `${this.dashboard.totalPoints}`, label: '积分', hint: '来自已结算奖励' }) }.layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  private WeeklyTrend() {
    Column({ space: AppSpacing.LG }) {
      Column({ space: AppSpacing.XS }) {
        Text('近 7 天趋势')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Text(`累计 ${InsightsPresentation.duration(this.weeklySeconds())}`)
          .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').alignItems(HorizontalAlign.Start)

      Row({ space: AppSpacing.SM }) {
        ForEach(this.dashboard.trend, (point: TrendPoint) => {
          Column({ space: AppSpacing.SM }) {
            Column({ space: 1 }) {
              ForEach(point.categorySegments, (segment: CategoryFocusSegment) => {
                Column()
                  .width('100%')
                  .height(this.segmentHeight(segment))
                  .backgroundColor(segment.colorSeed)
                  .borderRadius(3)
              }, (segment: CategoryFocusSegment) => `${point.dateKey}-${segment.categoryId ?? 'none'}`)
            }
            .width('100%').height(108)
            .justifyContent(FlexAlign.End)
            .backgroundColor(point.focusSeconds <= 0 ? $r('app.color.surface_emphasis') : Color.Transparent)
            .borderRadius(AppRadius.SM)
            Text(point.label)
              .fontSize(10).fontColor($r('app.color.text_tertiary')).maxLines(1)
          }
          .layoutWeight(1)
        }, (point: TrendPoint) => point.dateKey)
      }
      .width('100%').alignItems(VerticalAlign.Bottom)
    }
    .width('100%').padding(AppSpacing.XL)
    .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }

  @Builder
  private Heatmap() {
    Column({ space: AppSpacing.LG }) {
      Column({ space: AppSpacing.XS }) {
        Text('近 12 周专注热力图')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Text('颜色越深，表示当天专注时间越长')
          .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').alignItems(HorizontalAlign.Start)

      Row({ space: 5 }) {
        ForEach(this.dashboard.heatmapWeeks, (week: HeatmapDay[]) => {
          Column({ space: 5 }) {
            ForEach(week, (day: HeatmapDay) => {
              Row()
                .width(this.isWide ? 18 : 14).height(this.isWide ? 18 : 14)
                .backgroundColor(day.level === 0 || day.isFuture ?
                  $r('app.color.surface_emphasis') : $r('app.color.brand_primary'))
                .opacity(day.isFuture ? 0.35 : this.heatOpacity(day))
                .borderRadius(4)
            }, (day: HeatmapDay) => day.dateKey)
          }
        }, (_week: HeatmapDay[], weekIndex: number) => `week-${weekIndex}`)
      }
      .width('100%').justifyContent(FlexAlign.Center)
    }
    .width('100%').padding(AppSpacing.XL)
    .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }

  @Builder
  private CategoryDistribution() {
    Column({ space: AppSpacing.LG }) {
      Column({ space: AppSpacing.XS }) {
        Text('类别时间分布')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Text(`全部专注 ${InsightsPresentation.duration(this.dashboard.totalFocusSeconds)}`)
          .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').alignItems(HorizontalAlign.Start)

      ForEach(this.dashboard.categoryDistribution, (item: CategoryFocusShare) => {
        Column({ space: AppSpacing.SM }) {
          Row({ space: AppSpacing.SM }) {
            Row().width(10).height(10).backgroundColor(item.colorSeed).borderRadius(AppRadius.PILL)
            Text(item.name)
              .layoutWeight(1).fontSize(AppTypography.BODY)
              .fontColor(item.categoryDeleted ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(InsightsPresentation.duration(item.focusSeconds))
              .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
            Text(InsightsPresentation.percentage(item.percentage))
              .width(42).textAlign(TextAlign.End)
              .fontSize(AppTypography.CAPTION).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          Stack({ alignContent: Alignment.Start }) {
            Row().width('100%').height(7).backgroundColor($r('app.color.surface_emphasis')).borderRadius(AppRadius.PILL)
            Row().width(`${Math.max(2, item.percentage * 100)}%`).height(7)
              .backgroundColor(item.colorSeed).borderRadius(AppRadius.PILL)
          }
          .width('100%').height(7)
        }
        .width('100%')
      }, (item: CategoryFocusShare) => item.categoryId ?? 'uncategorized')
    }
    .width('100%').padding(AppSpacing.XL)
    .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}
