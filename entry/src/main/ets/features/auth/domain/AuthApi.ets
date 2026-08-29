import { AuthSessionPayload, RequestCodeResult } from './AuthModels'

export interface AuthApi {
  requestCode(email: string, deviceId: string): Promise<RequestCodeResult>
  verifyCode(email: string, code: string, deviceId: string): Promise<AuthSessionPayload>
  refresh(refreshToken: string, deviceId: string): Promise<AuthSessionPayload>
  logout(refreshToken: string): Promise<void>
  deleteAccount(accessToken: string): Promise<void>
}

export class AuthApiError extends Error {
  readonly statusCode: number
  readonly errorCode: string

  constructor(statusCode: number, errorCode: string) {
    super(errorCode)
    this.name = 'AuthApiError'
    this.statusCode = statusCode
    this.errorCode = errorCode
  }
}
