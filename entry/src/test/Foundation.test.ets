import { describe, expect, it } from '@ohos/hypium'
import { AppTab } from '../main/ets/app/AppTab'
import { AppError, AppErrorCode } from '../main/ets/core/error/AppError'

export default function foundationTest(): void {
  describe('foundation', () => {
    it('definesStableNavigationKeys', 0, () => {
      expect(AppTab.FOCUS).assertEqual('focus')
      expect(AppTab.INSIGHTS).assertEqual('insights')
      expect(AppTab.TASKS).assertEqual('tasks')
      expect(AppTab.SETTINGS).assertEqual('settings')
    })

    it('keepsStructuredErrorCode', 0, () => {
      const error: AppError = new AppError(AppErrorCode.VALIDATION, 'invalid input')
      expect(error.code).assertEqual(AppErrorCode.VALIDATION)
      expect(error.message).assertEqual('invalid input')
    })
  })
}
