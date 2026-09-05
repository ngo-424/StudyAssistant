import { describe, expect, it } from '@ohos/hypium'
import {
  ActiveTimerSnapshot,
  FocusPhase,
  TimerRunState
} from '../../../main/ets/domain/model/StudyModels'
import {
  CONTINUATION_APP_VERSION_CODE,
  CONTINUATION_PREVIOUS_APP_VERSION_CODE,
  CONTINUATION_PROTOCOL_VERSION,
  ContinuationEnvelope
} from '../../../main/ets/features/continuation/domain/ContinuationModels'
import { ContinuationRules } from '../../../main/ets/features/continuation/domain/ContinuationRules'

function activeSnapshot(): ActiveTimerSnapshot {
  return {
    flowId: '00000000-0000-4000-8000-000000000001',
    phaseSessionId: '00000000-0000-4000-8000-000000000002',
    profileId: 'account:account-1',
    taskId: null,
    categoryId: null,
    phase: FocusPhase.FOCUS,
    state: TimerRunState.RUNNING,
    terminalResult: null,
    config: {
      focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
      longBreakEvery: 4, autoStartBreaks: false, autoStartFocus: false
    },
    plannedSeconds: 1500,
    startedAt: 1000,
    deadlineAt: 1501000,
    pausedAt: null,
    remainingSecondsAtPause: null,
    accumulatedPausedMs: 0,
    completedFocusRounds: 0,
    lastObservedAt: 1000,
    lastKnownRemainingSeconds: 1500,
    updatedAt: 1000
  }
}

function envelope(): ContinuationEnvelope {
  return {
    protocolVersion: CONTINUATION_PROTOCOL_VERSION,
    appVersionCode: CONTINUATION_APP_VERSION_CODE,
    accountId: 'account-1',
    sourceDeviceId: 'source-device',
    token: '00000000-0000-4000-8000-00000000000300000000-0000-4000-8000-000000000004',
    preparedAt: 1000,
    expiresAt: 121000,
    snapshot: activeSnapshot()
  }
}

export default function continuationTest(): void {
  describe('ContinuationDevice', () => {
    it('keepsTheTimerIdentityAcrossAValidPayload', 0, () => {
      const decoded: ContinuationEnvelope | null = ContinuationRules.decode(
        ContinuationRules.encode(envelope()))
      expect(decoded?.snapshot.phaseSessionId).assertEqual(
        '00000000-0000-4000-8000-000000000002')
    })

    it('rejectsAnIncompatibleTargetVersion', 0, () => {
      expect(ContinuationRules.compatibleTargetVersion('2.0.0')).assertFalse()
      expect(ContinuationRules.compatibleTargetVersion(CONTINUATION_APP_VERSION_CODE)).assertTrue()
      expect(ContinuationRules.compatibleTargetVersion('1.1.0')).assertTrue()
      expect(ContinuationRules.compatibleTargetVersion('1.1.1')).assertTrue()
      expect(ContinuationRules.compatibleTargetVersion(CONTINUATION_PREVIOUS_APP_VERSION_CODE)).assertTrue()
      expect(ContinuationRules.compatibleTargetVersion('1.0.0')).assertTrue()
    })

    it('acceptsAOnePointZeroEnvelopeInOnePointOne', 0, () => {
      const previous: ContinuationEnvelope = envelope()
      previous.appVersionCode = CONTINUATION_PREVIOUS_APP_VERSION_CODE
      expect(ContinuationRules.decode(ContinuationRules.encode(previous)) !== null).assertTrue()
    })
  })
}
