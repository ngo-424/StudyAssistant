export class AuthPresentation {
  static maskEmail(email: string): string {
    const at: number = email.indexOf('@')
    if (at <= 0) {
      return email
    }
    const local: string = email.substring(0, at)
    const domain: string = email.substring(at)
    if (local.length <= 2) {
      return `${local.substring(0, 1)}***${domain}`
    }
    return `${local.substring(0, 2)}***${domain}`
  }

  static errorMessage(code: string): string {
    if (code === 'INVALID_EMAIL') {
      return '请输入有效的邮箱地址'
    }
    if (code === 'INVALID_CODE') {
      return '验证码不正确，请重新输入'
    }
    if (code === 'CODE_EXPIRED') {
      return '验证码已过期，请重新获取'
    }
    if (code === 'RATE_LIMITED') {
      return '操作过于频繁，请稍后再试'
    }
    if (code === 'MAIL_UNAVAILABLE') {
      return '验证码暂时无法发送，请稍后重试'
    }
    if (code === 'NETWORK_UNAVAILABLE') {
      return '无法连接账号服务，请检查网络和服务地址'
    }
    if (code === 'SESSION_EXPIRED') {
      return '登录已过期，请重新验证邮箱'
    }
    return '账号操作未完成，请稍后重试'
  }
}
