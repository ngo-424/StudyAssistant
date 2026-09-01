import { http } from '@kit.NetworkKit'
import { AuthApi, AuthApiError } from '../domain/AuthApi'
import {
  AuthErrorPayload,
  AuthSessionPayload,
  RequestCodeResult
} from '../domain/AuthModels'
import { AUTH_API_BASE_URL, AUTH_API_CONFIGURED } from './AuthEndpoint'

interface EmailDeviceBody {
  email: string
  deviceId: string
}

interface VerifyCodeBody extends EmailDeviceBody {
  code: string
}

interface RefreshBody {
  refreshToken: string
  deviceId: string
}

interface LogoutBody {
  refreshToken: string
}

export class HarmonyAuthApi implements AuthApi {
  private readonly baseUrl: string

  constructor(baseUrl: string = AUTH_API_BASE_URL) {
    this.baseUrl = baseUrl
  }

  requestCode(email: string, deviceId: string): Promise<RequestCodeResult> {
    const body: EmailDeviceBody = { email: email, deviceId: deviceId }
    return this.request<RequestCodeResult>('auth/code/request', http.RequestMethod.POST, JSON.stringify(body))
  }

  verifyCode(email: string, code: string, deviceId: string): Promise<AuthSessionPayload> {
    const body: VerifyCodeBody = { email: email, code: code, deviceId: deviceId }
    return this.request<AuthSessionPayload>('auth/code/verify', http.RequestMethod.POST, JSON.stringify(body))
  }

  refresh(refreshToken: string, deviceId: string): Promise<AuthSessionPayload> {
    const body: RefreshBody = { refreshToken: refreshToken, deviceId: deviceId }
    return this.request<AuthSessionPayload>('auth/refresh', http.RequestMethod.POST, JSON.stringify(body))
  }

  async logout(refreshToken: string): Promise<void> {
    const body: LogoutBody = { refreshToken: refreshToken }
    await this.request<Object>('auth/logout', http.RequestMethod.POST, JSON.stringify(body))
  }

  async deleteAccount(accessToken: string): Promise<void> {
    await this.request<Object>('account', http.RequestMethod.DELETE, '', accessToken)
  }

  private async request<T>(path: string, method: http.RequestMethod, body: string,
    accessToken: string = ''): Promise<T> {
    if (!AUTH_API_CONFIGURED && this.baseUrl === AUTH_API_BASE_URL) {
      throw new AuthApiError(503, 'SERVICE_NOT_CONFIGURED')
    }
    const client: http.HttpRequest = http.createHttp()
    const headers: Record<string, string> = { 'Content-Type': 'application/json' }
    if (accessToken.length > 0) {
      headers['Authorization'] = `Bearer ${accessToken}`
    }
    try {
      const response: http.HttpResponse = await client.request(`${this.baseUrl}/${path}`, {
        method: method,
        header: headers,
        extraData: body.length > 0 ? body : undefined,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10_000,
        readTimeout: 15_000
      })
      const responseText: string = typeof response.result === 'string' ?
        response.result : JSON.stringify(response.result)
      if (response.responseCode < 200 || response.responseCode >= 300) {
        let errorCode: string = 'AUTH_REQUEST_FAILED'
        try {
          const payload: AuthErrorPayload = JSON.parse(responseText) as AuthErrorPayload
          errorCode = payload.code ?? errorCode
        } catch (parseError) {
        }
        throw new AuthApiError(response.responseCode, errorCode)
      }
      return JSON.parse(responseText) as T
    } catch (error) {
      if (error instanceof AuthApiError) {
        throw error
      }
      throw new AuthApiError(0, 'NETWORK_UNAVAILABLE')
    } finally {
      client.destroy()
    }
  }
}
