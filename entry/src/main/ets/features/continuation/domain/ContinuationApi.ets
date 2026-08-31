import {
  ClaimContinuationBody,
  ClaimContinuationResult,
  ContinuationRemoteStatus,
  PrepareContinuationBody,
  PrepareContinuationResult
} from './ContinuationModels'

export interface ContinuationApi {
  prepare(accessToken: string, body: PrepareContinuationBody): Promise<PrepareContinuationResult>
  claim(accessToken: string, body: ClaimContinuationBody): Promise<ClaimContinuationResult>
  status(accessToken: string, token: string): Promise<ContinuationRemoteStatus>
}

export class ContinuationApiError extends Error {
  readonly statusCode: number
  readonly errorCode: string

  constructor(statusCode: number, errorCode: string) {
    super(errorCode)
    this.statusCode = statusCode
    this.errorCode = errorCode
  }
}
