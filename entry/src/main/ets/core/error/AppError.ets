export enum AppErrorCode {
  UNKNOWN = 'UNKNOWN',
  INITIALIZATION = 'INITIALIZATION',
  VALIDATION = 'VALIDATION'
}

export class AppError extends Error {
  readonly code: AppErrorCode

  constructor(code: AppErrorCode, message: string) {
    super(message)
    this.name = 'AppError'
    this.code = code
  }
}
