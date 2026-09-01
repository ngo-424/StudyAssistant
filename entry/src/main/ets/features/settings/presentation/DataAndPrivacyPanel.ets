import { common } from '@kit.AbilityKit'
import { AppControl, AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { HapticFeedbackService } from '../../../core/haptics/HapticFeedbackService'
import { AppStatusBanner, MessageTone } from '../../../shared/components/AppFeedback'
import { DataManagementService } from '../application/DataManagementService'

@Component
export struct DataAndPrivacyPanel {
  onOpenPrivacy: () => void = () => {}
  onOpenAgreement: () => void = () => {}
  @State exporting: boolean = false
  @State message: string = ''
  @State errorMessage: string = ''
  private readonly dataManagement: DataManagementService = new DataManagementService()

  private async exportData(): Promise<void> {
    if (this.exporting) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (context === undefined || context === null) {
      this.errorMessage = '当前窗口无法打开文件保存页面'
      return
    }
    this.exporting = true
    try {
      await this.dataManagement.exportToUserFile(context)
      this.message = '数据已导出为 JSON 文件，不包含登录令牌和设备标识'
      this.errorMessage = ''
      await HapticFeedbackService.success()
    } catch (error) {
      this.errorMessage = '未完成数据导出，请重新选择保存位置'
      this.message = ''
    } finally {
      this.exporting = false
    }
  }

  build() {
    Column({ space: AppSpacing.MD }) {
      Row({ space: AppSpacing.MD }) {
        SymbolGlyph($r('sys.symbol.doc_text')).fontSize(30)
          .fontColor([$r('app.color.brand_primary')])
        Column({ space: AppSpacing.XS }) {
          Text('数据与隐私').fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('导出当前数据，查看协议和数据处理说明').fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Button(this.exporting ? '正在准备导出' : '导出我的数据')
        .width('100%').height(AppControl.PRIMARY_HEIGHT).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.brand_container'))
        .borderRadius(AppRadius.SM).enabled(!this.exporting).onClick(() => this.exportData())

      Row({ space: AppSpacing.MD }) {
        Button('隐私政策').layoutWeight(1).height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM).onClick(this.onOpenPrivacy)
        Button('用户协议').layoutWeight(1).height(AppControl.MIN_TOUCH).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM).onClick(this.onOpenAgreement)
      }
      .width('100%')

      Text('游客数据仅保存在本机；登录后由你决定是否同步。账号注销和本机数据删除入口位于“账号”页面。')
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_tertiary'))
      if (this.errorMessage.length > 0) {
        AppStatusBanner({ message: this.errorMessage, tone: MessageTone.ERROR })
      } else if (this.message.length > 0) {
        AppStatusBanner({ message: this.message, tone: MessageTone.SUCCESS })
      }
    }
    .width('100%').padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}
