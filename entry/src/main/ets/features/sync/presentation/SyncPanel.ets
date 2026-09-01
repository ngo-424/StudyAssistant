import { AppControl, AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { HapticFeedbackService } from '../../../core/haptics/HapticFeedbackService'
import { AppStatusBanner, MessageTone } from '../../../shared/components/AppFeedback'
import { SyncConflict, SyncStatus } from '../../../domain/model/StudyModels'
import { ProfileContext } from '../application/ProfileContext'
import { SyncScreenData, SyncViewModel } from './SyncViewModel'
import { SyncConflictPresentation, SyncConflictVersionDisplay } from './SyncConflictPresentation'

@Component
struct ConflictVersionCard {
  @Prop label: string
  @Prop version: SyncConflictVersionDisplay

  build() {
    Column({ space: AppSpacing.XS }) {
      Text(this.label).fontSize(AppTypography.CAPTION).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
      Text(this.version.name).fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).maxLines(2)
      Text(this.version.content).fontSize(AppTypography.CAPTION)
        .fontColor($r('app.color.text_secondary')).maxLines(3)
      Text(this.version.modifiedText).fontSize(AppTypography.CAPTION)
        .fontColor($r('app.color.text_tertiary'))
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Start).padding(AppSpacing.MD)
    .backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.SM)
  }
}

@Component
export struct SyncPanel {
  @Prop @Watch('profileChanged') profileVersion: number = 0
  @State isGuest: boolean = true
  @State working: boolean = false
  @State status: SyncStatus = {
    syncing: false, offline: false, pendingCount: 0, conflictCount: 0,
    lastSyncedAt: null, errorMessage: ''
  }
  @State conflicts: SyncConflict[] = []
  @State message: string = ''
  private readonly viewModel: SyncViewModel = new SyncViewModel()

  aboutToAppear(): void {
    this.load()
  }

  private profileChanged(): void {
    this.load()
  }

  private async load(): Promise<void> {
    this.isGuest = ProfileContext.isGuest()
    if (this.isGuest) {
      return
    }
    try {
      this.apply(await this.viewModel.load())
    } catch (error) {
      this.status.errorMessage = '同步状态读取失败'
    }
  }

  private async synchronize(): Promise<void> {
    if (this.working) {
      return
    }
    this.isGuest = ProfileContext.isGuest()
    if (this.isGuest) {
      return
    }
    this.working = true
    this.status.syncing = true
    try {
      this.apply(await this.viewModel.synchronize())
      this.status.offline = false
      this.status.errorMessage = ''
      this.message = '已与云端保持一致'
    } catch (error) {
      const data: SyncScreenData = await this.viewModel.load()
      this.apply(data)
      this.status.offline = true
      this.status.errorMessage = '当前离线或服务暂不可用，变更已安全保留，将在下次同步时重试'
      this.message = ''
    } finally {
      this.status.syncing = false
      this.working = false
    }
  }

  private confirmResolve(conflict: SyncConflict, useCloud: boolean): void {
    if (!SyncConflictPresentation.map(conflict).previewable) {
      return
    }
    const choice: string = useCloud ? '云端内容' : '本机内容'
    this.getUIContext().showAlertDialog({
      title: `确定使用${choice}？`,
      message: `另一份内容不会继续使用。确认前请再次比较名称、内容和修改时间。`,
      primaryButton: { value: '再看看', action: () => {} },
      secondaryButton: { value: `使用${choice}`, action: () => this.resolve(conflict, useCloud) }
    })
  }

  private async resolve(conflict: SyncConflict, useCloud: boolean): Promise<void> {
    if (this.working) {
      return
    }
    this.working = true
    try {
      const data: SyncScreenData = useCloud ?
        await this.viewModel.resolveUsingCloud(conflict) : await this.viewModel.resolveUsingLocal(conflict)
      this.apply(data)
      this.status.errorMessage = ''
      this.message = useCloud ? '已采用云端内容' : '已保留本机内容，稍后会同步到云端'
      await HapticFeedbackService.success()
    } catch (error) {
      this.status.errorMessage = '冲突处理失败，请稍后重试'
      this.message = ''
    } finally {
      this.working = false
    }
  }

  private apply(data: SyncScreenData): void {
    this.status = data.status
    this.conflicts = data.conflicts
  }

  private lastSyncText(): string {
    if (this.status.lastSyncedAt === null) {
      return '尚未完成同步'
    }
    const date: Date = new Date(this.status.lastSyncedAt)
    return `上次同步 ${date.getMonth() + 1}月${date.getDate()}日 ${this.two(date.getHours())}:${this.two(date.getMinutes())}`
  }

  private two(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  @Builder
  private ConflictCard(conflict: SyncConflict) {
    Column({ space: AppSpacing.SM }) {
      Text(SyncConflictPresentation.map(conflict).title).width('100%').fontSize(AppTypography.BODY)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
      Text('本机和云端内容都已安全保留，请比较后选择继续使用哪一份。')
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      Row({ space: AppSpacing.SM }) {
        ConflictVersionCard({ label: '本机内容', version: SyncConflictPresentation.map(conflict).local })
        ConflictVersionCard({ label: '云端内容', version: SyncConflictPresentation.map(conflict).cloud })
      }
      .width('100%')
      if (SyncConflictPresentation.map(conflict).previewable) {
        Row({ space: AppSpacing.MD }) {
          Button('使用云端内容').layoutWeight(1).height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(AppRadius.SM).enabled(!this.working)
            .onClick(() => this.confirmResolve(conflict, true))
          Button('保留本机内容').layoutWeight(1).height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
            .borderRadius(AppRadius.SM).enabled(!this.working)
            .onClick(() => this.confirmResolve(conflict, false))
        }
        .width('100%')
      } else {
        AppStatusBanner({ message: '暂时无法安全读取这两份内容，已禁止覆盖。请稍后重试同步。', tone: MessageTone.WARNING })
      }
    }
    .width('100%').padding(AppSpacing.MD).backgroundColor($r('app.color.danger_container'))
    .borderRadius(AppRadius.SM)
  }

  build() {
    Column({ space: AppSpacing.MD }) {
      Row({ space: AppSpacing.MD }) {
        SymbolGlyph($r('sys.symbol.arrow_left_arrow_right')).fontSize(30)
          .fontColor([$r('app.color.brand_primary')])
        Column({ space: AppSpacing.XS }) {
          Text('多设备同步').fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.isGuest ? '游客模式完全离线，不会上传数据' : this.lastSyncText())
            .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (!this.isGuest) {
          Button(this.working ? '正在同步' : '立即同步').height(AppControl.MIN_TOUCH)
            .fontSize(AppTypography.CAPTION).fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary')).borderRadius(AppRadius.SM)
            .enabled(!this.working).onClick(() => this.synchronize())
        }
      }
      .width('100%')

      if (!this.isGuest) {
        Row({ space: AppSpacing.MD }) {
          Text(`${this.status.pendingCount} 项待同步`).layoutWeight(1).fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
          Text(`${this.status.conflictCount} 项待处理`).layoutWeight(1).fontSize(AppTypography.CAPTION)
            .fontColor(this.status.conflictCount > 0 ? $r('app.color.danger') : $r('app.color.text_secondary'))
            .textAlign(TextAlign.End)
        }
        .width('100%')
      }

      if (this.status.errorMessage.length > 0) {
        AppStatusBanner({
          message: this.status.errorMessage,
          tone: this.status.offline ? MessageTone.WARNING : MessageTone.ERROR
        })
      } else if (this.message.length > 0) {
        AppStatusBanner({ message: this.message, tone: MessageTone.SUCCESS })
      }

      ForEach(this.conflicts, (conflict: SyncConflict) => {
        this.ConflictCard(conflict)
      }, (conflict: SyncConflict) => conflict.id)
    }
    .width('100%').padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}
