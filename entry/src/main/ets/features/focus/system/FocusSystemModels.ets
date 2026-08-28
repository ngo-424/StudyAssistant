export enum CapabilityState {
  UNKNOWN = 'unknown',
  READY = 'ready',
  DENIED = 'denied',
  UNAVAILABLE = 'unavailable'
}

export interface FocusSystemStatus {
  notification: CapabilityState
  reminder: CapabilityState
  liveView: CapabilityState
  fallbackNotification: boolean
}

export interface FocusSystemMetadata {
  flowId: string
  reminderId: number | null
  notificationId: number
  liveViewId: number
  updatedAt: number
}

export interface FocusSystemDescriptor {
  taskTitle: string
  colorSeed: string
}

export class FocusSystemStatusFactory {
  static idle(): FocusSystemStatus {
    return {
      notification: CapabilityState.UNKNOWN,
      reminder: CapabilityState.UNKNOWN,
      liveView: CapabilityState.UNKNOWN,
      fallbackNotification: false
    }
  }
}
