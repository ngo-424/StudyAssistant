import { describe, expect, it } from '@ohos/hypium'
import {
  ActiveTimerSnapshot,
  FocusPhase,
  FocusResult,
  TimerConfig,
  TimerRunState
} from '../main/ets/domain/model/StudyModels'
import { TimerStateCodec } from '../main/ets/data/repository/TimerStateCodec'
import { FocusTimerEngine } from '../main/ets/features/focus/domain/FocusTimerEngine'
import { TimerConfigRules } from '../main/ets/features/focus/domain/TimerConfigRules'
import { TimerStartContext, TimerTransition } from '../main/ets/features/focus/domain/TimerModels'

function testConfig(): TimerConfig {
  return {
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    longBreakEvery: 4,
    autoStartBreaks: false,
    autoStartFocus: false
  }
}

function testContext(): TimerStartContext {
  return { profileId: 'guest', taskId: null, categoryId: null }
}

function start(now: number = 1000): TimerTransition {
  return FocusTimerEngine.startFocus(testConfig(), testContext(), now, 'flow-1', 'session-1')
}

export default function focusTimerEngineTest(): void {
  describe('focusTimerEngine', () => {
    it('usesExpectedDefaultConfiguration', 0, () => {
      const config: TimerConfig = TimerConfigRules.defaults()
      expect(config.focusMinutes).assertEqual(25)
      expect(config.shortBreakMinutes).assertEqual(5)
      expect(config.longBreakMinutes).assertEqual(15)
      expect(config.longBreakEvery).assertEqual(4)
      expect(config.autoStartBreaks).assertFalse()
      expect(config.autoStartFocus).assertFalse()
    })

    it('derivesRemainingTimeFromDeadline', 0, () => {
      const initial: TimerTransition = start(1000)
      const observed: TimerTransition = FocusTimerEngine.synchronize(initial.snapshot, 62500)
      expect(observed.reading.remainingSeconds).assertEqual(1439)
      expect(observed.reading.elapsedSeconds).assertEqual(61)
      expect(observed.snapshot.state).assertEqual(TimerRunState.RUNNING)
    })

    it('freezesTimeWhilePausedAndResumesFromSnapshot', 0, () => {
      const initial: TimerTransition = start(1000)
      const paused: TimerTransition = FocusTimerEngine.pause(initial.snapshot, 61000)
      expect(paused.reading.remainingSeconds).assertEqual(1440)
      const resumed: TimerTransition = FocusTimerEngine.resume(paused.snapshot, 3661000)
      expect(resumed.reading.remainingSeconds).assertEqual(1440)
      expect(resumed.snapshot.accumulatedPausedMs).assertEqual(3600000)
      const observed: TimerTransition = FocusTimerEngine.synchronize(resumed.snapshot, 3671000)
      expect(observed.reading.remainingSeconds).assertEqual(1430)
    })

    it('recoversExpiredProcessSnapshotExactlyOnce', 0, () => {
      const initial: TimerTransition = start(1000)
      const recovered: TimerTransition = FocusTimerEngine.synchronize(initial.snapshot, 1502000)
      expect(recovered.snapshot.state).assertEqual(TimerRunState.COMPLETED)
      expect(recovered.snapshot.completedFocusRounds).assertEqual(1)
      expect(recovered.outcome?.result).assertEqual(FocusResult.COMPLETED)
      expect(recovered.outcome?.focusedSeconds).assertEqual(1500)
      const repeated: TimerTransition = FocusTimerEngine.synchronize(recovered.snapshot, 1600000)
      expect(repeated.outcome).assertEqual(null)
    })

    it('selectsShortAndLongBreakByCompletedRounds', 0, () => {
      let current: TimerTransition = start(0)
      for (let round: number = 1; round <= 4; round++) {
        current = FocusTimerEngine.synchronize(current.snapshot, current.snapshot.deadlineAt)
        expect(current.snapshot.completedFocusRounds).assertEqual(round)
        current = FocusTimerEngine.startNextPhase(current.snapshot, current.snapshot.deadlineAt, `break-${round}`)
        const expectedPhase: FocusPhase = round === 4 ? FocusPhase.LONG_BREAK : FocusPhase.SHORT_BREAK
        expect(current.snapshot.phase).assertEqual(expectedPhase)
        if (round < 4) {
          current = FocusTimerEngine.synchronize(current.snapshot, current.snapshot.deadlineAt)
          current = FocusTimerEngine.startNextPhase(current.snapshot, current.snapshot.deadlineAt, `focus-${round + 1}`)
          expect(current.snapshot.phase).assertEqual(FocusPhase.FOCUS)
        }
      }
    })

    it('handlesCrossMidnightWithoutResettingElapsedTime', 0, () => {
      const beforeMidnight: number = new Date(2026, 7, 28, 23, 59, 30).getTime()
      const initial: TimerTransition = start(beforeMidnight)
      const afterMidnight: TimerTransition = FocusTimerEngine.synchronize(initial.snapshot, beforeMidnight + 90000)
      expect(afterMidnight.reading.elapsedSeconds).assertEqual(90)
      expect(afterMidnight.reading.remainingSeconds).assertEqual(1410)
    })

    it('repairsBackwardClockChangesWithoutAddingTime', 0, () => {
      const initial: TimerTransition = start(100000)
      const observed: TimerTransition = FocusTimerEngine.synchronize(initial.snapshot, 130000)
      expect(observed.reading.remainingSeconds).assertEqual(1470)
      const rolledBack: TimerTransition = FocusTimerEngine.synchronize(observed.snapshot, 70000)
      expect(rolledBack.reading.clockAdjusted).assertTrue()
      expect(rolledBack.reading.remainingSeconds).assertEqual(1470)
      expect(rolledBack.snapshot.deadlineAt).assertEqual(1540000)
    })

    it('recordsEarlyFinishAndAbandonWithoutCompletedRound', 0, () => {
      const initial: TimerTransition = start(1000)
      const early: TimerTransition = FocusTimerEngine.finishEarly(initial.snapshot, 11000)
      expect(early.outcome?.result).assertEqual(FocusResult.INTERRUPTED)
      expect(early.outcome?.focusedSeconds).assertEqual(10)
      expect(early.snapshot.completedFocusRounds).assertEqual(0)
      const earlyBreak: TimerTransition = FocusTimerEngine.startNextPhase(early.snapshot, 11000, 'early-break')
      expect(earlyBreak.snapshot.phase).assertEqual(FocusPhase.SHORT_BREAK)
      const abandoned: TimerTransition = FocusTimerEngine.abandon(initial.snapshot, 21000)
      expect(abandoned.snapshot.state).assertEqual(TimerRunState.ABANDONED)
      expect(abandoned.outcome?.result).assertEqual(FocusResult.ABANDONED)
      expect(abandoned.outcome?.focusedSeconds).assertEqual(20)
    })

    it('rejectsCorruptedPersistedSnapshots', 0, () => {
      const initial: ActiveTimerSnapshot = start(1000).snapshot
      const restored: ActiveTimerSnapshot | null = TimerStateCodec.decodeSnapshot(
        TimerStateCodec.encodeSnapshot(initial))
      expect(restored?.phaseSessionId).assertEqual('session-1')
      expect(TimerStateCodec.decodeSnapshot('{"state":"running"}')).assertEqual(null)
      expect(TimerStateCodec.decodeConfig('{"focusMinutes":0}')).assertEqual(null)
    })

    it('upgradesStoredConfigurationWithSafeAutomationDefaults', 0, () => {
      const restored: TimerConfig | null = TimerStateCodec.decodeConfig(
        '{"focusMinutes":40,"shortBreakMinutes":8,"longBreakMinutes":18,"longBreakEvery":3}')
      expect(restored?.focusMinutes).assertEqual(40)
      expect(restored?.autoStartBreaks).assertFalse()
      expect(restored?.autoStartFocus).assertFalse()
    })

    it('upgradesStoredActiveTimerWithSafeAutomationDefaults', 0, () => {
      const initial: ActiveTimerSnapshot = start(1000).snapshot
      const legacyValue: string = TimerStateCodec.encodeSnapshot(initial)
        .replace(',"autoStartBreaks":false,"autoStartFocus":false', '')
      const restored: ActiveTimerSnapshot | null = TimerStateCodec.decodeSnapshot(legacyValue)
      expect(restored?.phaseSessionId).assertEqual('session-1')
      expect(restored?.config.autoStartBreaks).assertFalse()
      expect(restored?.config.autoStartFocus).assertFalse()
    })
  })
}
