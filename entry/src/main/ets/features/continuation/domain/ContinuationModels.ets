import { ActiveTimerSnapshot } from '../../../domain/model/StudyModels'

export const CONTINUATION_PROTOCOL_VERSION: number = 1
export const CONTINUATION_APP_VERSION_CODE: number = 1000000
export const CONTINUATION_PAYLOAD_KEY: string = 'studyAssistantContinuationV1'
export const CONTINUATION_MAX_PAYLOAD_BYTES: number = 96 * 1024

export enum ContinuationControlState {
  IDLE = 'idle',
  GUEST = 'guest',
  READY = 'ready',
  TRANSFER_PENDING = 'transfer_pending',
  TRANSFERRED = 'transferred',
  TARGET_CONTROL = 'target_control',
  OFFLINE = 'offline',
  FAILED = 'failed'
}

export interface ContinuationEnvelope {
  protocolVersion: number
  appVersionCode: number
  accountId: string
  sourceDeviceId: string
  token: string
  preparedAt: number
  expiresAt: number
  snapshot: ActiveTimerSnapshot
}

export interface ContinuationControlRecord {
  flowId: string
  phaseSessionId: string
  token: string
  state: ContinuationControlState
  expiresAt: number
  lastPolledAt: number
  errorCode: string
  updatedAt: number
}

export interface ContinuationStatus {
  state: ContinuationControlState
  message: string
  canRetry: boolean
  isController: boolean
}

export interface PrepareContinuationBody {
  token: string
  flowId: string
  phaseSessionId: string
  sourceDeviceId: string
  sourceVersion: number
}

export interface PrepareContinuationResult {
  expiresAt: string
}

export interface ClaimContinuationBody {
  token: string
  flowId: string
  phaseSessionId: string
  targetDeviceId: string
  targetVersion: number
}

export interface ClaimContinuationResult {
  accepted: boolean
  alreadyClaimed: boolean
  claimedAt: string
}

export interface ContinuationRemoteStatus {
  status: string
  claimedAt: string | null
}
