import { AppRadius, AppSpacing, AppTypography } from '../../../../core/design/DesignTokens'
import { TaskListFilter } from '../TaskPresentation'

@Component
struct FilterButton {
  @Prop label: ResourceStr
  @Prop value: TaskListFilter
  @Prop selected: TaskListFilter
  @Prop count: number = 0
  onSelect: (value: TaskListFilter) => void = () => {}

  build() {
    Row({ space: AppSpacing.XS }) {
      Text(this.label)
        .fontSize(AppTypography.CAPTION)
        .fontWeight(this.selected === this.value ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selected === this.value ? $r('app.color.brand_on_primary') : $r('app.color.text_secondary'))
      Text(`${this.count}`)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selected === this.value ? $r('app.color.brand_on_primary') : $r('app.color.text_secondary'))
    }
      .layoutWeight(1)
      .height(40)
      .backgroundColor(this.selected === this.value ? $r('app.color.brand_primary') : Color.Transparent)
      .borderRadius(AppRadius.SM)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.onSelect(this.value))
  }
}

@Component
export struct TaskFilterBar {
  @Prop selected: TaskListFilter
  @Prop todoCount: number = 0
  @Prop completedCount: number = 0
  @Prop deletedCount: number = 0
  onSelect: (value: TaskListFilter) => void = () => {}

  build() {
    Row({ space: AppSpacing.XS }) {
      FilterButton({
        label: $r('app.string.tasks_filter_todo'), value: TaskListFilter.TODO,
        selected: this.selected, count: this.todoCount, onSelect: this.onSelect
      })
      FilterButton({
        label: $r('app.string.tasks_filter_completed'), value: TaskListFilter.COMPLETED,
        selected: this.selected, count: this.completedCount, onSelect: this.onSelect
      })
      FilterButton({
        label: $r('app.string.tasks_filter_deleted'), value: TaskListFilter.DELETED,
        selected: this.selected, count: this.deletedCount, onSelect: this.onSelect
      })
    }
    .width('100%')
    .padding(AppSpacing.XS)
    .backgroundColor($r('app.color.surface_secondary'))
    .borderRadius(AppRadius.MD)
  }
}
