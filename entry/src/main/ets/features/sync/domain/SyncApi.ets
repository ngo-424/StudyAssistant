import { SyncEntityType, SyncOperation } from '../../../domain/model/StudyModels'

export interface PushMutationPayload {
  mutationId: string
  entityType: SyncEntityType
  entityId: string
  baseRevision: number
  operation: SyncOperation
  payload: Object
  updatedAt: number
}

export interface PushSyncBody {
  mutations: PushMutationPayload[]
}

export interface ServerRecordPayload {
  entityType: SyncEntityType
  entityId: string
  revision: number
  operation: SyncOperation
  payload: Object
  updatedAt: number
}

export interface PushMutationResult {
  mutationId: string
  status: string
  revision: number
  serverRecord?: ServerRecordPayload
}

export interface PushSyncResult {
  results: PushMutationResult[]
}

export interface PullChangePayload extends ServerRecordPayload {
  cursor: string
}

export interface PullSyncResult {
  changes: PullChangePayload[]
  nextCursor: string
  hasMore: boolean
}

export interface SyncApi {
  push(accessToken: string, body: PushSyncBody): Promise<PushSyncResult>
  pull(accessToken: string, cursor: string): Promise<PullSyncResult>
}

export class SyncApiError extends Error {
  readonly statusCode: number
  readonly errorCode: string

  constructor(statusCode: number, errorCode: string) {
    super(errorCode)
    this.name = 'SyncApiError'
    this.statusCode = statusCode
    this.errorCode = errorCode
  }
}
