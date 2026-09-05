import { describe, expect, it } from '@ohos/hypium'
import { FocusPhase, FocusResult, TimerConfig, TimerRunState } from '../main/ets/domain/model/StudyModels'
import { FocusPresentation } from '../main/ets/features/focus/presentation/FocusPresentation'
import { FocusOperationQueue } from '../main/ets/features/focus/presentation/FocusOperationQueue'

function config(autoBreaks: boolean, autoFocus: boolean): TimerConfig {
  return {
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    longBreakEvery: 4,
    autoStartBreaks: autoBreaks,
    autoStartFocus: autoFocus
  }
}

export default function focusPresentationTest(): void {
  describe('focusPresentation', () => {
    it('keepsNavigationHiddenUntilTheSessionIsDismissed', 0, () => {
      expect(FocusPresentation.isImmersive(null)).assertFalse()
      expect(FocusPresentation.isImmersive(TimerRunState.IDLE)).assertFalse()
      expect(FocusPresentation.isImmersive(TimerRunState.RUNNING)).assertTrue()
      expect(FocusPresentation.isImmersive(TimerRunState.PAUSED)).assertTrue()
      expect(FocusPresentation.isImmersive(TimerRunState.COMPLETED)).assertTrue()
      expect(FocusPresentation.isImmersive(TimerRunState.ABANDONED)).assertTrue()
      expect(FocusPresentation.isActive(TimerRunState.RUNNING)).assertTrue()
      expect(FocusPresentation.isActive(TimerRunState.PAUSED)).assertTrue()
      expect(FocusPresentation.isActive(TimerRunState.COMPLETED)).assertFalse()
      expect(FocusPresentation.isActive(TimerRunState.ABANDONED)).assertFalse()
    })

    it('simplifiesSmallWindowsAndDistinguishesInterruptedResults', 0, () => {
      expect(FocusPresentation.showImmersiveDetails(399)).assertFalse()
      expect(FocusPresentation.showImmersiveDetails(400)).assertTrue()
      expect(FocusPresentation.immersiveLabel(TimerRunState.PAUSED, FocusPhase.SHORT_BREAK, null))
        .assertEqual('休息已暂停')
      expect(FocusPresentation.immersiveLabel(TimerRunState.COMPLETED, FocusPhase.FOCUS, FocusResult.INTERRUPTED))
        .assertEqual('本阶段已提前结束')
    })

    it('finishesAnInflightRestoreBeforeApplyingPause', 0, async () => {
      const queue: FocusOperationQueue = new FocusOperationQueue()
      let release: () => void = () => {}
      const barrier: Promise<void> = new Promise<void>((resolve) => { release = resolve })
      let state: string = 'initial'
      const restore: Promise<void> = queue.run(async () => {
        await barrier
        state = 'running'
      })
      const pause: Promise<void> = queue.run(async () => {
        expect(state).assertEqual('running')
        state = 'paused'
      })
      await Promise.resolve()
      expect(state).assertEqual('initial')
      release()
      await restore
      await pause
      expect(state).assertEqual('paused')
    })

    it('continuesProcessingCommandsAfterAnOperationFails', 0, async () => {
      const queue: FocusOperationQueue = new FocusOperationQueue()
      const failed: Promise<void> = queue.run(async () => { throw new Error('restore failed') })
      const next: Promise<string> = queue.run(async () => 'resumed')
      let rejected: boolean = false
      try {
        await failed
      } catch (error) {
        rejected = true
      }
      expect(rejected).assertTrue()
      expect(await next).assertEqual('resumed')
    })

    it('formatsTimerWithoutNegativeValues', 0, () => {
      expect(FocusPresentation.formatSeconds(1500)).assertEqual('25:00')
      expect(FocusPresentation.formatSeconds(61)).assertEqual('01:01')
      expect(FocusPresentation.formatSeconds(-2)).assertEqual('00:00')
    })

    it('onlyAutoStartsNormallyCompletedEnabledPhases', 0, () => {
      expect(FocusPresentation.shouldAutoStart(
        TimerRunState.COMPLETED, FocusResult.COMPLETED, FocusPhase.FOCUS, config(true, false))).assertTrue()
      expect(FocusPresentation.shouldAutoStart(
        TimerRunState.COMPLETED, FocusResult.COMPLETED, FocusPhase.SHORT_BREAK, config(true, false))).assertFalse()
      expect(FocusPresentation.shouldAutoStart(
        TimerRunState.COMPLETED, FocusResult.INTERRUPTED, FocusPhase.FOCUS, config(true, true))).assertFalse()
      expect(FocusPresentation.shouldAutoStart(
        TimerRunState.RUNNING, null, FocusPhase.FOCUS, config(true, true))).assertFalse()
    })

    it('describesEveryTimerPhaseAndTerminalState', 0, () => {
      expect(FocusPresentation.phaseLabel(FocusPhase.FOCUS)).assertEqual('专注中')
      expect(FocusPresentation.phaseLabel(FocusPhase.SHORT_BREAK)).assertEqual('短休息')
      expect(FocusPresentation.phaseLabel(FocusPhase.LONG_BREAK)).assertEqual('长休息')
      expect(FocusPresentation.statusLabel(TimerRunState.PAUSED, FocusPhase.FOCUS)).assertEqual('已暂停')
      expect(FocusPresentation.statusLabel(TimerRunState.COMPLETED, FocusPhase.FOCUS))
        .assertEqual('本轮专注已完成')
      expect(FocusPresentation.statusLabel(TimerRunState.COMPLETED, FocusPhase.SHORT_BREAK))
        .assertEqual('休息结束')
      expect(FocusPresentation.statusLabel(TimerRunState.ABANDONED, FocusPhase.FOCUS)).assertEqual('本轮已放弃')
    })
  })
}
