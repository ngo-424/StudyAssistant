import { describe, expect, it } from '@ohos/hypium'
import { SyncConflict, SyncEntityType } from '../../../main/ets/domain/model/StudyModels'
import { SyncConflictPresentation } from '../../../main/ets/features/sync/presentation/SyncConflictPresentation'

function conflict(localPayload: string, serverPayload: string): SyncConflict {
  return {
    id: 'conflict-1', profileId: 'account-1', mutationId: 'mutation-1',
    entityType: SyncEntityType.TASK, entityId: 'task-uuid-hidden',
    localPayload: localPayload, serverPayload: serverPayload,
    serverRevision: 2, createdAt: 1, resolvedAt: null
  }
}

export default function syncConflictTest(): void {
  describe('SyncConflictPresentation', () => {
    it('showsUserContentWithoutInternalIds', 0, () => {
      const local: string = JSON.stringify({
        title: '复习第三章', notes: '完成课后题', plannedMinutes: 25, updatedAt: 1725156000000
      })
      const cloud: string = JSON.stringify({
        title: '复习第四章', notes: '', plannedMinutes: 45, updatedAt: 1725159600000
      })
      const display = SyncConflictPresentation.map(conflict(local, cloud))
      expect(display.previewable).assertTrue()
      expect(display.local.name).assertEqual('复习第三章')
      expect(display.cloud.content).assertEqual('计划专注 45 分钟')
      expect(JSON.stringify(display).includes('task-uuid-hidden')).assertFalse()
    })

    it('blocksAnUnreadablePayload', 0, () => {
      const valid: string = JSON.stringify({
        title: '可读取任务', notes: '', plannedMinutes: 25, updatedAt: 1725156000000
      })
      const display = SyncConflictPresentation.map(conflict('{broken', valid))
      expect(display.previewable).assertFalse()
    })
  })
}
