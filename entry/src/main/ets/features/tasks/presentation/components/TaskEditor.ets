import { AppControl, AppRadius, AppSpacing, AppTypography } from '../../../../core/design/DesignTokens'
import { TaskCategory } from '../../../../domain/model/StudyModels'
import { CategorySelector } from './CategorySelector'

@Component
export struct TaskEditor {
  @Prop isWide: boolean = false
  @Prop isEditing: boolean = false
  @Prop saving: boolean = false
  @Prop categories: TaskCategory[] = []
  @Link title: string
  @Link notes: string
  @Link plannedMinutes: string
  @Link dueAt: number
  @Link categoryId: string
  onSave: () => void = () => {}
  onCancel: () => void = () => {}

  private selectDate(): void {
    const now: Date = new Date()
    const selected: Date = this.dueAt > 0 ? new Date(this.dueAt) : now
    const end: Date = new Date(now.getFullYear() + 5, 11, 31)
    this.getUIContext().showDatePickerDialog({
      start: new Date(2020, 0, 1),
      end: end,
      selected: selected,
      onDateAccept: (value: Date) => {
        value.setHours(23, 59, 59, 999)
        this.dueAt = value.getTime()
      }
    })
  }

  private dateLabel(): string {
    if (this.dueAt <= 0) {
      return '未设置截止日期'
    }
    const date: Date = new Date(this.dueAt)
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`
  }

  private canSave(): boolean {
    const minutes: number = Number(this.plannedMinutes)
    return this.title.trim().length > 0 && this.title.trim().length <= 120 &&
      Number.isFinite(minutes) && minutes >= 5 && minutes <= 480
  }

  build() {
    Column({ space: AppSpacing.LG }) {
      Row() {
        Column({ space: AppSpacing.XS }) {
          Text(this.isEditing ? $r('app.string.task_edit_title') : $r('app.string.task_create_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.task_editor_hint'))
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([$r('app.color.text_secondary')])
        }
          .width(AppControl.MIN_TOUCH)
          .height(AppControl.MIN_TOUCH)
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.PILL)
          .enabled(!this.saving)
          .accessibilityText($r('app.string.common_close'))
          .onClick(this.onCancel)
      }
      .width('100%')

      if (this.isWide) {
        Row({ space: AppSpacing.LG }) {
          this.PrimaryFields()
          this.PlanningFields()
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      } else {
        Column({ space: AppSpacing.LG }) {
          this.PrimaryFields()
          this.PlanningFields()
        }
        .width('100%')
      }

      Row({ space: AppSpacing.MD }) {
        Blank()
        Button($r('app.string.common_cancel'))
          .height(AppControl.MIN_TOUCH)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.MD)
          .enabled(!this.saving)
          .onClick(this.onCancel)
        Button(this.saving ? $r('app.string.task_saving') :
          (this.isEditing ? $r('app.string.common_save') : $r('app.string.task_create_action')))
          .height(AppControl.MIN_TOUCH)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius(AppRadius.MD)
          .enabled(this.canSave() && !this.saving)
          .onClick(this.onSave)
      }
      .width('100%')
    }
    .width('100%')
    .padding(this.isWide ? AppSpacing.XL : AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.brand_primary') })
  }

  @Builder
  private PrimaryFields() {
    Column({ space: AppSpacing.MD }) {
      Column({ space: AppSpacing.XS }) {
        Text($r('app.string.task_field_title'))
          .fontSize(AppTypography.CAPTION)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_secondary'))
        TextInput({ text: this.title, placeholder: $r('app.string.task_title_placeholder') })
          .height(48)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM)
          .maxLength(120)
          .onChange((value: string) => this.title = value)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: AppSpacing.XS }) {
        Row() {
          Text($r('app.string.task_field_notes'))
            .fontSize(AppTypography.CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(`${this.notes.length}/500`)
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        TextArea({ text: this.notes, placeholder: $r('app.string.task_notes_placeholder') })
          .height(108)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM)
          .maxLength(500)
          .onChange((value: string) => this.notes = value)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  private PlanningFields() {
    Column({ space: AppSpacing.MD }) {
      Column({ space: AppSpacing.XS }) {
        Text($r('app.string.task_field_duration'))
          .fontSize(AppTypography.CAPTION)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_secondary'))
        Row({ space: AppSpacing.SM }) {
          TextInput({ text: this.plannedMinutes, placeholder: '25' })
            .layoutWeight(1)
            .height(48)
            .type(InputType.Number)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(AppRadius.SM)
            .maxLength(3)
            .onChange((value: string) => this.plannedMinutes = value)
          Text($r('app.string.minutes_unit'))
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        Row({ space: AppSpacing.XS }) {
          ForEach([15, 25, 45, 60], (minutes: number) => {
            Button(`${minutes}`)
              .layoutWeight(1)
              .height(AppControl.MIN_TOUCH)
              .fontSize(AppTypography.CAPTION)
              .fontColor(this.plannedMinutes === `${minutes}` ?
                $r('app.color.brand_on_primary') : $r('app.color.text_secondary'))
              .backgroundColor(this.plannedMinutes === `${minutes}` ?
                $r('app.color.brand_primary') : $r('app.color.surface_secondary'))
              .borderRadius(AppRadius.SM)
              .onClick(() => this.plannedMinutes = `${minutes}`)
          }, (minutes: number) => `${minutes}`)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: AppSpacing.XS }) {
        Text($r('app.string.task_field_due'))
          .fontSize(AppTypography.CAPTION)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_secondary'))
        Row({ space: AppSpacing.SM }) {
          Button(this.dateLabel())
            .layoutWeight(1)
            .height(44)
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(AppRadius.SM)
            .onClick(() => this.selectDate())
          if (this.dueAt > 0) {
            Button($r('app.string.common_clear'))
              .height(44)
              .fontSize(AppTypography.CAPTION)
              .fontColor($r('app.color.text_secondary'))
              .backgroundColor(Color.Transparent)
              .onClick(() => this.dueAt = 0)
          }
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)

      Column({ space: AppSpacing.XS }) {
        Text($r('app.string.task_field_category'))
          .fontSize(AppTypography.CAPTION)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_secondary'))
        CategorySelector({
          categories: this.categories,
          selectedId: this.categoryId,
          showAll: false,
          onSelect: (id: string) => this.categoryId = id
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .width('100%')
  }
}
