export interface AccountSession {
  accountId: string
  email: string
  accessToken: string
  refreshToken: string
  accessExpiresAt: number
  refreshExpiresAt: number
  deviceId: string
  updatedAt: number
}

export interface RequestCodeResult {
  accepted: boolean
  expiresInSeconds: number
}

export interface AuthAccountPayload {
  id: string
  email: string
}

export interface AuthTokenPayload {
  accessToken: string
  refreshToken: string
  accessExpiresAt: string
  refreshExpiresAt: string
}

export interface AuthSessionPayload {
  account: AuthAccountPayload
  tokens: AuthTokenPayload
}

export interface AuthErrorPayload {
  code?: string
  retryAfter?: number
  message?: string
}

export enum AuthPanelStage {
  SUMMARY = 'summary',
  EMAIL = 'email',
  CODE = 'code'
}
