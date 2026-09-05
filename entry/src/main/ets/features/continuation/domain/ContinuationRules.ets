import { TimerRunState } from '../../../domain/model/StudyModels'
import { TimerStateCodec } from '../../../data/repository/TimerStateCodec'
import {
  CONTINUATION_APP_VERSION_CODE,
  CONTINUATION_MAX_PAYLOAD_BYTES,
  CONTINUATION_PREVIOUS_APP_VERSION_CODE,
  CONTINUATION_PROTOCOL_VERSION,
  ContinuationEnvelope
} from './ContinuationModels'

export class ContinuationRules {
  static encode(envelope: ContinuationEnvelope): string {
    if (!ContinuationRules.valid(envelope)) {
      throw new Error('CONTINUATION_PAYLOAD_INVALID')
    }
    const payload: string = JSON.stringify(envelope)
    if (payload.length * 3 > CONTINUATION_MAX_PAYLOAD_BYTES) {
      throw new Error('CONTINUATION_PAYLOAD_TOO_LARGE')
    }
    return payload
  }

  static decode(payload: string): ContinuationEnvelope | null {
    if (payload.length === 0 || payload.length * 3 > CONTINUATION_MAX_PAYLOAD_BYTES) {
      return null
    }
    try {
      const envelope: ContinuationEnvelope = JSON.parse(payload) as ContinuationEnvelope
      return ContinuationRules.valid(envelope) ? envelope : null
    } catch (error) {
      return null
    }
  }

  static compatibleTargetVersion(value: Object | undefined): boolean {
    if (value === undefined || value === null) {
      return false
    }
    const text: string = `${value}`
    return text === `${CONTINUATION_APP_VERSION_CODE}` || text === `${CONTINUATION_PREVIOUS_APP_VERSION_CODE}` ||
      text === '1.1.1' || text === '1.1.0' || text === '1.0.0'
  }

  static valid(envelope: ContinuationEnvelope): boolean {
    if (envelope === null || envelope.protocolVersion !== CONTINUATION_PROTOCOL_VERSION ||
      !ContinuationRules.compatibleEnvelopeVersion(envelope.appVersionCode) || envelope.accountId.length === 0 ||
      envelope.sourceDeviceId.length === 0 || envelope.token.length < 32 ||
      !Number.isFinite(envelope.preparedAt) || !Number.isFinite(envelope.expiresAt) ||
      envelope.expiresAt <= envelope.preparedAt) {
      return false
    }
    const snapshot = TimerStateCodec.decodeSnapshot(JSON.stringify(envelope.snapshot))
    return snapshot !== null && snapshot.profileId === `account:${envelope.accountId}` &&
      (snapshot.state === TimerRunState.RUNNING || snapshot.state === TimerRunState.PAUSED)
  }

  private static compatibleEnvelopeVersion(value: number): boolean {
    return value === CONTINUATION_APP_VERSION_CODE || value === CONTINUATION_PREVIOUS_APP_VERSION_CODE
  }
}
