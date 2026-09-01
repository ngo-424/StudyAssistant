import { AppControl, AppRadius, AppSpacing, AppTypography } from '../../../../core/design/DesignTokens'
import { TaskCategory } from '../../../../domain/model/StudyModels'
import { CategoryColor } from '../../domain/CategoryColor'

@Component
struct CategoryChip {
  @Prop categoryKey: string
  @Prop name: string
  @Prop colorSeed: string
  @Prop selectedId: string
  onSelect: (id: string) => void = () => {}

  build() {
    Row({ space: AppSpacing.SM }) {
      Circle({ width: 8, height: 8 })
        .fill(this.colorSeed)

      Text(this.name)
        .fontSize(AppTypography.CAPTION)
        .fontWeight(this.categoryKey === this.selectedId ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.categoryKey === this.selectedId ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
    }
    .height(AppControl.MIN_TOUCH)
    .padding({ left: AppSpacing.MD, right: AppSpacing.MD })
    .backgroundColor(this.categoryKey === this.selectedId ? $r('app.color.brand_container') : $r('app.color.surface_primary'))
    .border({ width: 1, color: this.categoryKey === this.selectedId ? $r('app.color.brand_primary') : $r('app.color.border_subtle') })
    .borderRadius(AppRadius.PILL)
    .onClick(() => this.onSelect(this.categoryKey))
  }
}

@Component
export struct CategorySelector {
  @Prop categories: TaskCategory[] = []
  @Prop selectedId: string = 'all'
  @Prop showAll: boolean = true
  onSelect: (id: string) => void = () => {}

  build() {
    Scroll() {
      Row({ space: AppSpacing.SM }) {
        if (this.showAll) {
          CategoryChip({
            categoryKey: 'all', name: '全部', colorSeed: CategoryColor.NEUTRAL,
            selectedId: this.selectedId, onSelect: this.onSelect
          })
        }
        CategoryChip({
          categoryKey: 'uncategorized', name: '未分类', colorSeed: CategoryColor.NEUTRAL,
          selectedId: this.selectedId, onSelect: this.onSelect
        })
        ForEach(this.categories, (category: TaskCategory) => {
          CategoryChip({
            categoryKey: category.id, name: category.name, colorSeed: category.colorSeed,
            selectedId: this.selectedId, onSelect: this.onSelect
          })
        }, (category: TaskCategory) => category.id)
      }
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }
}
