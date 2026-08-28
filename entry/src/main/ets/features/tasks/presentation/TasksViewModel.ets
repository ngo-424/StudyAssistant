import { util } from '@kit.ArkTS'
import { AppInitializer } from '../../../app/AppInitializer'
import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { StudyTask, TaskCategory } from '../../../domain/model/StudyModels'
import { CategoryDraft, TaskDraft } from '../domain/TaskDrafts'
import { ManageCategoriesUseCase, ManageTasksUseCase } from '../domain/ManageTasksUseCase'

export interface TasksScreenData {
  tasks: StudyTask[]
  categories: TaskCategory[]
}

export class TasksViewModel {
  private taskUseCase: ManageTasksUseCase | null = null
  private categoryUseCase: ManageCategoriesUseCase | null = null

  async load(): Promise<TasksScreenData> {
    await this.ensureReady()
    const tasks: StudyTask[] = await RepositoryRegistry.tasks().findAll(GUEST_PROFILE_ID, true)
    const categories: TaskCategory[] = await RepositoryRegistry.categories().findAll(GUEST_PROFILE_ID, true)
    return { tasks: tasks, categories: categories }
  }

  async saveTask(draft: TaskDraft, existing: StudyTask | null): Promise<void> {
    await this.ensureReady()
    await this.tasksController().save(draft, existing)
  }

  async setTaskCompleted(task: StudyTask, completed: boolean): Promise<void> {
    await this.ensureReady()
    await this.tasksController().setCompleted(task, completed)
  }

  async deleteTask(task: StudyTask): Promise<void> {
    await this.ensureReady()
    await this.tasksController().delete(task)
  }

  async restoreTask(task: StudyTask): Promise<void> {
    await this.ensureReady()
    await this.tasksController().restore(task)
  }

  async saveCategory(draft: CategoryDraft, existing: TaskCategory | null): Promise<void> {
    await this.ensureReady()
    await this.categoriesController().save(draft, existing)
  }

  async deleteCategory(category: TaskCategory): Promise<void> {
    await this.ensureReady()
    await this.categoriesController().delete(category)
  }

  async restoreCategory(category: TaskCategory): Promise<void> {
    await this.ensureReady()
    await this.categoriesController().restore(category)
  }

  private async ensureReady(): Promise<void> {
    await AppInitializer.whenReady()
    if (this.taskUseCase !== null && this.categoryUseCase !== null) {
      return
    }
    this.taskUseCase = new ManageTasksUseCase(
      RepositoryRegistry.tasks(), RepositoryRegistry.categories(),
      () => Date.now(), () => util.generateRandomUUID(true), GUEST_PROFILE_ID)
    this.categoryUseCase = new ManageCategoriesUseCase(
      RepositoryRegistry.categories(), () => Date.now(), () => util.generateRandomUUID(true), GUEST_PROFILE_ID)
  }

  private tasksController(): ManageTasksUseCase {
    if (this.taskUseCase === null) {
      throw new Error('Task use case is unavailable')
    }
    return this.taskUseCase
  }

  private categoriesController(): ManageCategoriesUseCase {
    if (this.categoryUseCase === null) {
      throw new Error('Category use case is unavailable')
    }
    return this.categoryUseCase
  }
}
