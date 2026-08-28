import { BusinessError } from '@kit.BasicServicesKit'
import { liveViewManager } from '@kit.LiveViewKit'
import { ActiveTimerSnapshot, TimerRunState } from '../../../domain/model/StudyModels'
import { TimerReading } from '../domain/TimerModels'
import { FocusPresentation } from '../presentation/FocusPresentation'
import { FocusSystemDescriptor } from '../system/FocusSystemModels'
import { FocusSystemPolicy } from '../system/FocusSystemPolicy'

const LIVE_VIEW_ALREADY_EXISTS: number = 1003500006

export class HarmonyLiveViewGateway {
  private sequence: number = 0

  async isEnabled(): Promise<boolean> {
    try {
      return await liveViewManager.isLiveViewEnabled()
    } catch (error) {
      return false
    }
  }

  async startOrUpdate(liveViewId: number, snapshot: ActiveTimerSnapshot, reading: TimerReading,
    descriptor: FocusSystemDescriptor): Promise<void> {
    const liveView: liveViewManager.LiveView = this.createLiveView(liveViewId, snapshot, reading, descriptor)
    try {
      await liveViewManager.startLiveView(liveView)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      if (businessError.code !== LIVE_VIEW_ALREADY_EXISTS) {
        throw new Error(`LIVE_VIEW_START_FAILED_${businessError.code}`)
      }
      await liveViewManager.updateLiveView(liveView)
    }
  }

  async stop(liveViewId: number): Promise<void> {
    try {
      const liveView: liveViewManager.LiveView = await liveViewManager.getActiveLiveView(liveViewId)
      liveView.sequence = this.nextSequence()
      liveView.liveViewData.primary.keepTime = 0
      await liveViewManager.stopLiveView(liveView)
    } catch (error) {
      // Live View is optional and may already have ended or be unavailable.
    }
  }

  private createLiveView(liveViewId: number, snapshot: ActiveTimerSnapshot, reading: TimerReading,
    descriptor: FocusSystemDescriptor): liveViewManager.LiveView {
    const taskText: string = descriptor.taskTitle.length > 0 ? '已关联任务' : '自由专注'
    const targetTime: number = Date.now() + reading.remainingSeconds * 1000
    const paused: boolean = snapshot.state === TimerRunState.PAUSED
    return {
      id: liveViewId,
      event: FocusSystemPolicy.TIMER_EVENT,
      sequence: this.nextSequence(),
      isMute: true,
      lifeCycleMode: liveViewManager.LifeCycleMode.STOP_BY_APP,
      timer: {
        time: targetTime,
        isCountdown: true,
        isPaused: paused,
        countdownPreset: {
          presetTitle: FocusSystemPolicy.phaseTitle(snapshot.phase),
          presetContent: taskText
        },
        capsuleCountdownPreset: {
          presetTitle: FocusSystemPolicy.phaseTitle(snapshot.phase),
          presetContent: taskText
        }
      },
      liveViewData: {
        primary: {
          title: FocusSystemPolicy.phaseTitle(snapshot.phase),
          content: [{ text: `${taskText} · ${FocusPresentation.formatSeconds(reading.remainingSeconds)}` }],
          extensionData: {
            text: paused ? '已暂停' : '专注计时进行中',
            type: liveViewManager.ExtensionType.EXTENSION_TYPE_COMMON_TEXT
          },
          aliveTime: Math.min(snapshot.plannedSeconds, 8 * 60 * 60)
        },
        capsule: {
          type: liveViewManager.CapsuleType.CAPSULE_TYPE_TIMER,
          status: paused ? 2 : 1,
          content: taskText,
          time: targetTime,
          isCountdown: true,
          isPaused: paused,
          backgroundColor: this.argb(descriptor.colorSeed)
        }
      }
    }
  }

  private argb(color: string): string {
    return /^#[0-9A-Fa-f]{6}$/.test(color) ? `#FF${color.substring(1)}` : '#FF778291'
  }

  private nextSequence(): number {
    this.sequence = Math.max(Date.now(), this.sequence + 1)
    return this.sequence
  }
}
