import { AppError, AppErrorCode } from '../../../core/error/AppError'
import { TimerConfig } from '../../../domain/model/StudyModels'

export class TimerConfigRules {
  static defaults(): TimerConfig {
    return {
      focusMinutes: 25,
      shortBreakMinutes: 5,
      longBreakMinutes: 15,
      longBreakEvery: 4
    }
  }

  static validate(config: TimerConfig): TimerConfig {
    if (!TimerConfigRules.integerBetween(config.focusMinutes, 1, 480)) {
      throw new AppError(AppErrorCode.VALIDATION, 'FOCUS_DURATION_INVALID')
    }
    if (!TimerConfigRules.integerBetween(config.shortBreakMinutes, 1, 120)) {
      throw new AppError(AppErrorCode.VALIDATION, 'SHORT_BREAK_DURATION_INVALID')
    }
    if (!TimerConfigRules.integerBetween(config.longBreakMinutes, 1, 180)) {
      throw new AppError(AppErrorCode.VALIDATION, 'LONG_BREAK_DURATION_INVALID')
    }
    if (!TimerConfigRules.integerBetween(config.longBreakEvery, 2, 12)) {
      throw new AppError(AppErrorCode.VALIDATION, 'LONG_BREAK_ROUNDS_INVALID')
    }
    return {
      focusMinutes: config.focusMinutes,
      shortBreakMinutes: config.shortBreakMinutes,
      longBreakMinutes: config.longBreakMinutes,
      longBreakEvery: config.longBreakEvery
    }
  }

  private static integerBetween(value: number, minimum: number, maximum: number): boolean {
    return Number.isFinite(value) && Math.round(value) === value && value >= minimum && value <= maximum
  }
}
