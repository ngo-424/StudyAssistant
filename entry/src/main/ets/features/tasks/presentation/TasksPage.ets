import { AppError } from '../../../core/error/AppError'
import { AppBreakpoint, AppControl, AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { StudyTask, TaskCategory, TaskStatus } from '../../../domain/model/StudyModels'
import { AppStatusBanner, MessageTone } from '../../../shared/components/AppFeedback'
import { CategoryColor } from '../domain/CategoryColor'
import { CategoryDraft, TaskDraft } from '../domain/TaskDrafts'
import { CategoryManager } from './components/CategoryManager'
import { CategorySelector } from './components/CategorySelector'
import { TaskCard } from './components/TaskCard'
import { TaskEditor } from './components/TaskEditor'
import { TaskFilterBar } from './components/TaskFilterBar'
import { TaskListFilter, TaskPresentation } from './TaskPresentation'
import { TasksScreenData, TasksViewModel } from './TasksViewModel'

@Component
export struct TasksPage {
  @Prop isWide: boolean = false
  @State tasks: StudyTask[] = []
  @State categories: TaskCategory[] = []
  @State loading: boolean = true
  @State saving: boolean = false
  @State errorMessage: string = ''
  @State successMessage: string = ''
  @State workingItemId: string = ''
  @State selectedFilter: TaskListFilter = TaskListFilter.TODO
  @State selectedCategoryId: string = 'all'
  @State showTaskEditor: boolean = false
  @State editingTaskId: string = ''
  @State taskTitle: string = ''
  @State taskNotes: string = ''
  @State taskMinutes: string = '25'
  @State taskDueAt: number = 0
  @State taskCategoryId: string = 'uncategorized'
  @State showCategoryManager: boolean = false
  @State editingCategory: boolean = false
  @State editingCategoryId: string = ''
  @State categoryName: string = ''
  @State categoryColor: string = CategoryColor.PRESETS[0]
  private readonly viewModel: TasksViewModel = new TasksViewModel()

  aboutToAppear(): void {
    this.reload()
  }

  private async reload(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.loading = true
    }
    try {
      const data: TasksScreenData = await this.viewModel.load()
      this.tasks = data.tasks
      this.categories = data.categories
      this.errorMessage = ''
      if (this.selectedCategoryId !== 'all' && this.selectedCategoryId !== 'uncategorized' &&
        !this.activeCategories().some((category: TaskCategory) => category.id === this.selectedCategoryId)) {
        this.selectedCategoryId = 'all'
      }
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      if (showLoading) {
        this.loading = false
      }
    }
  }

  private startTaskCreate(): void {
    this.successMessage = ''
    this.editingTaskId = ''
    this.taskTitle = ''
    this.taskNotes = ''
    this.taskMinutes = '25'
    this.taskDueAt = 0
    this.taskCategoryId = this.selectedCategoryId === 'all' ? 'uncategorized' : this.selectedCategoryId
    this.showTaskEditor = true
  }

  private startTaskEdit(task: StudyTask): void {
    this.successMessage = ''
    this.editingTaskId = task.id
    this.taskTitle = task.title
    this.taskNotes = task.notes
    this.taskMinutes = `${task.plannedMinutes}`
    this.taskDueAt = task.dueAt ?? 0
    const categoryActive: boolean = task.categoryId !== null &&
      this.activeCategories().some((category: TaskCategory) => category.id === task.categoryId)
    this.taskCategoryId = categoryActive ? task.categoryId ?? 'uncategorized' : 'uncategorized'
    this.showTaskEditor = true
  }

  private cancelTaskEdit(): void {
    this.showTaskEditor = false
    this.editingTaskId = ''
  }

  private async saveTask(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    const existing: StudyTask | null = this.findTask(this.editingTaskId)
    const draft: TaskDraft = {
      title: this.taskTitle,
      notes: this.taskNotes,
      plannedMinutes: Number(this.taskMinutes),
      dueAt: this.taskDueAt > 0 ? this.taskDueAt : null,
      categoryId: this.taskCategoryId === 'uncategorized' ? null : this.taskCategoryId
    }
    try {
      await this.viewModel.saveTask(draft, existing)
      this.cancelTaskEdit()
      await this.reload(false)
      this.successMessage = '任务已保存'
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.saving = false
    }
  }

  private async toggleTask(task: StudyTask): Promise<void> {
    if (this.workingItemId.length > 0) {
      return
    }
    this.workingItemId = task.id
    const completing: boolean = task.status !== TaskStatus.COMPLETED
    try {
      await this.viewModel.setTaskCompleted(task, completing)
      await this.reload(false)
      this.successMessage = completing ? '任务已完成' : '任务已恢复为进行中'
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.workingItemId = ''
    }
  }

  private confirmTaskDelete(task: StudyTask): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.task_delete_title'),
      message: $r('app.string.task_delete_message'),
      primaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        fontColor: $r('app.color.danger'),
        action: () => this.deleteTask(task)
      }
    })
  }

  private async deleteTask(task: StudyTask): Promise<void> {
    if (this.workingItemId.length > 0) {
      return
    }
    this.workingItemId = task.id
    try {
      await this.viewModel.deleteTask(task)
      if (this.editingTaskId === task.id) {
        this.cancelTaskEdit()
      }
      await this.reload(false)
      this.successMessage = '任务已移到回收站'
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.workingItemId = ''
    }
  }

  private async restoreTask(task: StudyTask): Promise<void> {
    if (this.workingItemId.length > 0) {
      return
    }
    this.workingItemId = task.id
    try {
      await this.viewModel.restoreTask(task)
      await this.reload(false)
      this.successMessage = '任务已恢复'
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.workingItemId = ''
    }
  }

  private openCategoryManager(): void {
    this.showCategoryManager = true
    this.cancelCategoryEdit()
  }

  private startCategoryCreate(): void {
    this.editingCategory = true
    this.editingCategoryId = ''
    this.categoryName = ''
    this.categoryColor = CategoryColor.PRESETS[this.activeCategories().length % CategoryColor.PRESETS.length]
  }

  private startCategoryEdit(category: TaskCategory): void {
    this.editingCategory = true
    this.editingCategoryId = category.id
    this.categoryName = category.name
    this.categoryColor = category.colorSeed
  }

  private cancelCategoryEdit(): void {
    this.editingCategory = false
    this.editingCategoryId = ''
  }

  private async saveCategory(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    const draft: CategoryDraft = { name: this.categoryName, colorSeed: this.categoryColor }
    try {
      await this.viewModel.saveCategory(draft, this.findCategory(this.editingCategoryId))
      this.cancelCategoryEdit()
      await this.reload(false)
      this.successMessage = '类别已保存'
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.saving = false
    }
  }

  private confirmCategoryDelete(category: TaskCategory): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.category_delete_title'),
      message: $r('app.string.category_delete_message'),
      primaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        fontColor: $r('app.color.danger'),
        action: () => this.deleteCategory(category)
      }
    })
  }

  private async deleteCategory(category: TaskCategory): Promise<void> {
    if (this.workingItemId.length > 0) {
      return
    }
    this.workingItemId = category.id
    try {
      await this.viewModel.deleteCategory(category)
      if (this.editingCategoryId === category.id) {
        this.cancelCategoryEdit()
      }
      await this.reload(false)
      this.successMessage = '类别已删除，原任务仍会保留'
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.workingItemId = ''
    }
  }

  private async restoreCategory(category: TaskCategory): Promise<void> {
    if (this.workingItemId.length > 0) {
      return
    }
    this.workingItemId = category.id
    try {
      await this.viewModel.restoreCategory(category)
      await this.reload(false)
      this.successMessage = '类别已恢复'
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.workingItemId = ''
    }
  }

  private activeCategories(): TaskCategory[] {
    return TaskPresentation.activeCategories(this.categories)
  }

  private deletedCategories(): TaskCategory[] {
    return TaskPresentation.deletedCategories(this.categories)
  }

  private visibleTasks(): StudyTask[] {
    return TaskPresentation.visibleTasks(this.tasks, this.selectedFilter, this.selectedCategoryId)
  }

  private count(filter: TaskListFilter): number {
    return TaskPresentation.visibleTasks(this.tasks, filter, 'all').length
  }

  private findTask(id: string): StudyTask | null {
    const match: StudyTask | undefined = this.tasks.find((task: StudyTask) => task.id === id)
    return match ?? null
  }

  private findCategory(id: string): TaskCategory | null {
    const match: TaskCategory | undefined = this.categories.find((category: TaskCategory) => category.id === id)
    return match ?? null
  }

  private readableError(error: Object): string {
    if (error instanceof AppError) {
      if (error.message === 'TASK_TITLE_INVALID') {
        return '任务标题需要填写，且不能超过 120 个字符'
      }
      if (error.message === 'TASK_NOTES_TOO_LONG') {
        return '任务备注不能超过 500 个字符'
      }
      if (error.message === 'TASK_DURATION_INVALID') {
        return '预计时长需要在 5 到 480 分钟之间'
      }
      if (error.message === 'CATEGORY_NAME_INVALID') {
        return '类别名称需要填写，且不能超过 24 个字符'
      }
      if (error.message === 'CATEGORY_COLOR_INVALID') {
        return '请输入 #RRGGBB 格式的颜色值'
      }
    }
    return '操作没有完成，请稍后重试'
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.LG }) {
        Row({ space: AppSpacing.MD }) {
          Column({ space: AppSpacing.XS }) {
            Text($r('app.string.tasks_title'))
              .fontSize(AppTypography.TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.tasks_subtitle'))
              .fontSize(AppTypography.BODY)
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button($r('app.string.category_manage_action'))
            .height(AppControl.MIN_TOUCH)
            .fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.surface_primary'))
            .border({ width: 1, color: $r('app.color.border_subtle') })
            .borderRadius(AppRadius.MD)
            .onClick(() => this.openCategoryManager())
          Button($r('app.string.tasks_create_short'))
            .height(AppControl.MIN_TOUCH)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .borderRadius(AppRadius.MD)
            .onClick(() => this.startTaskCreate())
        }
        .width('100%')

        if (this.errorMessage.length > 0) {
          AppStatusBanner({ message: this.errorMessage, tone: MessageTone.ERROR })
        } else if (this.successMessage.length > 0) {
          AppStatusBanner({ message: this.successMessage, tone: MessageTone.SUCCESS })
        }

        if (this.showTaskEditor) {
          TaskEditor({
            isWide: this.isWide,
            isEditing: this.editingTaskId.length > 0,
            saving: this.saving,
            categories: this.activeCategories(),
            title: $taskTitle,
            notes: $taskNotes,
            plannedMinutes: $taskMinutes,
            dueAt: $taskDueAt,
            categoryId: $taskCategoryId,
            onSave: () => this.saveTask(),
            onCancel: () => this.cancelTaskEdit()
          })
        }

        if (this.showCategoryManager) {
          CategoryManager({
            activeCategories: this.activeCategories(),
            deletedCategories: this.deletedCategories(),
            editing: this.editingCategory,
            editingExisting: this.editingCategoryId.length > 0,
            saving: this.saving,
            workingItemId: this.workingItemId,
            categoryName: $categoryName,
            colorSeed: $categoryColor,
            onStartCreate: () => this.startCategoryCreate(),
            onSave: () => this.saveCategory(),
            onCancelEdit: () => this.cancelCategoryEdit(),
            onEdit: (category: TaskCategory) => this.startCategoryEdit(category),
            onDelete: (category: TaskCategory) => this.confirmCategoryDelete(category),
            onRestore: (category: TaskCategory) => this.restoreCategory(category),
            onClose: () => this.showCategoryManager = false
          })
        }

        TaskFilterBar({
          selected: this.selectedFilter,
          todoCount: this.count(TaskListFilter.TODO),
          completedCount: this.count(TaskListFilter.COMPLETED),
          deletedCount: this.count(TaskListFilter.DELETED),
          onSelect: (filter: TaskListFilter) => this.selectedFilter = filter
        })

        CategorySelector({
          categories: this.activeCategories(),
          selectedId: this.selectedCategoryId,
          onSelect: (id: string) => this.selectedCategoryId = id
        })

        if (this.loading) {
          Column({ space: AppSpacing.MD }) {
            LoadingProgress()
              .width(42)
              .height(42)
              .color($r('app.color.brand_primary'))
            Text($r('app.string.common_loading'))
              .fontSize(AppTypography.CAPTION)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center)
        } else if (this.visibleTasks().length === 0) {
          this.EmptyState()
        } else {
          Column({ space: AppSpacing.MD }) {
            ForEach(this.visibleTasks(), (task: StudyTask) => {
              TaskCard({
                task: task,
                categoryName: TaskPresentation.categoryFor(task, this.categories)?.name ?? '未分类',
                colorSeed: TaskPresentation.categoryFor(task, this.categories)?.colorSeed ?? CategoryColor.NEUTRAL,
                deleted: task.deletedAt !== null,
                working: this.workingItemId === task.id,
                onToggle: (selected: StudyTask) => this.toggleTask(selected),
                onEdit: (selected: StudyTask) => this.startTaskEdit(selected),
                onDelete: (selected: StudyTask) => this.confirmTaskDelete(selected),
                onRestore: (selected: StudyTask) => this.restoreTask(selected)
              })
            }, (task: StudyTask) => `${task.id}-${task.updatedAt}`)
          }
          .width('100%')
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
  private EmptyState() {
    Column({ space: AppSpacing.MD }) {
      SymbolGlyph(this.selectedFilter === TaskListFilter.DELETED ?
        $r('sys.symbol.trash') : $r('sys.symbol.checkmark_circle'))
        .fontSize(36)
        .fontColor([$r('app.color.brand_primary')])
      Text(this.selectedFilter === TaskListFilter.TODO ?
        $r('app.string.tasks_empty_title') : $r('app.string.tasks_empty_filtered_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(this.selectedFilter === TaskListFilter.TODO ?
        $r('app.string.tasks_empty_body') : $r('app.string.tasks_empty_filtered_body'))
        .fontSize(AppTypography.BODY)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      if (this.selectedFilter === TaskListFilter.TODO) {
        Button($r('app.string.tasks_create'))
          .height(AppControl.MIN_TOUCH)
          .margin({ top: AppSpacing.SM })
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.brand_container'))
          .borderRadius(AppRadius.MD)
          .onClick(() => this.startTaskCreate())
      }
    }
    .width('100%')
    .constraintSize({ minHeight: this.isWide ? 320 : 280 })
    .justifyContent(FlexAlign.Center)
    .padding(AppSpacing.XL)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}
