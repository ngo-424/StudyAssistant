import { http } from '@kit.NetworkKit'
import { AUTH_API_BASE_URL } from '../../auth/infrastructure/AuthEndpoint'
import {
  PullSyncResult,
  PushSyncBody,
  PushSyncResult,
  SyncApi,
  SyncApiError
} from '../domain/SyncApi'

interface SyncErrorPayload {
  code?: string
}

export class HarmonySyncApi implements SyncApi {
  private readonly baseUrl: string

  constructor(baseUrl: string = AUTH_API_BASE_URL) {
    this.baseUrl = baseUrl
  }

  push(accessToken: string, body: PushSyncBody): Promise<PushSyncResult> {
    return this.request<PushSyncResult>('sync/push', http.RequestMethod.POST,
      JSON.stringify(body), accessToken)
  }

  pull(accessToken: string, cursor: string): Promise<PullSyncResult> {
    return this.request<PullSyncResult>(`sync/pull?cursor=${encodeURIComponent(cursor)}&limit=200`,
      http.RequestMethod.GET, '', accessToken)
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
        connectTimeout: 10_000,
        readTimeout: 20_000
      })
      const responseText: string = typeof response.result === 'string' ?
        response.result : JSON.stringify(response.result)
      if (response.responseCode < 200 || response.responseCode >= 300) {
        let errorCode: string = 'SYNC_REQUEST_FAILED'
        try {
          const payload: SyncErrorPayload = JSON.parse(responseText) as SyncErrorPayload
          errorCode = payload.code ?? errorCode
        } catch (parseError) {
        }
        throw new SyncApiError(response.responseCode, errorCode)
      }
      return JSON.parse(responseText) as T
    } catch (error) {
      if (error instanceof SyncApiError) {
        throw error
      }
      throw new SyncApiError(0, 'NETWORK_UNAVAILABLE')
    } finally {
      client.destroy()
    }
  }
}
