import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import { ActiveTimerSnapshot } from '../../../domain/model/StudyModels'
import { TimerReading } from '../domain/TimerModels'
import { FocusSystemDescriptor } from '../system/FocusSystemModels'
import { FocusSystemPolicy } from '../system/FocusSystemPolicy'

const BUNDLE_NAME: string = 'com.example.studyassistant'
const ABILITY_NAME: string = 'EntryAbility'

export class HarmonyReminderGateway {
  async schedule(notificationId: number, snapshot: ActiveTimerSnapshot, reading: TimerReading,
    descriptor: FocusSystemDescriptor): Promise<number> {
    const taskText: string = descriptor.taskTitle.length > 0 ? '已关联任务' : '自由专注'
    const request: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: Math.max(1, reading.remainingSeconds),
      title: FocusSystemPolicy.phaseTitle(snapshot.phase),
      content: `${taskText}正在计时`,
      expiredContent: FocusSystemPolicy.completionText(snapshot.phase),
      notificationId: notificationId,
      groupId: 'studyassistant-focus-timer',
      slotType: notificationManager.SlotType.CONTENT_INFORMATION,
      ringDuration: 1,
      ringChannel: reminderAgentManager.RingChannel.RING_CHANNEL_NOTIFICATION,
      tapDismissed: true,
      wantAgent: {
        pkgName: BUNDLE_NAME,
        abilityName: ABILITY_NAME,
        parameters: { 'focusFlowId': snapshot.flowId }
      }
    }
    return reminderAgentManager.publishReminder(request)
  }

  async cancel(reminderId: number): Promise<void> {
    try {
      await reminderAgentManager.cancelReminder(reminderId)
    } catch (error) {
      // An expired or already removed reminder does not need further cleanup.
    }
  }
}
