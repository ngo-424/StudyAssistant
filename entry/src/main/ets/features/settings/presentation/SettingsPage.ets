import { AppError } from '../../../core/error/AppError'
import { AppBreakpoint, AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { TimerConfig } from '../../../domain/model/StudyModels'
import { TimerConfigRules } from '../../focus/domain/TimerConfigRules'
import { FocusSettingsViewModel } from './FocusSettingsViewModel'
import { AccountPanel } from '../../auth/presentation/AccountPanel'
import { SyncPanel } from '../../sync/presentation/SyncPanel'

@Component
struct SettingRow {
  @Prop icon: string
  @Prop title: ResourceStr
  @Prop description: ResourceStr

  build() {
    Row({ space: AppSpacing.MD }) {
      Text(this.icon)
        .width(42).height(42).fontSize(18)
        .fontColor($r('app.color.brand_primary')).textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.brand_container')).borderRadius(AppRadius.SM)
      Column({ space: AppSpacing.XS }) {
        Text(this.title).fontSize(AppTypography.BODY).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.description).fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(24).fontColor($r('app.color.text_tertiary'))
    }
    .width('100%').padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}

@Component
struct DurationRow {
  @Prop label: string
  @Prop description: string
  @Prop value: number
  @Prop minimum: number
  @Prop maximum: number
  onChange: (value: number) => void = () => {}

  build() {
    Row({ space: AppSpacing.MD }) {
      Column({ space: AppSpacing.XS }) {
        Text(this.label).fontSize(AppTypography.BODY).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.description).fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Row({ space: AppSpacing.SM }) {
        Button('−').width(36).height(36).fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.SM)
          .enabled(this.value > this.minimum).onClick(() => this.onChange(this.value - 1))
        Text(`${this.value}`).width(44).fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).textAlign(TextAlign.Center)
        Button('+').width(36).height(36).fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.SM)
          .enabled(this.value < this.maximum).onClick(() => this.onChange(this.value + 1))
      }
    }
    .width('100%')
  }
}

@Component
struct AutomationRow {
  @Prop label: string
  @Prop description: string
  @Prop isEnabled: boolean
  onChange: (value: boolean) => void = () => {}

  build() {
    Row({ space: AppSpacing.MD }) {
      Column({ space: AppSpacing.XS }) {
        Text(this.label).fontSize(AppTypography.BODY).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.description).fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
        .selectedColor($r('app.color.brand_primary'))
        .onChange((value: boolean) => this.onChange(value))
    }
    .width('100%')
  }
}

@Component
export struct SettingsPage {
  @Prop isWide: boolean = false
  @State config: TimerConfig = TimerConfigRules.defaults()
  @State loading: boolean = true
  @State saving: boolean = false
  @State saved: boolean = false
  @State errorMessage: string = ''
  @State profileVersion: number = 0
  private readonly viewModel: FocusSettingsViewModel = new FocusSettingsViewModel()

  aboutToAppear(): void {
    this.loadConfig()
  }

  private async loadConfig(): Promise<void> {
    this.loading = true
    try {
      this.config = await this.viewModel.load()
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.loading = false
    }
  }

  private updateConfig(focusMinutes: number = this.config.focusMinutes,
    shortBreakMinutes: number = this.config.shortBreakMinutes,
    longBreakMinutes: number = this.config.longBreakMinutes,
    longBreakEvery: number = this.config.longBreakEvery,
    autoStartBreaks: boolean = this.config.autoStartBreaks,
    autoStartFocus: boolean = this.config.autoStartFocus): void {
    this.saved = false
    this.config = {
      focusMinutes: focusMinutes,
      shortBreakMinutes: shortBreakMinutes,
      longBreakMinutes: longBreakMinutes,
      longBreakEvery: longBreakEvery,
      autoStartBreaks: autoStartBreaks,
      autoStartFocus: autoStartFocus
    }
  }

  private async saveConfig(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    try {
      this.config = await this.viewModel.save(this.config)
      this.saved = true
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.saving = false
    }
  }

  private readableError(error: Object): string {
    if (error instanceof AppError) {
      return '设置值超出允许范围，请调整后再保存'
    }
    return '专注设置没有保存，请稍后重试'
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.LG }) {
        Column({ space: AppSpacing.XS }) {
          Text($r('app.string.settings_title')).fontSize(AppTypography.TITLE)
            .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_subtitle')).fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%').alignItems(HorizontalAlign.Start)

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage).width('100%').fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.danger')).padding(AppSpacing.MD)
            .backgroundColor($r('app.color.danger_container')).borderRadius(AppRadius.MD)
        }

        Column({ space: AppSpacing.LG }) {
          Row({ space: AppSpacing.MD }) {
            Text('◷').width(42).height(42).fontSize(18).textAlign(TextAlign.Center)
              .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.brand_container'))
              .borderRadius(AppRadius.SM)
            Column({ space: AppSpacing.XS }) {
              Text($r('app.string.focus_settings')).fontSize(AppTypography.BODY)
                .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
              Text('修改会从下一段计时开始生效').fontSize(AppTypography.CAPTION)
                .fontColor($r('app.color.text_secondary'))
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          if (this.loading) {
            LoadingProgress().width(42).height(42).color($r('app.color.brand_primary'))
          } else {
            DurationRow({
              label: '专注时长', description: '每轮 1–480 分钟', value: this.config.focusMinutes,
              minimum: 1, maximum: 480,
              onChange: (value: number) => this.updateConfig(value)
            })
            DurationRow({
              label: '短休息', description: '每轮 1–120 分钟', value: this.config.shortBreakMinutes,
              minimum: 1, maximum: 120,
              onChange: (value: number) => this.updateConfig(this.config.focusMinutes, value)
            })
            DurationRow({
              label: '长休息', description: '每轮 1–180 分钟', value: this.config.longBreakMinutes,
              minimum: 1, maximum: 180,
              onChange: (value: number) => this.updateConfig(
                this.config.focusMinutes, this.config.shortBreakMinutes, value)
            })
            DurationRow({
              label: '长休息间隔', description: '完成几轮专注后进入长休息', value: this.config.longBreakEvery,
              minimum: 2, maximum: 12,
              onChange: (value: number) => this.updateConfig(
                this.config.focusMinutes, this.config.shortBreakMinutes, this.config.longBreakMinutes, value)
            })
            Divider().color($r('app.color.border_subtle'))
            AutomationRow({
              label: '自动开始休息', description: '专注正常完成后直接进入休息',
              isEnabled: this.config.autoStartBreaks,
              onChange: (value: boolean) => this.updateConfig(
                this.config.focusMinutes, this.config.shortBreakMinutes, this.config.longBreakMinutes,
                this.config.longBreakEvery, value, this.config.autoStartFocus)
            })
            AutomationRow({
              label: '自动开始专注', description: '休息正常结束后直接进入下一轮',
              isEnabled: this.config.autoStartFocus,
              onChange: (value: boolean) => this.updateConfig(
                this.config.focusMinutes, this.config.shortBreakMinutes, this.config.longBreakMinutes,
                this.config.longBreakEvery, this.config.autoStartBreaks, value)
            })
            Button(this.saved ? '已保存' : '保存专注设置')
              .width(this.isWide ? 280 : '100%').height(48).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
              .borderRadius(AppRadius.MD).enabled(!this.saving)
              .onClick(() => this.saveConfig())
          }
        }
        .width('100%').padding(AppSpacing.LG)
        .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.border_subtle') })

        Column({ space: AppSpacing.MD }) {
          AccountPanel({
            isWide: this.isWide,
            onProfileChanged: () => this.profileVersion++
          })
          SyncPanel({ profileVersion: this.profileVersion })
          SettingRow({ icon: '◐', title: $r('app.string.appearance'), description: $r('app.string.appearance_desc') })
        }
        .width('100%')
      }
      .width('100%').constraintSize({ maxWidth: AppBreakpoint.CONTENT_MAX })
      .padding(this.isWide ? AppSpacing.XXL : AppSpacing.LG)
    }
    .width('100%').height('100%').scrollBar(BarState.Off)
  }
}
