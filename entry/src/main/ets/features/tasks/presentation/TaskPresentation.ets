import { StudyTask, TaskCategory, TaskStatus } from '../../../domain/model/StudyModels'

export enum TaskListFilter {
  TODO = 'todo',
  COMPLETED = 'completed',
  DELETED = 'deleted'
}

export class TaskPresentation {
  static visibleTasks(tasks: StudyTask[], filter: TaskListFilter, categoryId: string): StudyTask[] {
    return tasks.filter((task: StudyTask) => {
      const matchesState: boolean = filter === TaskListFilter.DELETED ? task.deletedAt !== null :
        task.deletedAt === null && task.status === (filter === TaskListFilter.TODO ? TaskStatus.TODO : TaskStatus.COMPLETED)
      const matchesCategory: boolean = categoryId === 'all' ||
        (categoryId === 'uncategorized' ? task.categoryId === null : task.categoryId === categoryId)
      return matchesState && matchesCategory
    })
  }

  static activeCategories(categories: TaskCategory[]): TaskCategory[] {
    return categories.filter((category: TaskCategory) => category.deletedAt === null)
  }

  static deletedCategories(categories: TaskCategory[]): TaskCategory[] {
    return categories.filter((category: TaskCategory) => category.deletedAt !== null)
  }

  static categoryFor(task: StudyTask, categories: TaskCategory[]): TaskCategory | null {
    const match: TaskCategory | undefined = categories.find((category: TaskCategory) =>
      category.id === task.categoryId && category.deletedAt === null)
    return match ?? null
  }

  static formatDate(timestamp: number): string {
    const date: Date = new Date(timestamp)
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`
  }

  static isOverdue(task: StudyTask, now: number): boolean {
    return task.status === TaskStatus.TODO && task.dueAt !== null && task.dueAt < now
  }
}
