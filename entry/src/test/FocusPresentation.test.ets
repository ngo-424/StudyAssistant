import { describe, expect, it } from '@ohos/hypium'
import { FocusPhase, FocusResult, TimerConfig, TimerRunState } from '../main/ets/domain/model/StudyModels'
import { FocusPresentation } from '../main/ets/features/focus/presentation/FocusPresentation'

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
