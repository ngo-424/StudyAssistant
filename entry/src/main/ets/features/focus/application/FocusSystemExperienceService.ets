import { common } from '@kit.AbilityKit'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { TimerRunState } from '../../../domain/model/StudyModels'
import { HarmonyLiveViewGateway } from '../infrastructure/HarmonyLiveViewGateway'
import { HarmonyNotificationGateway } from '../infrastructure/HarmonyNotificationGateway'
import { HarmonyReminderGateway } from '../infrastructure/HarmonyReminderGateway'
import { SystemExperienceStore } from '../infrastructure/SystemExperienceStore'
import { TimerRuntimeState } from '../domain/TimerModels'
import {
  CapabilityState,
  FocusSystemDescriptor,
  FocusSystemMetadata,
  FocusSystemStatus,
  FocusSystemStatusFactory
} from '../system/FocusSystemModels'
import { FocusSystemPolicy } from '../system/FocusSystemPolicy'
import { ProfileContext } from '../../sync/application/ProfileContext'

export class FocusSystemExperienceService {
  private readonly notifications: HarmonyNotificationGateway
  private readonly reminders: HarmonyReminderGateway
  private readonly liveViews: HarmonyLiveViewGateway
  private readonly store: SystemExperienceStore
  private status: FocusSystemStatus = FocusSystemStatusFactory.idle()

  constructor(notifications: HarmonyNotificationGateway, reminders: HarmonyReminderGateway,
    liveViews: HarmonyLiveViewGateway, store: SystemExperienceStore) {
    this.notifications = notifications
    this.reminders = reminders
    this.liveViews = liveViews
    this.store = store
  }

  static guest(): FocusSystemExperienceService {
    return new FocusSystemExperienceService(
      new HarmonyNotificationGateway(), new HarmonyReminderGateway(), new HarmonyLiveViewGateway(),
      new SystemExperienceStore(RepositoryRegistry.settings(), ProfileContext.currentProfileId()))
  }

  currentStatus(): FocusSystemStatus {
    return this.status
  }

  async requestNotificationPermission(context: common.UIAbilityContext): Promise<FocusSystemStatus> {
    const enabled: boolean = await this.notifications.requestPermission(context)
    this.status = {
      notification: enabled ? CapabilityState.READY : CapabilityState.DENIED,
      reminder: enabled ? CapabilityState.UNKNOWN : CapabilityState.DENIED,
      liveView: this.status.liveView,
      fallbackNotification: false
    }
    return this.status
  }

  async synchronize(runtime: TimerRuntimeState, descriptor: FocusSystemDescriptor): Promise<FocusSystemStatus> {
    if (runtime.snapshot === null || runtime.reading === null) {
      this.status = FocusSystemStatusFactory.idle()
      return this.status
    }
    if (runtime.snapshot.state === TimerRunState.COMPLETED ||
      runtime.snapshot.state === TimerRunState.ABANDONED) {
      return this.stop(runtime.snapshot.flowId)
    }

    const notificationReady: boolean = await this.notifications.isEnabled()
    let metadata: FocusSystemMetadata | null = await this.store.load()
    if (metadata !== null && metadata.flowId !== runtime.snapshot.flowId) {
      await this.cleanup(metadata)
      metadata = null
    }
    if (metadata === null) {
      metadata = this.createMetadata(runtime.snapshot.flowId)
    }

    let liveViewState: CapabilityState = CapabilityState.UNAVAILABLE
    if (await this.liveViews.isEnabled()) {
      try {
        await this.liveViews.startOrUpdate(metadata.liveViewId, runtime.snapshot, runtime.reading, descriptor)
        liveViewState = CapabilityState.READY
      } catch (error) {
        liveViewState = CapabilityState.UNAVAILABLE
      }
    }

    let reminderState: CapabilityState = notificationReady ? CapabilityState.UNAVAILABLE : CapabilityState.DENIED
    if (runtime.snapshot.state === TimerRunState.RUNNING && notificationReady) {
      if (metadata.reminderId !== null) {
        reminderState = CapabilityState.READY
      } else {
        try {
          metadata.reminderId = await this.reminders.schedule(
            metadata.notificationId, runtime.snapshot, runtime.reading, descriptor)
          reminderState = CapabilityState.READY
        } catch (error) {
          reminderState = CapabilityState.UNAVAILABLE
        }
      }
    } else if (runtime.snapshot.state === TimerRunState.PAUSED && metadata.reminderId !== null) {
      await this.reminders.cancel(metadata.reminderId)
      metadata.reminderId = null
      reminderState = CapabilityState.READY
    }

    this.status = {
      notification: notificationReady ? CapabilityState.READY : CapabilityState.DENIED,
      reminder: reminderState,
      liveView: liveViewState,
      fallbackNotification: false
    }
    this.status.fallbackNotification = FocusSystemPolicy.shouldPublishFallback(this.status)
    if (this.status.fallbackNotification) {
      try {
        await this.notifications.publish(metadata.notificationId, runtime.snapshot, runtime.reading, descriptor)
      } catch (error) {
        this.status.fallbackNotification = false
      }
    } else {
      await this.notifications.cancel(metadata.notificationId)
    }

    metadata.updatedAt = Date.now()
    await this.store.save(metadata)
    return this.status
  }

  async stop(flowId: string): Promise<FocusSystemStatus> {
    const metadata: FocusSystemMetadata | null = await this.store.load()
    if (metadata !== null && metadata.flowId === flowId) {
      await this.cleanup(metadata)
      await this.store.clear()
    } else {
      await this.liveViews.stop(FocusSystemPolicy.stableId(flowId, 41))
    }
    const notificationReady: boolean = await this.notifications.isEnabled()
    this.status = {
      notification: notificationReady ? CapabilityState.READY : CapabilityState.DENIED,
      reminder: CapabilityState.UNKNOWN,
      liveView: CapabilityState.UNKNOWN,
      fallbackNotification: false
    }
    return this.status
  }

  private createMetadata(flowId: string): FocusSystemMetadata {
    return {
      flowId: flowId,
      reminderId: null,
      notificationId: FocusSystemPolicy.stableId(flowId, 17),
      liveViewId: FocusSystemPolicy.stableId(flowId, 41),
      updatedAt: Date.now()
    }
  }

  private async cleanup(metadata: FocusSystemMetadata): Promise<void> {
    if (metadata.reminderId !== null) {
      await this.reminders.cancel(metadata.reminderId)
    }
    await this.liveViews.stop(metadata.liveViewId)
    await this.notifications.cancel(metadata.notificationId)
  }
}
