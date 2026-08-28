import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import {
  CategoryRepository,
  FocusSessionRepository,
  SettingsRepository,
  TaskRepository,
  TimerStateRepository
} from '../../domain/repository/StudyRepositories'
import { LocalCategoryRepository } from './LocalCategoryRepository'
import { LocalFocusSessionRepository } from './LocalFocusSessionRepository'
import { LocalSettingsRepository } from './LocalSettingsRepository'
import { LocalTaskRepository } from './LocalTaskRepository'
import { LocalTimerStateRepository } from './LocalTimerStateRepository'

export class RepositoryRegistry {
  private static taskRepository: TaskRepository | null = null
  private static categoryRepository: CategoryRepository | null = null
  private static focusSessionRepository: FocusSessionRepository | null = null
  private static settingsRepository: SettingsRepository | null = null
  private static timerStateRepository: TimerStateRepository | null = null

  static initialize(store: relationalStore.RdbStore): void {
    RepositoryRegistry.taskRepository = new LocalTaskRepository(store)
    RepositoryRegistry.categoryRepository = new LocalCategoryRepository(store)
    RepositoryRegistry.focusSessionRepository = new LocalFocusSessionRepository(store)
    RepositoryRegistry.settingsRepository = new LocalSettingsRepository(store)
    RepositoryRegistry.timerStateRepository = new LocalTimerStateRepository(RepositoryRegistry.settingsRepository)
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

  static focusSessions(): FocusSessionRepository {
    if (RepositoryRegistry.focusSessionRepository === null) {
      throw new AppError(AppErrorCode.INITIALIZATION, 'Focus session repository has not been initialized')
    }
    return RepositoryRegistry.focusSessionRepository
  }

  static settings(): SettingsRepository {
    if (RepositoryRegistry.settingsRepository === null) {
      throw new AppError(AppErrorCode.INITIALIZATION, 'Settings repository has not been initialized')
    }
    return RepositoryRegistry.settingsRepository
  }

  static timerState(): TimerStateRepository {
    if (RepositoryRegistry.timerStateRepository === null) {
      throw new AppError(AppErrorCode.INITIALIZATION, 'Timer state repository has not been initialized')
    }
    return RepositoryRegistry.timerStateRepository
  }
}
