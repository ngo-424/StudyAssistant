import { AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { AccountSession, AuthPanelStage } from '../domain/AuthModels'
import { AuthRules } from '../domain/AuthRules'
import { AuthPresentation } from './AuthPresentation'
import { AuthViewModel } from './AuthViewModel'

@Component
export struct AccountPanel {
  @Prop isWide: boolean = false
  @State session: AccountSession | null = null
  @State stage: AuthPanelStage = AuthPanelStage.SUMMARY
  @State email: string = ''
  @State code: string = ''
  @State loading: boolean = true
  @State working: boolean = false
  @State message: string = ''
  @State errorMessage: string = ''
  private readonly viewModel: AuthViewModel = new AuthViewModel()

  aboutToAppear(): void {
    this.loadSession()
  }

  private async loadSession(): Promise<void> {
    this.loading = true
    try {
      this.session = await this.viewModel.load()
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = '账号状态读取失败，本地游客数据不受影响'
    } finally {
      this.loading = false
    }
  }

  private beginLogin(): void {
    this.stage = AuthPanelStage.EMAIL
    this.message = ''
    this.errorMessage = ''
  }

  private cancelLogin(): void {
    this.stage = AuthPanelStage.SUMMARY
    this.email = ''
    this.code = ''
    this.message = ''
    this.errorMessage = ''
  }

  private async requestCode(): Promise<void> {
    if (this.working || !AuthRules.validEmail(this.email)) {
      this.errorMessage = AuthPresentation.errorMessage('INVALID_EMAIL')
      return
    }
    this.working = true
    try {
      const result = await this.viewModel.requestCode(this.email)
      this.stage = AuthPanelStage.CODE
      this.message = `验证码已发送，${Math.round(result.expiresInSeconds / 60)} 分钟内有效`
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = AuthPresentation.errorMessage(this.viewModel.errorCode(error as Object))
    } finally {
      this.working = false
    }
  }

  private async verifyCode(): Promise<void> {
    if (this.working || !AuthRules.validCode(this.code)) {
      this.errorMessage = AuthPresentation.errorMessage('INVALID_CODE')
      return
    }
    this.working = true
    try {
      this.session = await this.viewModel.verifyCode(this.email, this.code)
      this.stage = AuthPanelStage.SUMMARY
      this.code = ''
      this.message = '邮箱验证成功，账号已登录'
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = AuthPresentation.errorMessage(this.viewModel.errorCode(error as Object))
    } finally {
      this.working = false
    }
  }

  private async logout(): Promise<void> {
    if (this.working) {
      return
    }
    this.working = true
    try {
      await this.viewModel.logout()
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = '服务端登出未确认，本机登录信息已清除'
    } finally {
      this.session = null
      this.message = '已回到游客模式，本地游客数据仍保留'
      this.working = false
    }
  }

  private confirmDeleteAccount(): void {
    this.getUIContext().showAlertDialog({
      title: '注销账号？',
      message: '账号及服务端账号数据会被删除。本机游客数据不会删除，此操作无法撤销。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '注销账号',
        fontColor: $r('app.color.danger'),
        action: () => this.deleteAccount()
      }
    })
  }

  private async deleteAccount(): Promise<void> {
    if (this.working) {
      return
    }
    this.working = true
    try {
      await this.viewModel.deleteAccount()
      this.session = null
      this.message = '账号已注销，当前使用本地游客模式'
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = AuthPresentation.errorMessage(this.viewModel.errorCode(error as Object))
    } finally {
      this.working = false
    }
  }

  @Builder
  private StatusMessage() {
    if (this.errorMessage.length > 0) {
      Text(this.errorMessage)
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.danger'))
        .padding(AppSpacing.MD).backgroundColor($r('app.color.danger_container')).borderRadius(AppRadius.SM)
    } else if (this.message.length > 0) {
      Text(this.message)
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.brand_primary'))
        .padding(AppSpacing.MD).backgroundColor($r('app.color.brand_container')).borderRadius(AppRadius.SM)
    }
  }

  @Builder
  private GuestSummary() {
    Row({ space: AppSpacing.MD }) {
      Text('○').width(42).height(42).fontSize(18).textAlign(TextAlign.Center)
        .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.brand_container'))
        .borderRadius(AppRadius.SM)
      Column({ space: AppSpacing.XS }) {
        Text('游客模式').fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('任务、专注和积分仅保存在当前设备').fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('邮箱登录').height(40).fontSize(AppTypography.CAPTION)
        .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
        .borderRadius(AppRadius.SM).onClick(() => this.beginLogin())
    }
    .width('100%')
  }

  @Builder
  private LoginForm() {
    Column({ space: AppSpacing.MD }) {
      Row() {
        Column({ space: AppSpacing.XS }) {
          Text(this.stage === AuthPanelStage.EMAIL ? '邮箱验证码登录' : '输入验证码')
            .fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text('首次验证会自动创建账号，无需设置密码').fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button('取消').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
          .backgroundColor(Color.Transparent).onClick(() => this.cancelLogin())
      }
      .width('100%')

      TextInput({ text: this.email, placeholder: '邮箱地址' })
        .width('100%').height(48).maxLength(320).enabled(this.stage === AuthPanelStage.EMAIL)
        .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_secondary'))
        .borderRadius(AppRadius.SM).onChange((value: string) => this.email = value)

      if (this.stage === AuthPanelStage.CODE) {
        TextInput({ text: this.code, placeholder: '6 位数字验证码' })
          .width('100%').height(48).maxLength(6).type(InputType.Number)
          .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM).onChange((value: string) => this.code = value)
        Row({ space: AppSpacing.MD }) {
          Button('重新发送').layoutWeight(1).height(44).fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary')).backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.requestCode())
          Button(this.working ? '正在验证' : '登录 / 注册').layoutWeight(1).height(44)
            .fontWeight(FontWeight.Bold).fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary')).borderRadius(AppRadius.SM)
            .enabled(!this.working && AuthRules.validCode(this.code)).onClick(() => this.verifyCode())
        }
        .width('100%')
      } else {
        Button(this.working ? '正在发送' : '获取验证码').width(this.isWide ? 260 : '100%').height(46)
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary')).borderRadius(AppRadius.SM)
          .enabled(!this.working && AuthRules.validEmail(this.email)).onClick(() => this.requestCode())
      }
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private AccountSummary(session: AccountSession) {
    Column({ space: AppSpacing.MD }) {
      Row({ space: AppSpacing.MD }) {
        Text('✓').width(42).height(42).fontSize(18).textAlign(TextAlign.Center)
          .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.brand_container'))
          .borderRadius(AppRadius.SM)
        Column({ space: AppSpacing.XS }) {
          Text('账号已登录').fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(AuthPresentation.maskEmail(session.email)).fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Text('游客数据仍安全保留在本机；登录后的合并选择和多设备同步将在下一模块开放。')
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
        .padding(AppSpacing.MD).backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.SM)

      Row({ space: AppSpacing.MD }) {
        Button('退出登录').layoutWeight(1).height(42).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary')).backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.logout())
        Button('注销账号').layoutWeight(1).height(42).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.danger')).backgroundColor($r('app.color.danger_container'))
          .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.confirmDeleteAccount())
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Column({ space: AppSpacing.MD }) {
      if (this.loading) {
        Row({ space: AppSpacing.MD }) {
          LoadingProgress().width(32).height(32).color($r('app.color.brand_primary'))
          Text('正在读取账号状态').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
      } else if (this.session !== null) {
        this.AccountSummary(this.session)
      } else if (this.stage === AuthPanelStage.SUMMARY) {
        this.GuestSummary()
      } else {
        this.LoginForm()
      }
      this.StatusMessage()
    }
    .width('100%').padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}
