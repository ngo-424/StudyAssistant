import { AppControl, AppRadius, AppSpacing, AppTypography } from '../../../../core/design/DesignTokens'
import { TaskCategory } from '../../../../domain/model/StudyModels'
import { CategoryColor } from '../../domain/CategoryColor'

@Component
struct CategoryRow {
  @Prop category: TaskCategory
  @Prop deleted: boolean = false
  @Prop working: boolean = false
  onEdit: (category: TaskCategory) => void = () => {}
  onDelete: (category: TaskCategory) => void = () => {}
  onRestore: (category: TaskCategory) => void = () => {}

  build() {
    Row({ space: AppSpacing.MD }) {
      Circle({ width: 18, height: 18 })
        .fill(this.category.colorSeed)
      Text(this.category.name)
        .layoutWeight(1)
        .fontSize(AppTypography.BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.deleted ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
      if (this.deleted) {
        Button($r('app.string.common_restore'))
          .height(AppControl.MIN_TOUCH)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.brand_container'))
          .borderRadius(AppRadius.SM)
          .enabled(!this.working)
          .onClick(() => this.onRestore(this.category))
      } else {
        Button($r('app.string.common_edit'))
          .height(AppControl.MIN_TOUCH)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM)
          .enabled(!this.working)
          .onClick(() => this.onEdit(this.category))
        Button($r('app.string.common_delete'))
          .height(AppControl.MIN_TOUCH)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.danger'))
          .backgroundColor($r('app.color.danger_container'))
          .borderRadius(AppRadius.SM)
          .enabled(!this.working)
          .onClick(() => this.onDelete(this.category))
      }
    }
    .width('100%')
    .padding({ top: AppSpacing.SM, bottom: AppSpacing.SM })
  }
}

@Component
export struct CategoryManager {
  @Prop activeCategories: TaskCategory[] = []
  @Prop deletedCategories: TaskCategory[] = []
  @Prop editing: boolean = false
  @Prop editingExisting: boolean = false
  @Prop saving: boolean = false
  @Prop workingItemId: string = ''
  @State customColorExpanded: boolean = false
  @Link categoryName: string
  @Link colorSeed: string
  onStartCreate: () => void = () => {}
  onSave: () => void = () => {}
  onCancelEdit: () => void = () => {}
  onEdit: (category: TaskCategory) => void = () => {}
  onDelete: (category: TaskCategory) => void = () => {}
  onRestore: (category: TaskCategory) => void = () => {}
  onClose: () => void = () => {}

  private normalizedColor(): string {
    return CategoryColor.normalize(this.colorSeed) ?? CategoryColor.NEUTRAL
  }

  private canSave(): boolean {
    return this.categoryName.trim().length > 0 && this.categoryName.trim().length <= 24 &&
      CategoryColor.normalize(this.colorSeed) !== null
  }

  build() {
    Column({ space: AppSpacing.LG }) {
      Row() {
        Column({ space: AppSpacing.XS }) {
          Text($r('app.string.category_manage_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.category_manage_hint'))
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
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
          .onClick(this.onClose)
      }
      .width('100%')

      if (this.editing) {
        this.Editor()
      } else {
        Button($r('app.string.category_create_action'))
          .width('100%')
          .height(AppControl.PRIMARY_HEIGHT)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.brand_container'))
          .borderRadius(AppRadius.MD)
          .onClick(this.onStartCreate)
      }

      Column() {
        if (this.activeCategories.length === 0) {
          Text($r('app.string.category_empty'))
            .width('100%')
            .padding({ top: AppSpacing.LG, bottom: AppSpacing.LG })
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
        } else {
          ForEach(this.activeCategories, (category: TaskCategory) => {
            CategoryRow({
              category: category,
              working: this.workingItemId === category.id,
              onEdit: this.onEdit,
              onDelete: this.onDelete,
              onRestore: this.onRestore
            })
          }, (category: TaskCategory) => category.id)
        }
      }
      .width('100%')
      .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
      .backgroundColor($r('app.color.surface_secondary'))
      .borderRadius(AppRadius.MD)

      if (this.deletedCategories.length > 0) {
        Column({ space: AppSpacing.XS }) {
          Text($r('app.string.category_deleted_title'))
            .width('100%')
            .fontSize(AppTypography.CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_secondary'))
          Column() {
            ForEach(this.deletedCategories, (category: TaskCategory) => {
              CategoryRow({
                category: category,
                deleted: true,
                working: this.workingItemId === category.id,
                onEdit: this.onEdit,
                onDelete: this.onDelete,
                onRestore: this.onRestore
              })
            }, (category: TaskCategory) => category.id)
          }
          .width('100%')
          .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.MD)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }

  @Builder
  private Editor() {
    Column({ space: AppSpacing.MD }) {
      Row({ space: AppSpacing.MD }) {
        Circle({ width: 44, height: 44 })
          .fill(this.normalizedColor())
        TextInput({ text: this.categoryName, placeholder: $r('app.string.category_name_placeholder') })
          .layoutWeight(1)
          .height(46)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_primary'))
          .borderRadius(AppRadius.SM)
          .maxLength(24)
          .onChange((value: string) => this.categoryName = value)
      }
      .width('100%')

      Text(this.categoryName.trim().length > 0 ? this.categoryName.trim() : '类别预览')
        .fontSize(AppTypography.CAPTION)
        .fontWeight(FontWeight.Bold)
        .fontColor(CategoryColor.palette(this.normalizedColor()).onContainer)
        .backgroundColor(CategoryColor.palette(this.normalizedColor()).container)
        .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.SM, bottom: AppSpacing.SM })
        .borderRadius(AppRadius.PILL)

      Row({ space: AppSpacing.SM }) {
        ForEach(CategoryColor.PRESETS, (color: string) => {
          Button() {
            if (this.normalizedColor() === color) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(18)
                .fontColor([CategoryColor.foregroundFor(color)])
            }
          }
            .layoutWeight(1)
            .height(AppControl.MIN_TOUCH)
            .backgroundColor(color)
            .borderRadius(AppRadius.SM)
            .accessibilityText('选择这个颜色')
            .onClick(() => this.colorSeed = color)
        }, (color: string) => color)
      }
      .width('100%')

      Button($r('app.string.category_custom_color_show'))
        .width('100%')
        .height(AppControl.MIN_TOUCH)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor($r('app.color.surface_primary'))
        .borderRadius(AppRadius.SM)
        .onClick(() => this.customColorExpanded = !this.customColorExpanded)

      if (this.customColorExpanded) {
        Row({ space: AppSpacing.SM }) {
          Text($r('app.string.category_custom_color'))
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
          TextInput({ text: this.colorSeed, placeholder: '#3F704F' })
            .layoutWeight(1)
            .height(AppControl.MIN_TOUCH)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_primary'))
            .borderRadius(AppRadius.SM)
            .maxLength(7)
            .onChange((value: string) => this.colorSeed = value)
        }
        .width('100%')
      }

      Row({ space: AppSpacing.SM }) {
        Blank()
        Button($r('app.string.common_cancel'))
          .height(AppControl.MIN_TOUCH)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.surface_primary'))
          .borderRadius(AppRadius.SM)
          .enabled(!this.saving)
          .onClick(this.onCancelEdit)
        Button(this.saving ? $r('app.string.category_saving') :
          (this.editingExisting ? $r('app.string.common_save') : $r('app.string.common_add')))
          .height(AppControl.MIN_TOUCH)
          .fontWeight(FontWeight.Bold)
          .fontColor(CategoryColor.foregroundFor(this.normalizedColor()))
          .backgroundColor(this.normalizedColor())
          .borderRadius(AppRadius.SM)
          .enabled(this.canSave() && !this.saving)
          .onClick(this.onSave)
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_secondary'))
    .borderRadius(AppRadius.MD)
  }
}
