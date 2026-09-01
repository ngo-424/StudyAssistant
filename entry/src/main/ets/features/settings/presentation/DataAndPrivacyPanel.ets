import { common } from '@kit.AbilityKit'
import { AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'
import { DataManagementService } from '../application/DataManagementService'
import {
  PRIVACY_POLICY,
  PRIVACY_POLICY_TITLE,
  USER_AGREEMENT,
  USER_AGREEMENT_TITLE
} from '../domain/LegalDocuments'

@Component
export struct DataAndPrivacyPanel {
  @State exporting: boolean = false
  @State message: string = ''
  @State errorMessage: string = ''
  private readonly dataManagement: DataManagementService = new DataManagementService()

  private showDocument(title: string, message: string): void {
    this.getUIContext().showAlertDialog({
      title: title,
      message: message,
      autoCancel: true,
      confirm: { value: '我知道了', action: () => {} }
    })
  }

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
        Text('▤').width(42).height(42).fontSize(18).textAlign(TextAlign.Center)
          .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.brand_container'))
          .borderRadius(AppRadius.SM)
        Column({ space: AppSpacing.XS }) {
          Text('数据与隐私').fontSize(AppTypography.BODY).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('导出当前档案，查看协议和数据处理说明').fontSize(AppTypography.CAPTION)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Button(this.exporting ? '正在准备导出' : '导出我的数据')
        .width('100%').height(44).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.brand_container'))
        .borderRadius(AppRadius.SM).enabled(!this.exporting).onClick(() => this.exportData())

      Row({ space: AppSpacing.MD }) {
        Button('隐私政策').layoutWeight(1).height(42).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM).onClick(() => this.showDocument(PRIVACY_POLICY_TITLE, PRIVACY_POLICY))
        Button('用户协议').layoutWeight(1).height(42).fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(AppRadius.SM).onClick(() => this.showDocument(USER_AGREEMENT_TITLE, USER_AGREEMENT))
      }
      .width('100%')

      Text('游客数据仅保存在本机；登录后由你决定是否同步。账号注销和游客档案删除入口位于上方账号卡片。')
        .width('100%').fontSize(AppTypography.CAPTION).fontColor($r('app.color.text_tertiary'))
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage).width('100%').fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.danger')).padding(AppSpacing.SM)
          .backgroundColor($r('app.color.danger_container')).borderRadius(AppRadius.SM)
      } else if (this.message.length > 0) {
        Text(this.message).width('100%').fontSize(AppTypography.CAPTION)
          .fontColor($r('app.color.brand_primary')).padding(AppSpacing.SM)
          .backgroundColor($r('app.color.brand_container')).borderRadius(AppRadius.SM)
      }
    }
    .width('100%').padding(AppSpacing.LG)
    .backgroundColor($r('app.color.surface_primary')).borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }
}
