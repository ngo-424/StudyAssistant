import { FocusPhase } from '../../../domain/model/StudyModels'
import { CapabilityState, FocusSystemStatus } from './FocusSystemModels'

export class FocusSystemPolicy {
  static readonly TIMER_EVENT: string = 'TIMER'

  static stableId(value: string, salt: number): number {
    let hash: number = 2166136261 ^ salt
    for (let index: number = 0; index < value.length; index++) {
      hash = Math.imul(hash ^ value.charCodeAt(index), 16777619)
    }
    return Math.abs(hash % 2000000000) + 1
  }

  static phaseTitle(phase: FocusPhase): string {
    if (phase === FocusPhase.SHORT_BREAK) {
      return '短休息进行中'
    }
    if (phase === FocusPhase.LONG_BREAK) {
      return '长休息进行中'
    }
    return '专注进行中'
  }

  static completionText(phase: FocusPhase): string {
    return phase === FocusPhase.FOCUS ? '本轮专注已完成' : '休息结束，可以开始下一轮'
  }

  static shouldPublishFallback(status: FocusSystemStatus): boolean {
    return status.notification === CapabilityState.READY &&
      (status.reminder !== CapabilityState.READY || status.liveView !== CapabilityState.READY)
  }

  static summary(status: FocusSystemStatus): string {
    if (status.notification === CapabilityState.DENIED) {
      return '通知未开启，将继续使用应用内计时'
    }
    if (status.reminder === CapabilityState.READY && status.liveView === CapabilityState.READY) {
      return '后台结束提醒与实况窗均已启用'
    }
    if (status.fallbackNotification) {
      return '部分系统能力不可用，已使用普通通知'
    }
    if (status.notification === CapabilityState.READY) {
      return '通知已允许，系统计时能力将在开始后检测'
    }
    return '应用内计时可用，可按需开启系统提醒'
  }
}
