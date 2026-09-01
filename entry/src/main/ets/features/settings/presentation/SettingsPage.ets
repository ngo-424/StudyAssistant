import { AppError } from '../../../core/error/AppError'
import { HapticFeedbackService } from '../../../core/haptics/HapticFeedbackService'
import { AppBreakpoint, AppControl, AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { TimerConfig } from '../../../domain/model/StudyModels'
import { AppActionButton, ActionState, AppStatusBanner, MessageTone } from '../../../shared/components/AppFeedback'
import { AccountPanel } from '../../auth/presentation/AccountPanel'
import { TimerConfigRules } from '../../focus/domain/TimerConfigRules'
import { SyncPanel } from '../../sync/presentation/SyncPanel'
import { DataAndPrivacyPanel } from './DataAndPrivacyPanel'
import { FocusSettingsViewModel } from './FocusSettingsViewModel'
import { SettingsDestination } from './SettingsDestination'

@Component
struct SettingRow {
  @Prop symbol: Resource
  @Prop title: ResourceStr
  @Prop description: ResourceStr
  onOpen: () => void = () => {}

  build() {
    Row({ space: AppSpacing.MD }) {
      Row() {
        SymbolGlyph(this.symbol)
          .fontSize(22)
          .fontColor([$r('app.color.brand_primary')])
      }
      .width(AppControl.ICON_SIZE)
      .height(AppControl.ICON_SIZE)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.brand_container'))
      .borderRadius(AppRadius.SM)

      Column({ space: AppSpacing.XS }) {
        Text(this.title)
          .fontSize(AppTypography.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.description)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.text_tertiary')])
    }
    .width('100%')
    .constraintSize({ minHeight: 78 })
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border_subtle') })
    .onClick(this.onOpen)
  }
}

@Component
struct DurationRow {
  @Prop label: ResourceStr
  @Prop description: ResourceStr
  @Prop value: number
  @Prop minimum: number
  @Prop maximum: number
  onChange: (value: number) => void = () => {}

  build() {
    Row({ space: AppSpacing.MD }) {
      Column({ space: AppSpacing.XS }) {
        Text(this.label)
          .fontSize(AppTypography.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.description)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: AppSpacing.XS }) {
        Button() {
          SymbolGlyph($r('sys.symbol.minus'))
            .fontSize(18)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(AppControl.MIN_TOUCH)
        .height(AppControl.MIN_TOUCH)
        .backgroundColor($r('app.color.surface_secondary'))
        .borderRadius(AppRadius.SM)
        .enabled(this.value > this.minimum)
        .accessibilityText(`减少${this.label}`)
        .onClick(() => this.onChange(this.value - 1))

        Text(`${this.value}`)
          .width(44)
          .fontSize(AppTypography.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)

        Button() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(18)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(AppControl.MIN_TOUCH)
        .height(AppControl.MIN_TOUCH)
        .backgroundColor($r('app.color.surface_secondary'))
        .borderRadius(AppRadius.SM)
        .enabled(this.value < this.maximum)
        .accessibilityText(`增加${this.label}`)
        .onClick(() => this.onChange(this.value + 1))
      }
    }
    .width('100%')
  }
}

@Component
struct AutomationRow {
  @Prop label: ResourceStr
  @Prop description: ResourceStr
  @Prop isEnabled: boolean
  onChange: (value: boolean) => void = () => {}

  build() {
    Row({ space: AppSpacing.MD }) {
      Column({ space: AppSpacing.XS }) {
        Text(this.label)
          .fontSize(AppTypography.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.description)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
        .selectedColor($r('app.color.brand_primary'))
        .onChange((value: boolean) => this.onChange(value))
    }
    .width('100%')
    .constraintSize({ minHeight: AppControl.MIN_TOUCH })
  }
}

@Component
export struct SettingsPage {
  @Prop isWide: boolean = false
  @State destination: SettingsDestination = SettingsDestination.OVERVIEW
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
      this.errorMessage = '设置暂时没有读取成功，请重试'
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
      await HapticFeedbackService.success()
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.saving = false
    }
  }

  private readableError(error: Object): string {
    return error instanceof AppError ? '请检查时长设置后再保存' : '设置暂时没有保存成功，请重试'
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.LG }) {
        if (this.destination === SettingsDestination.OVERVIEW) {
          this.Overview()
        } else {
          this.Detail()
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: AppBreakpoint.CONTENT_MAX })
      .padding(this.isWide ? AppSpacing.XXL : AppSpacing.LG)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private Overview() {
    Column({ space: AppSpacing.XS }) {
      Text($r('app.string.settings_title'))
        .fontSize(AppTypography.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.settings_subtitle'))
        .fontSize(AppTypography.BODY)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)

    Row({ space: AppSpacing.MD }) {
      SymbolGlyph($r('sys.symbol.leaf_fill'))
        .fontSize(30)
        .fontColor([$r('app.color.brand_primary')])
      Text($r('app.string.settings_greeting'))
        .fontSize(AppTypography.SUBTITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding(AppSpacing.XL)
    .backgroundColor($r('app.color.brand_container'))
    .borderRadius(AppRadius.LG)

    Column({ space: AppSpacing.MD }) {
      SettingRow({
        symbol: $r('sys.symbol.person_crop_circle_fill'),
        title: $r('app.string.settings_account'),
        description: $r('app.string.settings_account_desc'),
        onOpen: () => this.destination = SettingsDestination.ACCOUNT
      })
      SettingRow({
        symbol: $r('sys.symbol.timer'),
        title: $r('app.string.focus_settings'),
        description: $r('app.string.settings_focus_desc'),
        onOpen: () => this.destination = SettingsDestination.FOCUS
      })
      SettingRow({
        symbol: $r('sys.symbol.arrow_left_arrow_right'),
        title: $r('app.string.settings_sync'),
        description: $r('app.string.settings_sync_desc'),
        onOpen: () => this.destination = SettingsDestination.SYNC
      })
      SettingRow({
        symbol: $r('sys.symbol.doc_text'),
        title: $r('app.string.settings_data_privacy'),
        description: $r('app.string.settings_data_privacy_desc'),
        onOpen: () => this.destination = SettingsDestination.PRIVACY
      })
    }
    .width('100%')
  }

  @Builder
  private Detail() {
    if (this.destination === SettingsDestination.ACCOUNT) {
      this.DetailHeader($r('app.string.settings_account'), $r('app.string.settings_account_desc'))
      AccountPanel({
        isWide: this.isWide,
        onProfileChanged: () => this.profileVersion = this.profileVersion + 1
      })
    } else if (this.destination === SettingsDestination.FOCUS) {
      this.DetailHeader($r('app.string.focus_settings'), $r('app.string.settings_focus_desc'))
      this.FocusSettingsCard()
    } else if (this.destination === SettingsDestination.SYNC) {
      this.DetailHeader($r('app.string.settings_sync'), $r('app.string.settings_sync_desc'))
      SyncPanel({ profileVersion: this.profileVersion })
    } else {
      this.DetailHeader($r('app.string.settings_data_privacy'), $r('app.string.settings_data_privacy_desc'))
      DataAndPrivacyPanel()
    }
  }

  @Builder
  private DetailHeader(title: ResourceStr, subtitle: ResourceStr) {
    Row({ space: AppSpacing.MD }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(AppControl.MIN_TOUCH)
      .height(AppControl.MIN_TOUCH)
      .backgroundColor($r('app.color.surface_primary'))
      .borderRadius(AppRadius.PILL)
      .accessibilityText($r('app.string.common_back'))
      .onClick(() => this.destination = SettingsDestination.OVERVIEW)

      Column({ space: AppSpacing.XS }) {
        Text(title)
          .fontSize(AppTypography.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(subtitle)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  @Builder
  private FocusSettingsCard() {
    Column({ space: AppSpacing.LG }) {
      Text($r('app.string.settings_focus_effect_hint'))
        .width('100%')
        .fontSize(AppTypography.CAPTION)
        .fontColor($r('app.color.text_secondary'))

      if (this.errorMessage.length > 0) {
        AppStatusBanner({ message: this.errorMessage, tone: MessageTone.ERROR })
      }

      if (this.loading) {
        LoadingProgress().width(44).height(44).color($r('app.color.brand_primary'))
      } else {
        DurationRow({
          label: $r('app.string.settings_focus_duration'), description: $r('app.string.settings_focus_range'),
          value: this.config.focusMinutes, minimum: 1, maximum: 480,
          onChange: (value: number) => this.updateConfig(value)
        })
        DurationRow({
          label: $r('app.string.settings_short_break'), description: $r('app.string.settings_short_break_range'),
          value: this.config.shortBreakMinutes, minimum: 1, maximum: 120,
          onChange: (value: number) => this.updateConfig(this.config.focusMinutes, value)
        })
        DurationRow({
          label: $r('app.string.settings_long_break'), description: $r('app.string.settings_long_break_range'),
          value: this.config.longBreakMinutes, minimum: 1, maximum: 180,
          onChange: (value: number) => this.updateConfig(
            this.config.focusMinutes, this.config.shortBreakMinutes, value)
        })
        DurationRow({
          label: $r('app.string.settings_long_break_interval'),
          description: $r('app.string.settings_long_break_interval_desc'),
          value: this.config.longBreakEvery, minimum: 2, maximum: 12,
          onChange: (value: number) => this.updateConfig(
            this.config.focusMinutes, this.config.shortBreakMinutes, this.config.longBreakMinutes, value)
        })
        Divider().color($r('app.color.border_subtle'))
        AutomationRow({
          label: $r('app.string.settings_auto_break'), description: $r('app.string.settings_auto_break_desc'),
          isEnabled: this.config.autoStartBreaks,
          onChange: (value: boolean) => this.updateConfig(
            this.config.focusMinutes, this.config.shortBreakMinutes, this.config.longBreakMinutes,
            this.config.longBreakEvery, value, this.config.autoStartFocus)
        })
        AutomationRow({
          label: $r('app.string.settings_auto_focus'), description: $r('app.string.settings_auto_focus_desc'),
          isEnabled: this.config.autoStartFocus,
          onChange: (value: boolean) => this.updateConfig(
            this.config.focusMinutes, this.config.shortBreakMinutes, this.config.longBreakMinutes,
            this.config.longBreakEvery, this.config.autoStartBreaks, value)
        })
        AppActionButton({
          label: $r('app.string.settings_save_focus'),
          loadingLabel: $r('app.string.common_saving'),
          successLabel: $r('app.string.common_saved'),
          state: this.saving ? ActionState.LOADING : (this.saved ? ActionState.SUCCESS : ActionState.IDLE),
          onAction: () => this.saveConfig()
        })
      }
    }
    .width('100%')
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
    .alignItems(HorizontalAlign.Start)
  }
}
