import { FocusPhase, FocusResult, TimerConfig, TimerRunState } from '../../../domain/model/StudyModels'

export class FocusPresentation {
  static isImmersive(state: TimerRunState | null): boolean {
    return state !== null && state !== TimerRunState.IDLE
  }

  static isActive(state: TimerRunState | null): boolean {
    return state === TimerRunState.RUNNING || state === TimerRunState.PAUSED
  }

  static showImmersiveDetails(height: number): boolean {
    return height >= 400
  }

  static immersiveLabel(state: TimerRunState, phase: FocusPhase, result: FocusResult | null): string {
    if (state === TimerRunState.PAUSED) {
      return phase === FocusPhase.FOCUS ? '专注已暂停' : '休息已暂停'
    }
    if (state === TimerRunState.COMPLETED && result === FocusResult.INTERRUPTED) {
      return '本阶段已提前结束'
    }
    return FocusPresentation.statusLabel(state, phase)
  }

  static formatSeconds(totalSeconds: number): string {
    const safeSeconds: number = Math.max(0, Math.round(totalSeconds))
    const minutes: number = Math.floor(safeSeconds / 60)
    const seconds: number = safeSeconds % 60
    return `${FocusPresentation.pad(minutes)}:${FocusPresentation.pad(seconds)}`
  }

  static phaseLabel(phase: FocusPhase): string {
    if (phase === FocusPhase.SHORT_BREAK) {
      return '短休息'
    }
    if (phase === FocusPhase.LONG_BREAK) {
      return '长休息'
    }
    return '专注中'
  }

  static statusLabel(state: TimerRunState, phase: FocusPhase): string {
    if (state === TimerRunState.PAUSED) {
      return '已暂停'
    }
    if (state === TimerRunState.COMPLETED) {
      return phase === FocusPhase.FOCUS ? '本轮专注已完成' : '休息结束'
    }
    if (state === TimerRunState.ABANDONED) {
      return '本轮已放弃'
    }
    return FocusPresentation.phaseLabel(phase)
  }

  static shouldAutoStart(state: TimerRunState, result: FocusResult | null,
    phase: FocusPhase, config: TimerConfig): boolean {
    if (state !== TimerRunState.COMPLETED || result !== FocusResult.COMPLETED) {
      return false
    }
    return phase === FocusPhase.FOCUS ? config.autoStartBreaks : config.autoStartFocus
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }
}
