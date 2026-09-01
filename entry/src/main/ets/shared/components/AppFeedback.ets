import { AppControl, AppRadius, AppSpacing, AppTypography } from '../../core/design/DesignTokens'

export enum ActionState {
  IDLE = 'idle',
  LOADING = 'loading',
  SUCCESS = 'success',
  DISABLED = 'disabled'
}

export enum ActionTone {
  PRIMARY = 'primary',
  SECONDARY = 'secondary',
  DANGER = 'danger'
}

export enum MessageTone {
  INFO = 'info',
  SUCCESS = 'success',
  WARNING = 'warning',
  ERROR = 'error'
}

@Component
export struct AppActionButton {
  @Prop label: ResourceStr
  @Prop loadingLabel: ResourceStr = ''
  @Prop successLabel: ResourceStr = ''
  @Prop state: ActionState = ActionState.IDLE
  @Prop tone: ActionTone = ActionTone.PRIMARY
  onAction: () => void = () => {}

  private visibleLabel(): ResourceStr {
    if (this.state === ActionState.LOADING && `${this.loadingLabel}`.length > 0) {
      return this.loadingLabel
    }
    if (this.state === ActionState.SUCCESS && `${this.successLabel}`.length > 0) {
      return this.successLabel
    }
    return this.label
  }

  private buttonBackground(): ResourceColor {
    if (this.state === ActionState.DISABLED) {
      return $r('app.color.surface_emphasis')
    }
    if (this.tone === ActionTone.DANGER) {
      return $r('app.color.danger_container')
    }
    if (this.tone === ActionTone.SECONDARY) {
      return $r('app.color.surface_secondary')
    }
    return $r('app.color.brand_primary')
  }

  private foreground(): ResourceColor {
    if (this.state === ActionState.DISABLED) {
      return $r('app.color.text_tertiary')
    }
    if (this.tone === ActionTone.DANGER) {
      return $r('app.color.danger')
    }
    if (this.tone === ActionTone.SECONDARY) {
      return $r('app.color.text_primary')
    }
    return $r('app.color.brand_on_primary')
  }

  build() {
    Button(this.visibleLabel())
      .width('100%')
      .height(AppControl.PRIMARY_HEIGHT)
      .fontSize(AppTypography.BODY)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.foreground())
      .backgroundColor(this.buttonBackground())
      .borderRadius(AppRadius.MD)
      .stateEffect(true)
      .enabled(this.state !== ActionState.LOADING && this.state !== ActionState.DISABLED)
      .onClick(this.onAction)
  }
}

@Component
export struct AppStatusBanner {
  @Prop message: ResourceStr
  @Prop tone: MessageTone = MessageTone.INFO

  private foreground(): ResourceColor {
    if (this.tone === MessageTone.ERROR) {
      return $r('app.color.danger')
    }
    if (this.tone === MessageTone.WARNING) {
      return $r('app.color.warning')
    }
    if (this.tone === MessageTone.SUCCESS) {
      return $r('app.color.success')
    }
    return $r('app.color.brand_primary')
  }

  private bannerBackground(): ResourceColor {
    if (this.tone === MessageTone.ERROR) {
      return $r('app.color.danger_container')
    }
    if (this.tone === MessageTone.WARNING) {
      return $r('app.color.warning_container')
    }
    if (this.tone === MessageTone.SUCCESS) {
      return $r('app.color.success_container')
    }
    return $r('app.color.brand_container')
  }

  build() {
    Row({ space: AppSpacing.SM }) {
      SymbolGlyph(this.tone === MessageTone.ERROR ? $r('sys.symbol.xmark_circle') :
        (this.tone === MessageTone.SUCCESS ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.info_circle')))
        .fontSize(20)
        .fontColor([this.foreground()])
      Text(this.message)
        .layoutWeight(1)
        .fontSize(AppTypography.CAPTION)
        .fontColor(this.foreground())
    }
    .width('100%')
    .padding(AppSpacing.MD)
    .backgroundColor(this.bannerBackground())
    .borderRadius(AppRadius.SM)
  }
}

@Component
export struct AppLoadingState {
  @Prop message: ResourceStr

  build() {
    Column({ space: AppSpacing.MD }) {
      LoadingProgress()
        .width(44)
        .height(44)
        .color($r('app.color.brand_primary'))
      Text(this.message)
        .fontSize(AppTypography.BODY)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .constraintSize({ minHeight: 220 })
    .justifyContent(FlexAlign.Center)
  }
}

@Component
export struct AppEmptyState {
  @Prop symbol: Resource
  @Prop title: ResourceStr
  @Prop message: ResourceStr

  build() {
    Column({ space: AppSpacing.MD }) {
      SymbolGlyph(this.symbol)
        .fontSize(34)
        .fontColor([$r('app.color.brand_primary')])
      Text(this.title)
        .fontSize(AppTypography.SUBTITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
      Text(this.message)
        .fontSize(AppTypography.BODY)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .constraintSize({ minHeight: 240 })
    .padding(AppSpacing.XL)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}
