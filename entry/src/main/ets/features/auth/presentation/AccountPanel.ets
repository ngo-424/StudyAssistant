import { AppControl, AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { HapticFeedbackService } from '../../../core/haptics/HapticFeedbackService'
import { AppStatusBanner, MessageTone } from '../../../shared/components/AppFeedback'
import { AccountSession, AuthPanelStage } from '../domain/AuthModels'
import { GuestDataSummary } from '../../../domain/model/StudyModels'
import { AuthRules } from '../domain/AuthRules'
import { AuthPresentation } from './AuthPresentation'
import { AuthViewModel } from './AuthViewModel'

@Component
export struct AccountPanel {
  @Prop isWide: boolean = false
  onProfileChanged: () => void = () => {}
  @State session: AccountSession | null = null
  @State stage: AuthPanelStage = AuthPanelStage.SUMMARY
  @State email: string = ''
  @State code: string = ''
  @State loading: boolean = true
  @State working: boolean = false
  @State message: string = ''
  @State errorMessage: string = ''
  @State guestTaskCount: number = 0
  @State guestFocusCount: number = 0
  @State guestPoints: number = 0
  @State resendSeconds: number = 0
  private readonly viewModel: AuthViewModel = new AuthViewModel()
  private resendTimerId: number = -1

  aboutToAppear(): void {
    this.loadSession()
  }

  aboutToDisappear(): void {
    this.stopResendCountdown()
  }

  private startResendCountdown(): void {
    this.stopResendCountdown()
    this.resendSeconds = 60
    this.resendTimerId = setInterval(() => {
      this.resendSeconds = Math.max(0, this.resendSeconds - 1)
      if (this.resendSeconds === 0) {
        this.stopResendCountdown()
      }
    }, 1000)
  }

  private stopResendCountdown(): void {
    if (this.resendTimerId >= 0) {
      clearInterval(this.resendTimerId)
      this.resendTimerId = -1
    }
  }

  private resendLabel(): string {
    return this.resendSeconds > 0 ? `${this.resendSeconds} 秒后可重发` : '重新发送'
  }

  private async loadSession(): Promise<void> {
    this.loading = true
    try {
      this.session = await this.viewModel.load()
      const summary: GuestDataSummary = await this.viewModel.guestSummary()
      this.guestTaskCount = summary.taskCount
      this.guestFocusCount = summary.focusCount
      this.guestPoints = summary.points
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

  private async cancelLogin(): Promise<void> {
    if (this.stage === AuthPanelStage.GUEST_DECISION) {
      this.working = true
      try {
        await this.viewModel.cancelVerifiedLogin()
        this.session = null
        this.onProfileChanged()
      } catch (error) {
        this.errorMessage = '取消登录失败，请稍后重试'
        return
      } finally {
        this.working = false
      }
    }
    this.stage = AuthPanelStage.SUMMARY
    this.email = ''
    this.code = ''
    this.message = ''
    this.errorMessage = ''
  }

  private async requestCode(): Promise<void> {
    if (this.working || this.resendSeconds > 0) {
      return
    }
    if (!AuthRules.validEmail(this.email)) {
      this.errorMessage = AuthPresentation.errorMessage('INVALID_EMAIL')
      return
    }
    this.working = true
    try {
      const result = await this.viewModel.requestCode(this.email)
      this.stage = AuthPanelStage.CODE
      this.message = `验证码已发送，${Math.round(result.expiresInSeconds / 60)} 分钟内有效`
      this.errorMessage = ''
      this.startResendCountdown()
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
      const preparation = await this.viewModel.prepareLogin(this.session)
      this.guestTaskCount = preparation.taskCount
      this.guestFocusCount = preparation.focusCount
      this.guestPoints = preparation.points
      this.stage = preparation.requiresGuestDecision ? AuthPanelStage.GUEST_DECISION : AuthPanelStage.SUMMARY
      this.code = ''
      this.message = preparation.requiresGuestDecision ?
        '邮箱验证成功，请选择如何处理本机游客数据' : '邮箱验证成功，账号已登录'
      if (!preparation.requiresGuestDecision) {
        this.onProfileChanged()
      }
      this.errorMessage = ''
      await HapticFeedbackService.success()
    } catch (error) {
      this.errorMessage = AuthPresentation.errorMessage(this.viewModel.errorCode(error as Object))
    } finally {
      this.working = false
    }
  }

  private async mergeGuestAndLogin(): Promise<void> {
    if (this.working || this.session === null) {
      return
    }
    this.working = true
    try {
      await this.viewModel.mergeGuestAndLogin(this.session)
      this.message = '本机游客数据已复制到账号并完成同步；原数据仍保留在本机'
      this.errorMessage = ''
    } catch (error) {
      this.message = '本机游客数据已安全保留，网络恢复后会继续同步'
      this.errorMessage = '当前无法连接同步服务'
    } finally {
      this.stage = AuthPanelStage.SUMMARY
      this.onProfileChanged()
      this.working = false
    }
  }

  private async keepGuestAndLogin(): Promise<void> {
    if (this.working || this.session === null) {
      return
    }
    this.working = true
    try {
      await this.viewModel.keepGuestAndLogin(this.session)
      this.message = '已进入账号，本机游客数据会继续保留'
      this.errorMessage = ''
    } catch (error) {
      this.message = '已进入账号，本机游客数据会继续保留'
      this.errorMessage = '当前离线，账号数据将在稍后同步'
    } finally {
      this.stage = AuthPanelStage.SUMMARY
      this.onProfileChanged()
      this.working = false
    }
  }

  private async importGuestData(): Promise<void> {
    if (this.working || this.session === null) {
      return
    }
    this.working = true
    try {
      await this.viewModel.importGuestData(this.session)
      this.message = '游客数据已导入账号；原数据仍保留在本机'
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = '导入已保存在本机，但暂时无法完成云同步'
    } finally {
      this.working = false
    }
  }

  private confirmDeleteGuestData(): void {
    this.getUIContext().showAlertDialog({
      title: '删除本机游客数据？',
      message: `将删除当前设备上的 ${this.guestTaskCount} 个任务、${this.guestFocusCount} 条专注记录和 ${this.guestPoints} 积分。账号数据不受影响。`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除本机数据', fontColor: $r('app.color.danger'),
        action: () => this.deleteGuestData()
      }
    })
  }

  private async deleteGuestData(): Promise<void> {
    this.working = true
    try {
      await this.viewModel.deleteGuestData()
      this.guestTaskCount = 0
      this.guestFocusCount = 0
      this.guestPoints = 0
      this.message = '本机游客数据已删除'
      this.errorMessage = ''
      await HapticFeedbackService.success()
    } catch (error) {
      this.errorMessage = '本机游客数据没有删除成功，请稍后重试'
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
      this.errorMessage = '云端暂时没有确认退出，但本机登录信息已安全清除'
    } finally {
      this.session = null
      this.message = '已回到游客模式，本地游客数据仍保留'
      this.onProfileChanged()
      this.working = false
    }
  }

  private confirmDeleteAccount(): void {
    this.getUIContext().showAlertDialog({
      title: '注销账号？',
      message: '账号及云端账号数据会被删除。本机游客数据不会删除，此操作无法撤销。',
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
      this.onProfileChanged()
      this.errorMessage = ''
      await HapticFeedbackService.success()
    } catch (error) {
      this.errorMessage = AuthPresentation.errorMessage(this.viewModel.errorCode(error as Object))
    } finally {
      this.working = false
    }
  }

  @Builder
  private StatusMessage() {
    if (this.errorMessage.length > 0) {
      AppStatusBanner({ message: this.errorMessage, tone: MessageTone.ERROR })
    } else if (this.message.length > 0) {
      AppStatusBanner({ message: this.message, tone: MessageTone.SUCCESS })
    }
  }

  @Builder
  private GuestSummary() {
    Row({ space: AppSpacing.MD }) {
      SymbolGlyph($r('sys.symbol.person_crop_circle_fill')).fontSize(34)
        .fontColor([$r('app.color.brand_primary')])
      Column({ space: AppSpacing.XS }) {
        Text('游客模式').fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('任务、专注和积分仅保存在当前设备').fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: AppSpacing.SM }) {
        Button('邮箱登录').height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
          .borderRadius(AppRadius.SM).onClick(() => this.beginLogin())
        if (this.guestTaskCount > 0 || this.guestFocusCount > 0 || this.guestPoints > 0) {
          Button('删除本机数据').height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.danger')).backgroundColor($r('app.color.danger_container'))
            .borderRadius(AppRadius.SM).onClick(() => this.confirmDeleteGuestData())
        }
      }
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
        Button('取消').height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
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
          Button(this.resendLabel()).layoutWeight(1).height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary')).backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(AppRadius.SM).enabled(!this.working && this.resendSeconds === 0)
            .onClick(() => this.requestCode())
          Button(this.working ? '正在验证' : '登录或注册').layoutWeight(1).height(AppControl.MIN_TOUCH)
            .fontWeight(FontWeight.Bold).fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary')).borderRadius(AppRadius.SM)
            .enabled(!this.working && AuthRules.validCode(this.code)).onClick(() => this.verifyCode())
        }
        .width('100%')
      } else {
        Button(this.working ? '正在发送' : '获取验证码').width(this.isWide ? 260 : '100%')
          .height(AppControl.PRIMARY_HEIGHT)
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary')).borderRadius(AppRadius.SM)
          .enabled(!this.working && AuthRules.validEmail(this.email)).onClick(() => this.requestCode())
      }
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private GuestDecision() {
    Column({ space: AppSpacing.MD }) {
      Text('处理本机游客数据').fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(`检测到 ${this.guestTaskCount} 个任务、${this.guestFocusCount} 条专注记录、${this.guestPoints} 积分`)
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
        .padding(AppSpacing.MD).backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.SM)
      Button(this.working ? '正在合并' : '合并游客数据并登录').width('100%').height(AppControl.PRIMARY_HEIGHT)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.brand_on_primary'))
        .backgroundColor($r('app.color.brand_primary')).borderRadius(AppRadius.SM)
        .enabled(!this.working).onClick(() => this.mergeGuestAndLogin())
      Button('不合并，保留本机数据').width('100%').height(AppControl.MIN_TOUCH)
        .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_secondary'))
        .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.keepGuestAndLogin())
      Button('取消登录').width('100%').height(AppControl.MIN_TOUCH).fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent).enabled(!this.working).onClick(() => this.cancelLogin())
      Text('合并只会复制数据；云端同步成功前不会删除本机原数据。')
        .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_tertiary'))
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private AccountSummary(session: AccountSession) {
    Column({ space: AppSpacing.MD }) {
      Row({ space: AppSpacing.MD }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(34)
          .fontColor([$r('app.color.brand_primary')])
        Column({ space: AppSpacing.XS }) {
          Text('账号已登录').fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(AuthPresentation.maskEmail(session.email)).fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Text('账号数据与本机游客数据相互隔离；离线时也可以继续使用，联网后会同步到其他登录设备。')
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
        .padding(AppSpacing.MD).backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.SM)

      Row({ space: AppSpacing.MD }) {
        Button('退出登录').layoutWeight(1).height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary')).backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.logout())
        Button('注销账号').layoutWeight(1).height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.danger')).backgroundColor($r('app.color.danger_container'))
          .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.confirmDeleteAccount())
      }
      .width('100%')

      if (this.guestTaskCount > 0 || this.guestFocusCount > 0 || this.guestPoints > 0) {
        Column({ space: AppSpacing.SM }) {
          Text(`本机游客数据：${this.guestTaskCount} 个任务 · ${this.guestFocusCount} 条专注 · ${this.guestPoints} 积分`)
            .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
          Row({ space: AppSpacing.MD }) {
            Button('导入账号').layoutWeight(1).height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
              .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.brand_container'))
              .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.importGuestData())
            Button('删除本机数据').layoutWeight(1).height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
              .fontColor($r('app.color.danger')).backgroundColor($r('app.color.danger_container'))
              .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.confirmDeleteGuestData())
          }
        }
        .width('100%')
      }
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
      } else if (this.stage === AuthPanelStage.GUEST_DECISION) {
        this.GuestDecision()
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
