import { common } from '@kit.AbilityKit'
import { notificationManager } from '@kit.NotificationKit'
import { ActiveTimerSnapshot } from '../../../domain/model/StudyModels'
import { TimerReading } from '../domain/TimerModels'
import { FocusPresentation } from '../presentation/FocusPresentation'
import { FocusSystemDescriptor } from '../system/FocusSystemModels'
import { FocusSystemPolicy } from '../system/FocusSystemPolicy'

export class HarmonyNotificationGateway {
  async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled()
    } catch (error) {
      return false
    }
  }

  async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (await this.isEnabled()) {
      return true
    }
    try {
      await notificationManager.requestEnableNotification(context)
      return await this.isEnabled()
    } catch (error) {
      return false
    }
  }

  async publish(notificationId: number, snapshot: ActiveTimerSnapshot, reading: TimerReading,
    descriptor: FocusSystemDescriptor): Promise<void> {
    const taskText: string = descriptor.taskTitle.length > 0 ? '已关联任务' : '自由专注'
    const request: notificationManager.NotificationRequest = {
      id: notificationId,
      notificationSlotType: notificationManager.SlotType.CONTENT_INFORMATION,
      isAlertOnce: true,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: FocusSystemPolicy.phaseTitle(snapshot.phase),
          text: `${taskText} · 剩余 ${FocusPresentation.formatSeconds(reading.remainingSeconds)}`,
          additionalText: snapshot.state === 'paused' ? '计时已暂停' : '点击应用查看计时详情'
        }
      }
    }
    await notificationManager.publish(request)
  }

  async cancel(notificationId: number): Promise<void> {
    try {
      await notificationManager.cancel(notificationId)
    } catch (error) {
      // The fallback notification may already have been cleared by the user or system.
    }
  }
}
