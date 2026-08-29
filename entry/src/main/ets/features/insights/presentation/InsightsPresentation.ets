export class InsightsPresentation {
  static focusMinutes(seconds: number): string {
    if (seconds <= 0) {
      return '0 分钟'
    }
    if (seconds < 60) {
      return '<1 分钟'
    }
    return `${Math.round(seconds / 60)} 分钟`
  }

  static duration(seconds: number): string {
    if (seconds < 60) {
      return seconds > 0 ? '<1 分钟' : '0 分钟'
    }
    const minutes: number = Math.round(seconds / 60)
    if (minutes < 60) {
      return `${minutes} 分钟`
    }
    const hours: number = Math.floor(minutes / 60)
    const remaining: number = minutes % 60
    return remaining === 0 ? `${hours} 小时` : `${hours} 小时 ${remaining} 分钟`
  }

  static percentage(value: number): string {
    return `${Math.round(Math.max(0, Math.min(1, value)) * 100)}%`
  }
}
