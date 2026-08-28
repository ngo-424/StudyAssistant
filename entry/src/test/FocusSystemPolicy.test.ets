import { describe, expect, it } from '@ohos/hypium'
import { WindowLayoutPolicy } from '../main/ets/core/design/WindowLayoutPolicy'
import { FocusPhase } from '../main/ets/domain/model/StudyModels'
import { CapabilityState, FocusSystemStatus } from '../main/ets/features/focus/system/FocusSystemModels'
import { FocusSystemPolicy } from '../main/ets/features/focus/system/FocusSystemPolicy'

function status(notification: CapabilityState, reminder: CapabilityState,
  liveView: CapabilityState): FocusSystemStatus {
  return {
    notification: notification,
    reminder: reminder,
    liveView: liveView,
    fallbackNotification: false
  }
}

export default function focusSystemPolicyTest(): void {
  describe('focusSystemPolicy', () => {
    it('createsStablePositiveIdsForEveryFocusFlow', 0, () => {
      const first: number = FocusSystemPolicy.stableId('flow-1', 17)
      expect(first).assertLarger(0)
      expect(FocusSystemPolicy.stableId('flow-1', 17)).assertEqual(first)
      expect(FocusSystemPolicy.stableId('flow-1', 41) === first).assertFalse()
    })

    it('usesOrdinaryNotificationOnlyAsARealFallback', 0, () => {
      expect(FocusSystemPolicy.shouldPublishFallback(status(
        CapabilityState.READY, CapabilityState.UNAVAILABLE, CapabilityState.READY))).assertTrue()
      expect(FocusSystemPolicy.shouldPublishFallback(status(
        CapabilityState.READY, CapabilityState.READY, CapabilityState.READY))).assertFalse()
      expect(FocusSystemPolicy.shouldPublishFallback(status(
        CapabilityState.DENIED, CapabilityState.DENIED, CapabilityState.UNAVAILABLE))).assertFalse()
    })

    it('buildsPrivatePhaseOnlyReminderCopy', 0, () => {
      expect(FocusSystemPolicy.phaseTitle(FocusPhase.FOCUS)).assertEqual('专注进行中')
      expect(FocusSystemPolicy.phaseTitle(FocusPhase.SHORT_BREAK)).assertEqual('短休息进行中')
      expect(FocusSystemPolicy.completionText(FocusPhase.FOCUS)).assertEqual('本轮专注已完成')
      expect(FocusSystemPolicy.completionText(FocusPhase.LONG_BREAK)).assertEqual('休息结束，可以开始下一轮')
    })

    it('selectsCompactLayoutOnlyForSmallWindowShapes', 0, () => {
      expect(WindowLayoutPolicy.isCompact(360, 780)).assertFalse()
      expect(WindowLayoutPolicy.isCompact(900, 600)).assertFalse()
      expect(WindowLayoutPolicy.isCompact(420, 560)).assertTrue()
    })
  })
}
