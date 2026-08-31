import { http } from '@kit.NetworkKit'
import { AUTH_API_BASE_URL } from '../../auth/infrastructure/AuthEndpoint'
import { ContinuationApi, ContinuationApiError } from '../domain/ContinuationApi'
import {
  ClaimContinuationBody,
  ClaimContinuationResult,
  ContinuationRemoteStatus,
  PrepareContinuationBody,
  PrepareContinuationResult
} from '../domain/ContinuationModels'

interface ContinuationErrorPayload {
  code?: string
}

export class HarmonyContinuationApi implements ContinuationApi {
  private readonly baseUrl: string

  constructor(baseUrl: string = AUTH_API_BASE_URL) {
    this.baseUrl = baseUrl
  }

  prepare(accessToken: string, body: PrepareContinuationBody): Promise<PrepareContinuationResult> {
    return this.request<PrepareContinuationResult>('continuation/prepare', http.RequestMethod.POST,
      JSON.stringify(body), accessToken)
  }

  claim(accessToken: string, body: ClaimContinuationBody): Promise<ClaimContinuationResult> {
    return this.request<ClaimContinuationResult>('continuation/claim', http.RequestMethod.POST,
      JSON.stringify(body), accessToken)
  }

  status(accessToken: string, token: string): Promise<ContinuationRemoteStatus> {
    return this.request<ContinuationRemoteStatus>(
      `continuation/status?token=${encodeURIComponent(token)}`, http.RequestMethod.GET, '', accessToken)
  }

  private async request<T>(path: string, method: http.RequestMethod, body: string,
    accessToken: string): Promise<T> {
    const client: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await client.request(`${this.baseUrl}/${path}`, {
        method: method,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        extraData: body.length > 0 ? body : undefined,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8_000,
        readTimeout: 12_000
      })
      const responseText: string = typeof response.result === 'string' ?
        response.result : JSON.stringify(response.result)
      if (response.responseCode < 200 || response.responseCode >= 300) {
        let errorCode: string = 'CONTINUATION_REQUEST_FAILED'
        try {
          const payload: ContinuationErrorPayload = JSON.parse(responseText) as ContinuationErrorPayload
          errorCode = payload.code ?? errorCode
        } catch (parseError) {
        }
        throw new ContinuationApiError(response.responseCode, errorCode)
      }
      return JSON.parse(responseText) as T
    } catch (error) {
      if (error instanceof ContinuationApiError) {
        throw error
      }
      throw new ContinuationApiError(0, 'NETWORK_UNAVAILABLE')
    } finally {
      client.destroy()
    }
  }
}
