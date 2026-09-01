import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0x5354
const LOG_TAG: string = 'Shiya'

export class AppLogger {
  static info(scope: string, message: string): void {
    hilog.info(DOMAIN, LOG_TAG, '[%{public}s] %{public}s', scope, message)
  }

  static warn(scope: string, message: string): void {
    hilog.warn(DOMAIN, LOG_TAG, '[%{public}s] %{public}s', scope, message)
  }

  static error(scope: string, message: string): void {
    hilog.error(DOMAIN, LOG_TAG, '[%{public}s] %{public}s', scope, message)
  }
}
