import { describe, expect, it } from '@ohos/hypium'
import {
  DATABASE_V1_STATEMENTS,
  DATABASE_V2_STATEMENTS,
  DATABASE_V3_STATEMENTS,
  DATABASE_VERSION,
  GUEST_PROFILE_ID
} from '../main/ets/data/database/DatabaseSchema'
import { LegacyDataParser, LegacyTaskCandidate } from '../main/ets/data/migration/LegacyDataParser'
import { TaskStatus } from '../main/ets/domain/model/StudyModels'

export default function dataFoundationTest(): void {
  describe('dataFoundation', () => {
    it('definesVersionedSchema', 0, () => {
      expect(DATABASE_VERSION).assertEqual(3)
      const schema: string = DATABASE_V1_STATEMENTS.join(' ')
      expect(schema).assertContain('study_tasks')
      expect(schema).assertContain('focus_sessions')
      expect(schema).assertContain('reward_events')
      expect(schema).assertContain('migration_history')
      expect(DATABASE_V2_STATEMENTS.join(' ')).assertContain('session_id')
      expect(DATABASE_V3_STATEMENTS.join(' ')).assertContain('account_session')
      expect(DATABASE_V3_STATEMENTS.join(' ')).assertContain('refresh_token')
    })

    it('parsesOnlyRecognizableLegacyTasks', 0, () => {
      const legacyJson: string = `{
        "focusMinutes":999,
        "completedCount":1,
        "tasks":[
          {"code":"DS","title":"学习数据结构","subtitle":"数据结构 · 60分钟","status":"已完成"},
          {"code":"AR","title":"学习 ArkTS","subtitle":"鸿蒙开发 · 120分钟","status":"未开始"},
          {"code":"EMPTY","title":"   ","subtitle":"无效 · 30分钟","status":"未开始"}
        ]
      }`
      let idSequence: number = 0
      const migratedAt: number = 1000
      const candidates: LegacyTaskCandidate[] = LegacyDataParser.parse(legacyJson, migratedAt, () => {
        idSequence += 1
        return `legacy-${idSequence}`
      })

      expect(candidates.length).assertEqual(2)
      expect(candidates[0].task.profileId).assertEqual(GUEST_PROFILE_ID)
      expect(candidates[0].task.status).assertEqual(TaskStatus.COMPLETED)
      expect(candidates[0].task.plannedMinutes).assertEqual(60)
      expect(candidates[0].task.completedAt).assertEqual(migratedAt)
      expect(candidates[1].task.plannedMinutes).assertEqual(90)
      expect(candidates[1].task.categoryId).assertEqual(null)
    })

    it('usesSafeDefaultsForLegacyDuration', 0, () => {
      const candidates: LegacyTaskCandidate[] = LegacyDataParser.parse(
        '{"tasks":[{"code":"X","title":"没有时长的任务","subtitle":"旧数据","status":"未开始"}]}',
        1000,
        () => 'legacy-default')
      expect(candidates.length).assertEqual(1)
      expect(candidates[0].task.plannedMinutes).assertEqual(25)
      expect(candidates[0].task.status).assertEqual(TaskStatus.TODO)
    })
  })
}
