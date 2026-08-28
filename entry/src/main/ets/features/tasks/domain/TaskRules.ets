import { AppError, AppErrorCode } from '../../../core/error/AppError'
import { StudyTask, SyncState, TaskCategory, TaskStatus } from '../../../domain/model/StudyModels'
import { CategoryColor } from './CategoryColor'
import { CategoryDraft, TaskDraft } from './TaskDrafts'

export class TaskRules {
  static create(profileId: string, draft: TaskDraft, now: number, id: string): StudyTask {
    TaskRules.validateTask(draft)
    return {
      id: id,
      profileId: profileId,
      title: draft.title.trim(),
      notes: draft.notes.trim(),
      categoryId: draft.categoryId,
      plannedMinutes: Math.round(draft.plannedMinutes),
      dueAt: draft.dueAt,
      status: TaskStatus.TODO,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 0,
      syncState: SyncState.LOCAL_ONLY
    }
  }

  static update(task: StudyTask, draft: TaskDraft, now: number): StudyTask {
    TaskRules.validateTask(draft)
    return TaskRules.copyTask(task, draft.title.trim(), draft.notes.trim(), draft.categoryId,
      Math.round(draft.plannedMinutes), draft.dueAt, task.status, task.completedAt,
      task.deletedAt, now, task.revision + 1)
  }

  static setCompleted(task: StudyTask, completed: boolean, now: number): StudyTask {
    return TaskRules.copyTask(task, task.title, task.notes, task.categoryId, task.plannedMinutes,
      task.dueAt, completed ? TaskStatus.COMPLETED : TaskStatus.TODO, completed ? now : null,
      task.deletedAt, now, task.revision + 1)
  }

  static restore(task: StudyTask, now: number): StudyTask {
    return TaskRules.copyTask(task, task.title, task.notes, task.categoryId, task.plannedMinutes,
      task.dueAt, task.status, task.completedAt, null, now, task.revision + 1)
  }

  static validateTask(draft: TaskDraft): void {
    const titleLength: number = draft.title.trim().length
    if (titleLength === 0 || titleLength > 120) {
      throw new AppError(AppErrorCode.VALIDATION, 'TASK_TITLE_INVALID')
    }
    if (draft.notes.trim().length > 500) {
      throw new AppError(AppErrorCode.VALIDATION, 'TASK_NOTES_TOO_LONG')
    }
    if (!Number.isFinite(draft.plannedMinutes) || draft.plannedMinutes < 5 || draft.plannedMinutes > 480) {
      throw new AppError(AppErrorCode.VALIDATION, 'TASK_DURATION_INVALID')
    }
  }

  private static copyTask(task: StudyTask, title: string, notes: string, categoryId: string | null,
    plannedMinutes: number, dueAt: number | null, status: TaskStatus, completedAt: number | null,
    deletedAt: number | null, updatedAt: number, revision: number): StudyTask {
    return {
      id: task.id,
      profileId: task.profileId,
      title: title,
      notes: notes,
      categoryId: categoryId,
      plannedMinutes: plannedMinutes,
      dueAt: dueAt,
      status: status,
      completedAt: completedAt,
      createdAt: task.createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      revision: revision,
      syncState: task.syncState === SyncState.LOCAL_ONLY ? SyncState.LOCAL_ONLY : SyncState.PENDING
    }
  }
}

export class CategoryRules {
  static create(profileId: string, draft: CategoryDraft, now: number, id: string): TaskCategory {
    const normalizedColor: string = CategoryRules.validate(draft)
    return {
      id: id,
      profileId: profileId,
      name: draft.name.trim(),
      colorSeed: normalizedColor,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 0,
      syncState: SyncState.LOCAL_ONLY
    }
  }

  static update(category: TaskCategory, draft: CategoryDraft, now: number): TaskCategory {
    const normalizedColor: string = CategoryRules.validate(draft)
    return CategoryRules.copy(category, draft.name.trim(), normalizedColor, category.deletedAt,
      now, category.revision + 1)
  }

  static restore(category: TaskCategory, now: number): TaskCategory {
    return CategoryRules.copy(category, category.name, category.colorSeed, null, now, category.revision + 1)
  }

  private static validate(draft: CategoryDraft): string {
    const nameLength: number = draft.name.trim().length
    if (nameLength === 0 || nameLength > 24) {
      throw new AppError(AppErrorCode.VALIDATION, 'CATEGORY_NAME_INVALID')
    }
    const normalizedColor: string | null = CategoryColor.normalize(draft.colorSeed)
    if (normalizedColor === null) {
      throw new AppError(AppErrorCode.VALIDATION, 'CATEGORY_COLOR_INVALID')
    }
    return normalizedColor
  }

  private static copy(category: TaskCategory, name: string, colorSeed: string,
    deletedAt: number | null, updatedAt: number, revision: number): TaskCategory {
    return {
      id: category.id,
      profileId: category.profileId,
      name: name,
      colorSeed: colorSeed,
      createdAt: category.createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      revision: revision,
      syncState: category.syncState === SyncState.LOCAL_ONLY ? SyncState.LOCAL_ONLY : SyncState.PENDING
    }
  }
}
