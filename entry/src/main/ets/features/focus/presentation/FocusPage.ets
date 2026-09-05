import { common } from '@kit.AbilityKit'
import { AppError } from '../../../core/error/AppError'
import { HapticFeedbackService } from '../../../core/haptics/HapticFeedbackService'
import { AppBreakpoint, AppControl, AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { AppStatusBanner, MessageTone } from '../../../shared/components/AppFeedback'
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
import { FocusOperationQueue } from './FocusOperationQueue'
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
  @Prop @Watch('onForegroundRevisionChanged') foregroundRevision: number = 0
  onImmersiveChange: (immersive: boolean) => void = () => {}
  onActiveChange: (active: boolean) => void = () => {}
  @State viewportHeight: number = 0
  @State viewportWidth: number = 360
  @State transferredViewDismissed: boolean = false
  @State showAbandonReasonDialog: boolean = false
  @State abandonReason: string = ''
  @State tasks: StudyTask[] = []
  @State categories: TaskCategory[] = []
  @State selectedTaskId: string = ''
  @State runtime: TimerRuntimeState = {
    config: TimerConfigRules.defaults(), snapshot: null, reading: null
  }
  @State loading: boolean = true
  @State actionBusy: boolean = false
  @State errorMessage: string = ''
  @State actionMessage: string = ''
  @State systemStatus: FocusSystemStatus = FocusSystemStatusFactory.idle()
  @State continuationStatus: ContinuationStatus = {
    state: ContinuationControlState.IDLE,
    message: '开始计时后可使用跨设备接续',
    canRetry: false,
    isController: true
  }
  private readonly viewModel: FocusViewModel = new FocusViewModel()
  private readonly operations: FocusOperationQueue = new FocusOperationQueue()
  private mounted: boolean = false
  private refreshPending: boolean = false
  private timerId: number = -1
  private tickBusy: boolean = false
  private autoTransitioning: boolean = false

  aboutToAppear(): void {
    this.mounted = true
    this.refresh()
    if (this.timerId < 0) {
      this.timerId = setInterval(() => this.tick(), 1000)
    }
  }

  aboutToDisappear(): void {
    this.mounted = false
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private onForegroundRevisionChanged(): void {
    this.refresh()
  }

  private async refresh(): Promise<void> {
    if (!this.mounted || this.refreshPending) {
      return
    }
    this.refreshPending = true
    try {
      await this.operations.run(async () => {
        while (this.mounted) {
          const revision: number = this.foregroundRevision
          await this.load()
          if (revision === this.foregroundRevision) {
            break
          }
        }
      })
    } finally {
      this.refreshPending = false
    }
  }

  private isImmersive(): boolean {
    return FocusPresentation.isImmersive(this.runtime.snapshot?.state ?? null) && !this.transferredViewDismissed
  }

  private notifyPresentation(): void {
    if (this.mounted && !this.loading) {
      this.onImmersiveChange(this.isImmersive())
      this.onActiveChange(this.continuationStatus.isController &&
        FocusPresentation.isActive(this.runtime.snapshot?.state ?? null))
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
      this.errorMessage = ''
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.loading = false
      this.notifyPresentation()
    }
  }

  private async tick(): Promise<void> {
    if (!this.mounted || this.tickBusy || this.actionBusy || this.refreshPending || this.runtime.snapshot === null ||
      this.runtime.snapshot.state !== TimerRunState.RUNNING) {
      return
    }
    this.tickBusy = true
    try {
      await this.operations.run(async () => {
        if (this.mounted && this.runtime.snapshot?.state === TimerRunState.RUNNING) {
          await this.applyRuntime(await this.viewModel.observe(), true)
        }
      })
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.tickBusy = false
    }
  }

  private async start(): Promise<void> {
    if (await this.runAction(async () => {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      this.systemStatus = await this.viewModel.requestNotificationPermission(context)
      return this.viewModel.start(this.selectedTask())
    }, '专注已开始')) {
      await HapticFeedbackService.touch()
    }
  }

  private async pause(): Promise<void> {
    await this.runAction(async () => this.viewModel.pause(), '计时已暂停')
  }

  private async resume(): Promise<void> {
    await this.runAction(async () => this.viewModel.resume(), '继续保持现在的节奏')
  }

  private async finishEarlyAndContinue(): Promise<void> {
    const phase: FocusPhase | null = this.runtime.snapshot?.phase ?? null
    if (phase === FocusPhase.FOCUS) {
      const finished: boolean = await this.runAction(async () => this.viewModel.finishEarly(), '')
      if (finished && this.runtime.snapshot?.state === TimerRunState.COMPLETED) {
        await this.runAction(async () => this.viewModel.startNextPhase(), '已自动开始休息')
      }
      return
    }
    this.confirmBreakFinish()
  }

  private openAbandonReason(): void {
    this.abandonReason = ''
    this.showAbandonReasonDialog = true
  }

  private async abandon(): Promise<void> {
    const phaseSessionId: string = this.runtime.snapshot?.phaseSessionId ?? ''
    if (await this.runAction(async () => this.viewModel.abandon(), '本次计时已放弃')) {
      try {
        await this.viewModel.saveAbandonReason(phaseSessionId, this.abandonReason)
      } catch (_error) {
        this.errorMessage = '放弃理由保存失败，但本次计时已结束'
      }
      this.showAbandonReasonDialog = false
      await HapticFeedbackService.success()
      await this.dismissTerminal()
    }
  }

  private async startNextPhase(): Promise<void> {
    await this.runAction(async () => this.viewModel.startNextPhase(), '下一阶段已开始')
  }

  private async dismissTerminal(): Promise<void> {
    if (this.actionBusy || this.loading) {
      return
    }
    this.actionBusy = true
    try {
      await this.operations.run(async () => {
        await this.viewModel.dismissTerminal()
        await this.applyRuntime({ config: this.runtime.config, snapshot: null, reading: null }, false)
      })
      this.errorMessage = ''
      this.actionMessage = '已回到准备状态'
    } catch (error) {
      this.errorMessage = this.readableError(error)
    } finally {
      this.actionBusy = false
    }
  }

  private async runAction(action: () => Promise<TimerRuntimeState>, successMessage: string): Promise<boolean> {
    if (this.actionBusy || this.loading) {
      return false
    }
    this.actionBusy = true
    try {
      await this.operations.run(async () => this.applyRuntime(await action(), false))
      this.errorMessage = ''
      this.actionMessage = successMessage
      return true
    } catch (error) {
      this.errorMessage = this.readableError(error)
      this.actionMessage = ''
      return false
    } finally {
      this.actionBusy = false
    }
  }

  private async applyRuntime(runtime: TimerRuntimeState, allowAutomaticStart: boolean): Promise<void> {
    const previousState: TimerRunState | null = this.runtime.snapshot?.state ?? null
    this.runtime = runtime
    this.systemStatus = this.viewModel.systemStatus()
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    await this.viewModel.updateContinuationAvailability(context, runtime)
    this.continuationStatus = this.viewModel.continuationState()
    if (this.continuationStatus.isController) {
      this.transferredViewDismissed = false
    }
    this.notifyPresentation()
    if (runtime.snapshot?.state === TimerRunState.COMPLETED && previousState !== TimerRunState.COMPLETED) {
      await HapticFeedbackService.success()
    }
    if (!allowAutomaticStart || !this.continuationStatus.isController || runtime.snapshot === null || this.autoTransitioning ||
      !FocusPresentation.shouldAutoStart(runtime.snapshot.state, runtime.snapshot.terminalResult,
        runtime.snapshot.phase, runtime.config)) {
      return
    }
    this.autoTransitioning = true
    try {
      await this.applyRuntime(await this.viewModel.startNextPhase(), false)
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

  private shouldShowSystemStatus(): boolean {
    return this.runtime.snapshot !== null && (this.systemStatus.notification !== CapabilityState.READY ||
      this.systemStatus.reminder !== CapabilityState.READY || this.systemStatus.liveView !== CapabilityState.READY)
  }

  private shouldShowContinuationStatus(): boolean {
    return this.runtime.snapshot !== null || this.continuationStatus.state !== ContinuationControlState.IDLE
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

  private requestEarlyFinish(): void {
    if (this.actionBusy || this.loading) {
      return
    }
    const isFocus: boolean = this.runtime.snapshot?.phase === FocusPhase.FOCUS
    if (!isFocus) {
      this.confirmBreakFinish()
      return
    }
    this.getUIContext().showAlertDialog({
      title: '提前结束计时',
      message: '可选择放弃或者提前完成计时，当前计时会立刻停止并自动开始休息。',
      buttonDirection: DialogButtonDirection.VERTICAL,
      buttons: [
        { value: '放弃本次计时（不记录时长）', fontColor: $r('app.color.text_secondary'), action: () => this.openAbandonReason() },
        { value: '提前完成并记录已有时长', action: () => this.finishEarlyAndContinue() },
        { value: '取消', action: () => {} }
      ]
    })
  }

  private confirmBreakFinish(): void {
    this.getUIContext().showAlertDialog({
      title: '退出休息？',
      message: '是否退出休息并返回首页？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确定', action: () => this.finishBreakAndReturn() }
    })
  }

  private async finishBreakAndReturn(): Promise<void> {
    if (await this.runAction(async () => this.viewModel.finishEarly(), '')) {
      await this.dismissTerminal()
    }
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
    Stack() {
      if (this.isImmersive()) {
        this.ImmersiveContent()
      } else {
        this.PreparationContent()
      }
      if (this.showAbandonReasonDialog) {
        this.AbandonReasonDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isImmersive() ? $r('app.color.surface_tinted') : $r('app.color.app_background'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.viewportHeight = Number(newArea.height)
      this.viewportWidth = Number(newArea.width)
    })
  }

  private immersiveLabel(): string {
    if (!this.continuationStatus.isController) {
      return '已在另一设备继续'
    }
    const snapshot = this.runtime.snapshot
    return snapshot === null ? '' :
      FocusPresentation.immersiveLabel(snapshot.state, snapshot.phase, snapshot.terminalResult)
  }

  private ringSize(): number {
    return Math.min(this.isCompact ? 172 : (this.isWide ? 310 : 280), Math.max(120, this.viewportWidth - 48))
  }

  @Builder
  private TimerDigits() {
    Text(this.timeText())
      .fontSize(this.isCompact ? 40 : (this.isWide ? 76 : AppTypography.DISPLAY))
      .minFontSize(this.isCompact ? 28 : 40)
      .maxFontSize(this.isCompact ? 40 : (this.isWide ? 76 : AppTypography.DISPLAY))
      .maxLines(1)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .textAlign(TextAlign.Center)
      .width('100%')
      .maxFontScale(1.5)
  }

  @Builder
  private ImmersiveContent() {
    Scroll() {
      Column({ space: this.isCompact ? AppSpacing.MD : AppSpacing.XL }) {
        Text(this.immersiveLabel())
          .fontSize(AppTypography.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .width('100%')

        if (this.errorMessage.length > 0) {
          AppStatusBanner({ message: this.errorMessage, tone: MessageTone.ERROR })
        }

        if (FocusPresentation.showImmersiveDetails(this.viewportHeight)) {
          Stack({ alignContent: Alignment.Center }) {
            Progress({ value: this.progressValue(), total: 100, type: ProgressType.Ring })
              .width(this.ringSize()).height(this.ringSize())
              .color(this.accentColor())
              .backgroundColor($r('app.color.surface_emphasis'))
              .style({ strokeWidth: this.isCompact ? 8 : 12, enableSmoothEffect: true })
            Column() {
              this.TimerDigits()
            }
            .width(this.ringSize() - 40)
          }
          Text(this.linkedTask()?.title ?? $r('app.string.focus_free'))
            .fontSize(AppTypography.BODY)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        } else {
          this.TimerDigits()
        }

        Column({ space: AppSpacing.SM }) {
          this.ActionArea()
        }
        .width('100%')
        .constraintSize({ maxWidth: 320 })
      }
      .width('100%')
      .constraintSize({ minHeight: this.viewportHeight, maxWidth: 600 })
      .justifyContent(FlexAlign.Center)
      .padding(this.isCompact ? AppSpacing.MD : AppSpacing.XL)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private PreparationContent() {
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
          AppStatusBanner({ message: this.errorMessage, tone: MessageTone.ERROR })
        } else if (this.actionMessage.length > 0) {
          AppStatusBanner({ message: this.actionMessage, tone: MessageTone.SUCCESS })
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
        .backgroundColor($r('app.color.surface_tinted'))
        .borderRadius(AppRadius.LG)
        .border({ width: 1, color: $r('app.color.border_subtle') })

        if (this.shouldShowSystemStatus()) {
          this.SystemCapabilityStatus()
        }

        if (this.shouldShowContinuationStatus()) {
          this.ContinuationStatusCard()
        }

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
      Text('当前设备无法操作这次计时，可在另一设备继续。')
        .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Button(this.loading ? '正在检查' : '重新检查')
        .width('100%').height(AppControl.PRIMARY_HEIGHT)
        .fontColor($r('app.color.text_secondary')).backgroundColor($r('app.color.surface_secondary'))
        .borderRadius(AppRadius.MD).enabled(!this.actionBusy && !this.loading)
        .onClick(() => this.refresh())
      if (!this.transferredViewDismissed) {
        Button('返回主界面')
          .width('100%').height(AppControl.MIN_TOUCH)
          .fontColor($r('app.color.text_secondary')).backgroundColor(Color.Transparent)
          .onClick(() => {
            this.transferredViewDismissed = true
            this.notifyPresentation()
          })
      }
    } else if (this.runtime.snapshot === null) {
      Button(this.actionBusy ? $r('app.string.focus_starting') : $r('app.string.focus_start'))
        .width(this.isWide ? 280 : '100%')
        .height(AppControl.PRIMARY_HEIGHT)
        .fontWeight(FontWeight.Bold)
        .fontColor(CategoryColor.foregroundFor(this.accentColor()))
        .backgroundColor(this.accentColor())
        .borderRadius(AppRadius.MD)
        .enabled(!this.actionBusy && !this.loading)
        .onClick(() => this.start())
    } else if (this.runtime.snapshot.state === TimerRunState.RUNNING ||
      this.runtime.snapshot.state === TimerRunState.PAUSED) {
      Row({ space: AppSpacing.LG }) {
        Button() {
          SymbolGlyph(this.runtime.snapshot?.state === TimerRunState.RUNNING ?
            $r('sys.symbol.pause') : $r('sys.symbol.play'))
            .fontSize(24)
            .fontColor([CategoryColor.foregroundFor(this.accentColor())])
        }
          .width(72).height(56)
          .backgroundColor(this.accentColor()).borderRadius(AppRadius.MD)
          .enabled(!this.actionBusy && !this.loading)
          .accessibilityText(this.runtime.snapshot.state === TimerRunState.RUNNING ? '暂停' : '继续')
          .onClick(() => this.runtime.snapshot?.state === TimerRunState.RUNNING ? this.pause() : this.resume())
        Button() {
          SymbolGlyph($r('sys.symbol.square_fill'))
            .fontSize(24)
            .fontColor([$r('app.color.text_secondary')])
        }
          .width(72).height(56)
          .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.MD)
          .enabled(!this.actionBusy && !this.loading)
          .accessibilityText('退出')
          .onClick(() => this.requestEarlyFinish())
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
    } else if (this.runtime.snapshot.state === TimerRunState.COMPLETED) {
      Button(this.runtime.snapshot.phase === FocusPhase.FOCUS ? '开始休息' : '开始下一轮专注')
        .width('100%').height(AppControl.PRIMARY_HEIGHT).fontWeight(FontWeight.Bold)
        .fontColor(CategoryColor.foregroundFor(this.accentColor()))
        .backgroundColor(this.accentColor()).borderRadius(AppRadius.MD)
        .enabled(!this.actionBusy && !this.loading).onClick(() => this.startNextPhase())
      Button('返回准备页')
        .width('100%').height(AppControl.MIN_TOUCH).fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent).borderRadius(AppRadius.MD)
        .enabled(!this.actionBusy && !this.loading).onClick(() => this.dismissTerminal())
    } else {
      Button('返回准备状态')
        .width(this.isWide ? 280 : '100%').height(AppControl.PRIMARY_HEIGHT)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.MD)
        .enabled(!this.actionBusy && !this.loading).onClick(() => this.dismissTerminal())
    }
  }

  @Builder
  private TaskPicker() {
    Column({ space: AppSpacing.MD }) {
      Column({ space: AppSpacing.XS }) {
        Text('关联任务（可选）')
          .fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('专注记录会归入所选任务，之后也可以在数据中查看')
          .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').alignItems(HorizontalAlign.Start)

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        Button($r('app.string.focus_free'))
          .height(AppControl.MIN_TOUCH)
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
            .height(AppControl.MIN_TOUCH)
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
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(22).fontColor([$r('app.color.brand_primary')])
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
  private AbandonReasonDialog() {
    Column() {
      Column({ space: AppSpacing.MD }) {
        Text('放弃本次计时')
          .fontSize(AppTypography.SUBTITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('本次不会记录专注时长。填写理由有助于之后分析专注中断的原因（可选）。')
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        TextArea({ text: this.abandonReason, placeholder: '例如：临时有事、状态不佳……' })
          .width('100%')
          .height(120)
          .maxLength(240)
          .fontSize(AppTypography.BODY)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM)
          .onChange((value: string) => this.abandonReason = value)
        Row({ space: AppSpacing.MD }) {
          Button('取消')
            .layoutWeight(1).height(AppControl.MIN_TOUCH)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(AppRadius.MD)
            .enabled(!this.actionBusy)
            .onClick(() => this.showAbandonReasonDialog = false)
          Button('确认放弃')
            .layoutWeight(1).height(AppControl.MIN_TOUCH)
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.danger'))
            .borderRadius(AppRadius.MD)
            .enabled(!this.actionBusy)
            .onClick(() => this.abandon())
        }
        .width('100%')
      }
      .width('88%')
      .padding(AppSpacing.XL)
      .backgroundColor($r('app.color.surface_primary'))
      .borderRadius(AppRadius.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ContinuationStatusCard() {
    Row({ space: AppSpacing.SM }) {
      SymbolGlyph(this.continuationStatus.state === ContinuationControlState.TRANSFERRED ?
        $r('sys.symbol.checkmark_circle') : $r('sys.symbol.arrow_left_arrow_right'))
        .fontSize(22)
        .fontColor([this.continuationStatus.state === ContinuationControlState.OFFLINE ||
          this.continuationStatus.state === ContinuationControlState.FAILED ?
          $r('app.color.text_secondary') : $r('app.color.brand_primary')])
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
          .height(AppControl.MIN_TOUCH)
          .fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor(Color.Transparent)
          .enabled(!this.actionBusy && !this.loading)
          .onClick(() => this.refresh())
      }
    }
    .width('100%').padding(AppSpacing.MD)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.MD)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}
