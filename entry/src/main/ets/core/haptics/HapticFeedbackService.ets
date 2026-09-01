import { vibrator } from '@kit.SensorServiceKit'

export class HapticFeedbackService {
  static async touch(): Promise<void> {
    await HapticFeedbackService.play(18)
  }

  static async success(): Promise<void> {
    await HapticFeedbackService.play(32)
  }

  private static async play(duration: number): Promise<void> {
    try {
      await vibrator.startVibration({ type: 'time', duration: duration }, { id: 0, usage: 'touch' })
    } catch (_) {
      // Devices without a vibrator keep the action fully usable.
    }
  }
}
