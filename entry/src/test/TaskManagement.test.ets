import { describe, expect, it } from '@ohos/hypium'
import { StudyTask, SyncState, TaskCategory, TaskStatus } from '../main/ets/domain/model/StudyModels'
import { CategoryColor, CategoryPalette } from '../main/ets/features/tasks/domain/CategoryColor'
import { CategoryDraft, TaskDraft } from '../main/ets/features/tasks/domain/TaskDrafts'
import { CategoryRules, TaskRules } from '../main/ets/features/tasks/domain/TaskRules'
import { TaskListFilter, TaskPresentation } from '../main/ets/features/tasks/presentation/TaskPresentation'

function sampleTask(id: string, status: TaskStatus, deletedAt: number | null,
  categoryId: string | null = null): StudyTask {
  return {
    id: id,
    profileId: 'guest',
    title: `任务 ${id}`,
    notes: '',
    categoryId: categoryId,
    plannedMinutes: 25,
    dueAt: null,
    status: status,
    completedAt: status === TaskStatus.COMPLETED ? 2000 : null,
    createdAt: 1000,
    updatedAt: 1000,
    deletedAt: deletedAt,
    revision: 0,
    syncState: SyncState.LOCAL_ONLY
  }
}

export default function taskManagementTest(): void {
  describe('taskManagement', () => {
    it('normalizesAndValidatesCategoryColors', 0, () => {
      expect(CategoryColor.normalize(' #53aF9e ')).assertEqual('#53AF9E')
      expect(CategoryColor.normalize('#12345')).assertEqual(null)
      const testColors: string[] = CategoryColor.PRESETS.concat(['#777777', '#F8F8F8', '#101010'])
      testColors.forEach((seed: string) => {
        const palette: CategoryPalette = CategoryColor.palette(seed)
        expect(CategoryColor.contrastRatio(palette.accent, palette.onAccent) >= 4.5).assertTrue()
        expect(CategoryColor.contrastRatio(palette.container, palette.onContainer) >= 4.5).assertTrue()
      })
    })

    it('createsSanitizedTaskWithLocalIdentity', 0, () => {
      const draft: TaskDraft = {
        title: '  复习第三章  ', notes: '  完成课后题  ', categoryId: 'math',
        plannedMinutes: 45.4, dueAt: 3000
      }
      const task: StudyTask = TaskRules.create('guest', draft, 1000, 'task-1')
      expect(task.title).assertEqual('复习第三章')
      expect(task.notes).assertEqual('完成课后题')
      expect(task.plannedMinutes).assertEqual(45)
      expect(task.status).assertEqual(TaskStatus.TODO)
      expect(task.syncState).assertEqual(SyncState.LOCAL_ONLY)
    })

    it('completesRestoresAndVersionsTask', 0, () => {
      const original: StudyTask = sampleTask('one', TaskStatus.TODO, null)
      const completed: StudyTask = TaskRules.setCompleted(original, true, 2000)
      expect(completed.status).assertEqual(TaskStatus.COMPLETED)
      expect(completed.completedAt).assertEqual(2000)
      expect(completed.revision).assertEqual(1)
      const deleted: StudyTask = sampleTask('one', TaskStatus.COMPLETED, 3000)
      const restored: StudyTask = TaskRules.restore(deleted, 4000)
      expect(restored.deletedAt).assertEqual(null)
      expect(restored.status).assertEqual(TaskStatus.COMPLETED)
      expect(restored.syncState).assertEqual(SyncState.LOCAL_ONLY)
    })

    it('createsCategoryWithPersistentCustomColor', 0, () => {
      const draft: CategoryDraft = { name: '  数学  ', colorSeed: '#52a36f' }
      const category: TaskCategory = CategoryRules.create('guest', draft, 1000, 'category-1')
      expect(category.name).assertEqual('数学')
      expect(category.colorSeed).assertEqual('#52A36F')
      expect(category.deletedAt).assertEqual(null)
    })

    it('filtersActiveCompletedAndDeletedTasks', 0, () => {
      const tasks: StudyTask[] = [
        sampleTask('todo-math', TaskStatus.TODO, null, 'math'),
        sampleTask('todo-free', TaskStatus.TODO, null, null),
        sampleTask('done', TaskStatus.COMPLETED, null, 'math'),
        sampleTask('deleted', TaskStatus.TODO, 5000, 'math')
      ]
      expect(TaskPresentation.visibleTasks(tasks, TaskListFilter.TODO, 'math').length).assertEqual(1)
      expect(TaskPresentation.visibleTasks(tasks, TaskListFilter.TODO, 'uncategorized').length).assertEqual(1)
      expect(TaskPresentation.visibleTasks(tasks, TaskListFilter.COMPLETED, 'all').length).assertEqual(1)
      expect(TaskPresentation.visibleTasks(tasks, TaskListFilter.DELETED, 'all').length).assertEqual(1)
    })
  })
}
