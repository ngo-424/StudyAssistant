import { AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { SyncConflict, SyncStatus } from '../../../domain/model/StudyModels'
import { ProfileContext } from '../application/ProfileContext'
import { SyncScreenData, SyncViewModel } from './SyncViewModel'

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
    } catch (error) {
      const data: SyncScreenData = await this.viewModel.load()
      this.apply(data)
      this.status.offline = true
      this.status.errorMessage = '当前离线或服务暂不可用，变更已安全保留，将在下次同步时重试'
    } finally {
      this.status.syncing = false
      this.working = false
    }
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
      this.status.errorMessage = useCloud ? '已采用云端版本' : '已保留本机版本，将在下次同步上传'
    } catch (error) {
      this.status.errorMessage = '冲突处理失败，请稍后重试'
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
      Text('发现多设备修改冲突').width('100%').fontSize(AppTypography.BODY)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
      Text(`${conflict.entityType} · ${conflict.entityId.slice(0, 8)}…`)
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      Text('本机和云端内容均已保留，请明确选择要继续使用的版本。')
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
      Row({ space: AppSpacing.MD }) {
        Button('采用云端').layoutWeight(1).height(40).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.resolve(conflict, true))
        Button('保留本机').layoutWeight(1).height(40).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
          .borderRadius(AppRadius.SM).enabled(!this.working).onClick(() => this.resolve(conflict, false))
      }
      .width('100%')
    }
    .width('100%').padding(AppSpacing.MD).backgroundColor($r('app.color.danger_container'))
    .borderRadius(AppRadius.SM)
  }

  build() {
    Column({ space: AppSpacing.MD }) {
      Row({ space: AppSpacing.MD }) {
        Text('⇄').width(42).height(42).fontSize(18).textAlign(TextAlign.Center)
          .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.brand_container'))
          .borderRadius(AppRadius.SM)
        Column({ space: AppSpacing.XS }) {
          Text('多设备同步').fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.isGuest ? '游客模式完全离线，不会上传数据' : this.lastSyncText())
            .fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(this.isGuest ? '刷新' : (this.working ? '同步中' : '立即同步')).height(40)
          .fontSize(AppTypography.CAPTION).fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary')).borderRadius(AppRadius.SM)
          .enabled(!this.working).onClick(() => this.isGuest ? this.load() : this.synchronize())
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
        Text(this.status.errorMessage).width('100%').fontSize(AppTypography.CAPTION)
          .fontColor(this.status.offline ? $r('app.color.text_secondary') : $r('app.color.danger'))
          .padding(AppSpacing.MD).backgroundColor($r('app.color.surface_secondary')).borderRadius(AppRadius.SM)
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
