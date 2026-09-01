import { describe, expect, it } from '@ohos/hypium'
import { FocusPhase, FocusResult, SyncState } from '../../../main/ets/domain/model/StudyModels'
import { DataExportSerializer } from '../../../main/ets/features/settings/domain/DataExportModels'

export default function dataExportTest(): void {
  describe('Data export privacy', () => {
    it('exports study data without device or token secrets', 0, () => {
      const document = DataExportSerializer.build('guest', 1000, [], [], [{
        id: 'session-device-test', profileId: 'guest', taskId: null, categoryId: null,
        deviceId: 'must-not-leave-device', phase: FocusPhase.FOCUS,
        plannedSeconds: 1500, focusedSeconds: 1500, startedAt: 10, endedAt: 1510,
        result: FocusResult.COMPLETED, createdAt: 1510, updatedAt: 1510,
        deletedAt: null, revision: 0, syncState: SyncState.LOCAL_ONLY
      }], [], [], [{
        profileId: 'guest', key: 'focus_timer_config_v1', value: '{"focusMinutes":25}', updatedAt: 1
      }, {
        profileId: 'guest', key: 'local_device_id_v1', value: 'must-not-leave-device', updatedAt: 1
      }, {
        profileId: 'guest', key: 'continuation_control_v1', value: 'one-time-transfer-token', updatedAt: 1
      }])
      const serialized: string = DataExportSerializer.serialize(document)
      expect(serialized.includes('session-device-test')).assertTrue()
      expect(serialized.includes('focus_timer_config_v1')).assertTrue()
      expect(serialized.includes('must-not-leave-device')).assertFalse()
      expect(serialized.includes('one-time-transfer-token')).assertFalse()
      expect(serialized.includes('accessToken')).assertFalse()
      expect(serialized.includes('refreshToken')).assertFalse()
    })
  })
}
