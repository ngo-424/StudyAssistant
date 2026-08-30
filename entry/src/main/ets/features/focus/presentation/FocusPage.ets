import { common } from '@kit.AbilityKit'
import { AppError } from '../../../core/error/AppError'
import { AppBreakpoint, AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import {
  FocusPhase,
  StudyTask,
  TaskCategory,
  TimerRunState
} from '../../../domain/model/StudyModels'
import { CategoryColor } from '../../tasks/domain/CategoryColor'
import { TimerRuntimeState } from '../domain/TimerModels'
import { TimerConfigRules } from '../domain/TimerConfigRules'
import { FocusPresentation } from './FocusPresentation'
import { FocusScreenData, FocusViewModel } from './FocusViewModel'
import { FocusSystemPolicy } from '../system/FocusSystemPolicy'
import {
  CapabilityState,
  FocusSystemStatus,
  FocusSystemStatusFactory
} from '../system/FocusSystemModels'
import {
  ContinuationControlState,
  ContinuationStatus
} from '../../continuation/domain/ContinuationModels'

@Component
export struct FocusPage {
  @Prop isWide: boolean = false
  @Prop isCompact: boolean = false
  @State tasks: StudyTask[] = []
  @State categories: TaskCategory[] = []
  @State selectedTaskId: string = ''
  @State runtime: TimerRuntimeState = {
    config: TimerConfigRules.defaults(), snapshot: null, reading: null
  }
  @State loading: boolean = true
  @State actionBusy: boolean = false
  @State errorMessage: string = ''
  @State systemStatus: FocusSystemStatus = FocusSystemStatusFactory.idle()
  @State continuationStatus: ContinuationStatus = {
    state: ContinuationControlState.IDLE,
    message: '开始计时后可使用跨设备接续',
    canRetry: false,
    isController: true
  }
  private readonly viewModel: FocusViewModel = new FocusViewModel()
  private timerId: number = -1
  private tickBusy: boolean = false
  private autoTransitioning: boolean = false

  aboutToAppear(): void {
    this.load()
    if (this.timerId < 0) {
      this.timerId = setInterval(() => this.tick(), 1000)
    }
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private async load(): Promise<void> {
    this.loading = true
    try {
      const data: FocusScreenData = await this.viewModel.load()
      this.tasks = data.tasks
      this.categories = data.categories
      if (data.runtime.snapshot?.taskId !== null && data.runtime.snapshot?.taskId !== undefined) {
        this.selectedTaskId = data.runtime.snapshot.taskId
      }
      await this.applyRuntime(data.runtime, true)
      this.systemStatus = this.viewModel.systemStatus()
      this.continuationStatus = data.continuation
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.loading = false
    }
  }

  private async tick(): Promise<void> {
    if (this.tickBusy || this.runtime.snapshot === null ||
      this.runtime.snapshot.state !== TimerRunState.RUNNING) {
      return
    }
    this.tickBusy = true
    try {
      await this.applyRuntime(await this.viewModel.observe(), true)
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.tickBusy = false
    }
  }

  private async start(): Promise<void> {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.systemStatus = await this.viewModel.requestNotificationPermission(context)
    await this.runAction(async () => this.viewModel.start(this.selectedTask()))
  }

  private async pause(): Promise<void> {
    await this.runAction(async () => this.viewModel.pause())
  }

  private async resume(): Promise<void> {
    await this.runAction(async () => this.viewModel.resume())
  }

  private async finishEarly(): Promise<void> {
    await this.runAction(async () => this.viewModel.finishEarly())
  }

  private async abandon(): Promise<void> {
    await this.runAction(async () => this.viewModel.abandon())
  }

  private async startNextPhase(): Promise<void> {
    await this.runAction(async () => this.viewModel.startNextPhase())
  }

  private async dismissTerminal(): Promise<void> {
    if (this.actionBusy) {
      return
    }
    this.actionBusy = true
    try {
      await this.viewModel.dismissTerminal()
      this.runtime = { config: this.runtime.config, snapshot: null, reading: null }
      this.systemStatus = this.viewModel.systemStatus()
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.actionBusy = false
    }
  }

  private async runAction(action: () => Promise<TimerRuntimeState>): Promise<void> {
    if (this.actionBusy) {
      return
    }
    this.actionBusy = true
    try {
      await this.applyRuntime(await action(), false)
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.actionBusy = false
    }
  }

  private async applyRuntime(runtime: TimerRuntimeState, allowAutomaticStart: boolean): Promise<void> {
    this.runtime = runtime
    this.systemStatus = this.viewModel.systemStatus()
    this.continuationStatus = this.viewModel.continuationState()
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    await this.viewModel.updateContinuationAvailability(context, runtime)
    if (!allowAutomaticStart || runtime.snapshot === null || this.autoTransitioning ||
      !FocusPresentation.shouldAutoStart(runtime.snapshot.state, runtime.snapshot.terminalResult,
        runtime.snapshot.phase, runtime.config)) {
      return
    }
    this.autoTransitioning = true
    try {
      this.runtime = await this.viewModel.startNextPhase()
      this.systemStatus = this.viewModel.systemStatus()
    } finally {
      this.autoTransitioning = false
    }
  }

  private selectedTask(): StudyTask | null {
    const match: StudyTask | undefined = this.tasks.find((task: StudyTask) => task.id === this.selectedTaskId)
    return match ?? null
  }

  private linkedTask(): StudyTask | null {
    const taskId: string | null = this.runtime.snapshot?.taskId ??
      (this.selectedTaskId.length > 0 ? this.selectedTaskId : null)
    const match: StudyTask | undefined = this.tasks.find((task: StudyTask) => task.id === taskId)
    return match ?? null
  }

  private category(): TaskCategory | null {
    const categoryId: string | null = this.runtime.snapshot?.categoryId ?? this.linkedTask()?.categoryId ?? null
    const match: TaskCategory | undefined = this.categories.find((category: TaskCategory) => category.id === categoryId)
    return match ?? null
  }

  private accentColor(): string {
    return this.category()?.colorSeed ?? CategoryColor.NEUTRAL
  }

  private timeText(): string {
    if (this.runtime.reading !== null) {
      return FocusPresentation.formatSeconds(this.runtime.reading.remainingSeconds)
    }
    return FocusPresentation.formatSeconds(this.runtime.config.focusMinutes * 60)
  }

  private progressValue(): number {
    return Math.max(0, Math.min(100, (this.runtime.reading?.progress ?? 0) * 100))
  }

  private statusText(): string {
    if (this.runtime.snapshot === null) {
      return '准备开始'
    }
    return FocusPresentation.statusLabel(this.runtime.snapshot.state, this.runtime.snapshot.phase)
  }

  private phaseText(): string {
    return this.runtime.snapshot === null ? '专注' : FocusPresentation.phaseLabel(this.runtime.snapshot.phase)
  }

  private confirmFinishEarly(): void {
    this.getUIContext().showAlertDialog({
      title: '提前结束本阶段？',
      message: '本次会记录实际用时，但不会计为完整专注轮次。',
      primaryButton: { value: $r('app.string.common_cancel'), action: () => {} },
      secondaryButton: { value: '确认结束', action: () => this.finishEarly() }
    })
  }

  private confirmAbandon(): void {
    this.getUIContext().showAlertDialog({
      title: '放弃本阶段？',
      message: '本次会标记为已放弃，并保留实际经过的时间。',
      primaryButton: { value: $r('app.string.common_cancel'), action: () => {} },
      secondaryButton: {
        value: '放弃', fontColor: $r('app.color.danger'), action: () => this.abandon()
      }
    })
  }

  private readableError(error: Object): string {
    if (error instanceof AppError && error.message === 'TIMER_ALREADY_ACTIVE') {
      return '已有一个进行中的计时，请先完成当前阶段'
    }
    if (error instanceof AppError && error.message === 'TIMER_CONTROL_TRANSFERRED') {
      return '本次计时已转移到另一设备，当前设备不能继续操作'
    }
    return '计时操作没有完成，请稍后重试'
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.LG }) {
        Column({ space: AppSpacing.XS }) {
          Text($r('app.string.focus_title'))
            .fontSize(this.isCompact ? 20 : AppTypography.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          if (!this.isCompact) {
            Text($r('app.string.focus_subtitle'))
              .fontSize(AppTypography.BODY)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.errorMessage.length > 0) {
          Row({ space: AppSpacing.SM }) {
            Text('!').fontWeight(FontWeight.Bold).fontColor($r('app.color.danger'))
            Text(this.errorMessage)
              .layoutWeight(1)
              .fontSize(AppTypography.CAPTION)
              .fontColor($r('app.color.danger'))
            Button('×')
              .width(32)
              .height(32)
              .fontColor($r('app.color.danger'))
              .backgroundColor(Color.Transparent)
              .onClick(() => this.errorMessage = '')
          }
          .width('100%')
          .padding(AppSpacing.MD)
          .backgroundColor($r('app.color.danger_container'))
          .borderRadius(AppRadius.MD)
        }

        Column({ space: AppSpacing.LG }) {
          Row({ space: AppSpacing.SM }) {
            Text(this.phaseText())
              .fontSize(AppTypography.CAPTION)
              .fontWeight(FontWeight.Bold)
              .fontColor(CategoryColor.foregroundFor(this.accentColor()))
              .backgroundColor(this.accentColor())
              .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.SM, bottom: AppSpacing.SM })
              .borderRadius(AppRadius.PILL)
            Text(this.statusText())
              .fontSize(AppTypography.BODY)
              .fontColor($r('app.color.text_secondary'))
          }

          if (this.loading) {
            LoadingProgress().width(56).height(56).color($r('app.color.brand_primary'))
          } else {
            Stack({ alignContent: Alignment.Center }) {
              Progress({ value: this.progressValue(), total: 100, type: ProgressType.Ring })
                .width(this.isCompact ? 172 : (this.isWide ? 310 : 250))
                .height(this.isCompact ? 172 : (this.isWide ? 310 : 250))
                .color(this.accentColor())
                .backgroundColor($r('app.color.surface_emphasis'))
                .style({ strokeWidth: this.isCompact ? 10 : (this.isWide ? 16 : 13), enableSmoothEffect: true })
              Column({ space: AppSpacing.XS }) {
                Text(this.timeText())
                  .fontSize(this.isCompact ? 40 : (this.isWide ? 76 : AppTypography.DISPLAY))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .maxFontScale(1.5)
                Text(this.runtime.snapshot?.state === TimerRunState.PAUSED ? '保持节奏，准备好再继续' :
                  `${Math.round(this.progressValue())}%`)
                  .fontSize(AppTypography.CAPTION)
                  .fontColor($r('app.color.text_tertiary'))
              }
            }
          }

          Text(this.linkedTask()?.title ?? $r('app.string.focus_free'))
            .fontSize(AppTypography.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(CategoryColor.foregroundFor(this.accentColor()))
            .backgroundColor(this.accentColor())
            .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: AppSpacing.SM, bottom: AppSpacing.SM })
            .borderRadius(AppRadius.PILL)

          this.ActionArea()
        }
        .width('100%')
        .constraintSize({ minHeight: this.isCompact ? 330 : (this.isWide ? 520 : 460) })
        .justifyContent(FlexAlign.Center)
        .padding(this.isCompact ? AppSpacing.MD : (this.isWide ? AppSpacing.XXL : AppSpacing.XL))
        .backgroundColor($r('app.color.surface_primary'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.border_subtle') })

        this.SystemCapabilityStatus()

        this.ContinuationStatusCard()

        if (this.runtime.snapshot === null && !this.loading && !this.isCompact) {
          this.TaskPicker()
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: AppBreakpoint.CONTENT_MAX })
      .padding(this.isCompact ? AppSpacing.SM : (this.isWide ? AppSpacing.XXL : AppSpacing.LG))
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private ActionArea() {
    if (!this.continuationStatus.isController && this.runtime.snapshot !== null) {
      Button('已在另一设备继续')
        .width(this.isWide ? 280 : '100%').height(50)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_secondary'))
        .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.MD)
        .enabled(false)
    } else if (this.runtime.snapshot === null) {
      Button($r('app.string.focus_start'))
        .width(this.isWide ? 280 : '100%')
        .height(52)
        .fontWeight(FontWeight.Bold)
        .fontColor(CategoryColor.foregroundFor(this.accentColor()))
        .backgroundColor(this.accentColor())
        .borderRadius(AppRadius.MD)
        .enabled(!this.actionBusy && !this.loading)
        .onClick(() => this.start())
    } else if (this.runtime.snapshot.state === TimerRunState.RUNNING) {
      Row({ space: AppSpacing.MD }) {
        Button('暂停')
          .layoutWeight(1).height(50).fontWeight(FontWeight.Bold)
          .fontColor(CategoryColor.foregroundFor(this.accentColor()))
          .backgroundColor(this.accentColor()).borderRadius(AppRadius.MD)
          .enabled(!this.actionBusy).onClick(() => this.pause())
        Button('提前结束')
          .layoutWeight(1).height(50).fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.MD)
          .enabled(!this.actionBusy).onClick(() => this.confirmFinishEarly())
      }
      .width(this.isWide && !this.isCompact ? 520 : '100%')
      Button('放弃本阶段')
        .fontSize(AppTypography.CAPTION).fontColor($r('app.color.danger'))
        .backgroundColor(Color.Transparent).enabled(!this.actionBusy)
        .onClick(() => this.confirmAbandon())
    } else if (this.runtime.snapshot.state === TimerRunState.PAUSED) {
      Row({ space: AppSpacing.MD }) {
        Button('继续')
          .layoutWeight(1).height(50).fontWeight(FontWeight.Bold)
          .fontColor(CategoryColor.foregroundFor(this.accentColor()))
          .backgroundColor(this.accentColor()).borderRadius(AppRadius.MD)
          .enabled(!this.actionBusy).onClick(() => this.resume())
        Button('提前结束')
          .layoutWeight(1).height(50).fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.MD)
          .enabled(!this.actionBusy).onClick(() => this.confirmFinishEarly())
      }
      .width(this.isWide && !this.isCompact ? 520 : '100%')
      Button('放弃本阶段')
        .fontSize(AppTypography.CAPTION).fontColor($r('app.color.danger'))
        .backgroundColor(Color.Transparent).enabled(!this.actionBusy)
        .onClick(() => this.confirmAbandon())
    } else if (this.runtime.snapshot.state === TimerRunState.COMPLETED) {
      Row({ space: AppSpacing.MD }) {
        Button(this.runtime.snapshot.phase === FocusPhase.FOCUS ? '开始休息' : '开始下一轮专注')
          .layoutWeight(1).height(50).fontWeight(FontWeight.Bold)
          .fontColor(CategoryColor.foregroundFor(this.accentColor()))
          .backgroundColor(this.accentColor()).borderRadius(AppRadius.MD)
          .enabled(!this.actionBusy).onClick(() => this.startNextPhase())
        Button('暂不继续')
          .layoutWeight(1).height(50).fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.MD)
          .enabled(!this.actionBusy).onClick(() => this.dismissTerminal())
      }
      .width(this.isWide && !this.isCompact ? 520 : '100%')
    } else {
      Button('返回准备状态')
        .width(this.isWide ? 280 : '100%').height(50)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.MD)
        .enabled(!this.actionBusy).onClick(() => this.dismissTerminal())
    }
  }

  @Builder
  private TaskPicker() {
    Column({ space: AppSpacing.MD }) {
      Column({ space: AppSpacing.XS }) {
        Text('关联任务（可选）')
          .fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('计时开始后，本阶段会固定使用所选类别色系')
          .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').alignItems(HorizontalAlign.Start)

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        Button($r('app.string.focus_free'))
          .margin({ right: AppSpacing.SM, bottom: AppSpacing.SM })
          .fontSize(AppTypography.CAPTION)
          .fontColor(this.selectedTaskId.length === 0 ? $r('app.color.brand_on_primary') :
            $r('app.color.text_secondary'))
          .backgroundColor(this.selectedTaskId.length === 0 ? $r('app.color.brand_primary') :
            $r('app.color.surface_secondary'))
          .borderRadius(AppRadius.PILL)
          .onClick(() => this.selectedTaskId = '')
        ForEach(this.tasks, (task: StudyTask) => {
          Button(task.title)
            .margin({ right: AppSpacing.SM, bottom: AppSpacing.SM })
            .fontSize(AppTypography.CAPTION)
            .fontColor(this.selectedTaskId === task.id ? CategoryColor.foregroundFor(
              this.categories.find((category: TaskCategory) => category.id === task.categoryId)?.colorSeed ??
                CategoryColor.NEUTRAL) : $r('app.color.text_secondary'))
            .backgroundColor(this.selectedTaskId === task.id ?
              this.categories.find((category: TaskCategory) => category.id === task.categoryId)?.colorSeed ??
                CategoryColor.NEUTRAL : $r('app.color.surface_secondary'))
            .borderRadius(AppRadius.PILL)
            .onClick(() => this.selectedTaskId = task.id)
        }, (task: StudyTask) => `${task.id}-${task.updatedAt}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }

  @Builder
  private SystemCapabilityStatus() {
    Row({ space: AppSpacing.SM }) {
      Text(this.systemStatus.reminder === CapabilityState.READY &&
        this.systemStatus.liveView === CapabilityState.READY ? '✓' : 'i')
        .width(28).height(28).textAlign(TextAlign.Center)
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.brand_container'))
        .borderRadius(AppRadius.PILL)
      Text(FocusSystemPolicy.summary(this.systemStatus))
        .layoutWeight(1).fontSize(AppTypography.CAPTION)
        .fontColor($r('app.color.text_secondary'))
      if (this.systemStatus.notification !== CapabilityState.READY &&
        this.runtime.snapshot === null) {
        Text('开始时询问')
          .fontSize(AppTypography.CAPTION).fontColor($r('app.color.brand_primary'))
      }
    }
    .width('100%').padding(AppSpacing.MD)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }

  @Builder
  private ContinuationStatusCard() {
    Row({ space: AppSpacing.SM }) {
      Text(this.continuationStatus.state === ContinuationControlState.TRANSFERRED ? '✓' : '⇄')
        .width(28).height(28).textAlign(TextAlign.Center)
        .fontColor(this.continuationStatus.state === ContinuationControlState.OFFLINE ||
          this.continuationStatus.state === ContinuationControlState.FAILED ?
          $r('app.color.text_secondary') : $r('app.color.brand_primary'))
        .backgroundColor($r('app.color.brand_container'))
        .borderRadius(AppRadius.PILL)
      Column({ space: 2 }) {
        Text('跨设备接续')
          .fontSize(AppTypography.CAPTION).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.continuationStatus.message)
          .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.continuationStatus.canRetry) {
        Button('重试')
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor(Color.Transparent)
          .onClick(async () => {
            await this.viewModel.retryContinuation()
            await this.load()
          })
      }
    }
    .width('100%').padding(AppSpacing.MD)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}
