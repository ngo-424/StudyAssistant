import { AppRadius, AppSpacing, AppTypography } from '../../../../core/design/DesignTokens'
import { StudyTask, TaskStatus } from '../../../../domain/model/StudyModels'
import { CategoryColor } from '../../domain/CategoryColor'
import { TaskPresentation } from '../TaskPresentation'

@Component
export struct TaskCard {
  @Prop task: StudyTask
  @Prop categoryName: string = '未分类'
  @Prop colorSeed: string = CategoryColor.NEUTRAL
  @Prop deleted: boolean = false
  onToggle: (task: StudyTask) => void = () => {}
  onEdit: (task: StudyTask) => void = () => {}
  onDelete: (task: StudyTask) => void = () => {}
  onRestore: (task: StudyTask) => void = () => {}

  build() {
    Row() {
      Column()
        .width(5)
        .height('100%')
        .backgroundColor(this.colorSeed)
        .borderRadius({ topLeft: AppRadius.MD, bottomLeft: AppRadius.MD })

      Column({ space: AppSpacing.MD }) {
        Row({ space: AppSpacing.MD }) {
          if (!this.deleted) {
            Button(this.task.status === TaskStatus.COMPLETED ? '✓' : '')
              .width(36)
              .height(36)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor(this.task.status === TaskStatus.COMPLETED ?
                $r('app.color.success') : Color.Transparent)
              .border({ width: 2, color: this.task.status === TaskStatus.COMPLETED ?
                $r('app.color.success') : $r('app.color.border_strong') })
              .borderRadius(AppRadius.PILL)
              .onClick(() => this.onToggle(this.task))
          }

          Column({ space: AppSpacing.XS }) {
            Text(this.task.title)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.deleted ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
              .decoration({ type: this.task.status === TaskStatus.COMPLETED ?
                TextDecorationType.LineThrough : TextDecorationType.None })
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Row({ space: AppSpacing.SM }) {
              this.CategoryBadge()
              Text(`${this.task.plannedMinutes} 分钟`)
                .fontSize(AppTypography.CAPTION)
                .fontColor($r('app.color.text_secondary'))
              if (this.task.dueAt !== null) {
                Text(TaskPresentation.formatDate(this.task.dueAt))
                  .fontSize(AppTypography.CAPTION)
                  .fontColor(TaskPresentation.isOverdue(this.task, Date.now()) ?
                    $r('app.color.danger') : $r('app.color.text_secondary'))
              }
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        if (this.task.notes.length > 0) {
          Text(this.task.notes)
            .width('100%')
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Row({ space: AppSpacing.SM }) {
          Blank()
          if (this.deleted) {
            Button($r('app.string.common_restore'))
              .height(34)
              .fontSize(AppTypography.CAPTION)
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.brand_container'))
              .borderRadius(AppRadius.SM)
              .onClick(() => this.onRestore(this.task))
          } else {
            Button($r('app.string.common_edit'))
              .height(34)
              .fontSize(AppTypography.CAPTION)
              .fontColor($r('app.color.text_secondary'))
              .backgroundColor($r('app.color.surface_secondary'))
              .borderRadius(AppRadius.SM)
              .onClick(() => this.onEdit(this.task))
            Button($r('app.string.common_delete'))
              .height(34)
              .fontSize(AppTypography.CAPTION)
              .fontColor($r('app.color.danger'))
              .backgroundColor($r('app.color.danger_container'))
              .borderRadius(AppRadius.SM)
              .onClick(() => this.onDelete(this.task))
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .padding(AppSpacing.LG)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border_subtle') })
    .clip(true)
  }

  @Builder
  private CategoryBadge() {
    Row() {
      Text(this.categoryName)
        .fontSize(AppTypography.CAPTION)
        .fontWeight(FontWeight.Bold)
        .fontColor(CategoryColor.palette(this.colorSeed).onAccent)
    }
    .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: 3, bottom: 3 })
    .backgroundColor(CategoryColor.palette(this.colorSeed).accent)
    .borderRadius(AppRadius.PILL)
  }
}
