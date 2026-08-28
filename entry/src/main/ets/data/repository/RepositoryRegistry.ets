import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { CategoryRepository, TaskRepository } from '../../domain/repository/StudyRepositories'
import { LocalCategoryRepository } from './LocalCategoryRepository'
import { LocalTaskRepository } from './LocalTaskRepository'

export class RepositoryRegistry {
  private static taskRepository: TaskRepository | null = null
  private static categoryRepository: CategoryRepository | null = null

  static initialize(store: relationalStore.RdbStore): void {
    RepositoryRegistry.taskRepository = new LocalTaskRepository(store)
    RepositoryRegistry.categoryRepository = new LocalCategoryRepository(store)
  }

  static tasks(): TaskRepository {
    if (RepositoryRegistry.taskRepository === null) {
      throw new AppError(AppErrorCode.INITIALIZATION, 'Task repository has not been initialized')
    }
    return RepositoryRegistry.taskRepository
  }

  static categories(): CategoryRepository {
    if (RepositoryRegistry.categoryRepository === null) {
      throw new AppError(AppErrorCode.INITIALIZATION, 'Category repository has not been initialized')
    }
    return RepositoryRegistry.categoryRepository
  }
}
