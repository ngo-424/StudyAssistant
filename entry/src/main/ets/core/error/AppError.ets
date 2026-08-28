export enum AppErrorCode {
  UNKNOWN = 'UNKNOWN',
  INITIALIZATION = 'INITIALIZATION',
  VALIDATION = 'VALIDATION',
  DATABASE = 'DATABASE',
  MIGRATION = 'MIGRATION'
}

export class AppError extends Error {
  readonly code: AppErrorCode

  constructor(code: AppErrorCode, message: string) {
    super(message)
    this.name = 'AppError'
    this.code = code
  }
}
