import { describe, expect, it } from '@ohos/hypium'
import { SyncState } from '../main/ets/domain/model/StudyModels'
import { ProfileContext } from '../main/ets/features/sync/application/ProfileContext'
import { CategoryRules, TaskRules } from '../main/ets/features/tasks/domain/TaskRules'

export default function syncProfileTest() {
  describe('SyncProfile', () => {
    it('keeps guest and account profiles isolated', 0, () => {
      ProfileContext.activateGuest()
      expect(ProfileContext.currentProfileId()).assertEqual('guest')
      ProfileContext.activateAccount('account-1')
      expect(ProfileContext.currentProfileId()).assertEqual('account:account-1')
      ProfileContext.activateGuest()
      expect(ProfileContext.currentProfileId()).assertEqual('guest')
    })

    it('marks account tasks and categories pending while guests stay local', 0, () => {
      const guestTask = TaskRules.create('guest', {
        title: 'guest', notes: '', categoryId: null, plannedMinutes: 25, dueAt: null
      }, 1, 'guest-task')
      const accountTask = TaskRules.create('account:1', {
        title: 'account', notes: '', categoryId: null, plannedMinutes: 25, dueAt: null
      }, 1, 'account-task')
      const accountCategory = CategoryRules.create('account:1', {
        name: '学习', colorSeed: '#4F6B5A'
      }, 1, 'account-category')
      expect(guestTask.syncState).assertEqual(SyncState.LOCAL_ONLY)
      expect(accountTask.syncState).assertEqual(SyncState.PENDING)
      expect(accountCategory.syncState).assertEqual(SyncState.PENDING)
    })
  })
}
