import { StudyTask, TaskCategory } from '../../../domain/model/StudyModels'
import { CategoryRepository, TaskRepository } from '../../../domain/repository/StudyRepositories'
import { CategoryDraft, TaskDraft } from './TaskDrafts'
import { CategoryRules, TaskRules } from './TaskRules'

export class ManageTasksUseCase {
  private readonly tasks: TaskRepository
  private readonly categories: CategoryRepository
  private readonly clock: () => number
  private readonly idFactory: () => string
  private readonly profileId: string

  constructor(tasks: TaskRepository, categories: CategoryRepository,
    clock: () => number, idFactory: () => string, profileId: string) {
    this.tasks = tasks
    this.categories = categories
    this.clock = clock
    this.idFactory = idFactory
    this.profileId = profileId
  }

  async save(draft: TaskDraft, existing: StudyTask | null): Promise<void> {
    let categoryId: string | null = draft.categoryId
    if (draft.categoryId !== null) {
      const categories: TaskCategory[] = await this.categories.findAll(
        existing?.profileId ?? this.profileId, false)
      const categoryExists: boolean = categories.some((category: TaskCategory) => category.id === draft.categoryId)
      if (!categoryExists) {
        categoryId = null
      }
    }
    const validatedDraft: TaskDraft = {
      title: draft.title,
      notes: draft.notes,
      categoryId: categoryId,
      plannedMinutes: draft.plannedMinutes,
      dueAt: draft.dueAt
    }
    const task: StudyTask = existing === null ?
      TaskRules.create(this.profileId, validatedDraft, this.clock(), this.idFactory()) :
      TaskRules.update(existing, validatedDraft, this.clock())
    await this.tasks.save(task)
  }

  async setCompleted(task: StudyTask, completed: boolean): Promise<void> {
    await this.tasks.save(TaskRules.setCompleted(task, completed, this.clock()))
  }

  async delete(task: StudyTask): Promise<void> {
    await this.tasks.softDelete(task.id, this.clock())
  }

  async restore(task: StudyTask): Promise<void> {
    await this.tasks.save(TaskRules.restore(task, this.clock()))
  }
}

export class ManageCategoriesUseCase {
  private readonly categories: CategoryRepository
  private readonly clock: () => number
  private readonly idFactory: () => string
  private readonly profileId: string

  constructor(categories: CategoryRepository, clock: () => number, idFactory: () => string, profileId: string) {
    this.categories = categories
    this.clock = clock
    this.idFactory = idFactory
    this.profileId = profileId
  }

  async save(draft: CategoryDraft, existing: TaskCategory | null): Promise<void> {
    const category: TaskCategory = existing === null ?
      CategoryRules.create(this.profileId, draft, this.clock(), this.idFactory()) :
      CategoryRules.update(existing, draft, this.clock())
    await this.categories.save(category)
  }

  async delete(category: TaskCategory): Promise<void> {
    await this.categories.softDelete(category.id, this.clock())
  }

  async restore(category: TaskCategory): Promise<void> {
    await this.categories.save(CategoryRules.restore(category, this.clock()))
  }
}
