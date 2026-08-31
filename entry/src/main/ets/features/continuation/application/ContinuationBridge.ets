import { CONTINUATION_PAYLOAD_KEY } from '../domain/ContinuationModels'

export class ContinuationBridge {
  private static pendingPayload: string = ''

  static receive(parameters: Record<string, Object> | undefined): void {
    if (parameters === undefined) {
      return
    }
    const value: Object | undefined = parameters[CONTINUATION_PAYLOAD_KEY]
    if (value !== undefined && typeof value === 'string') {
      ContinuationBridge.pendingPayload = value
    }
  }

  static pending(): string {
    return ContinuationBridge.pendingPayload
  }

  static clear(): void {
    ContinuationBridge.pendingPayload = ''
  }
}
