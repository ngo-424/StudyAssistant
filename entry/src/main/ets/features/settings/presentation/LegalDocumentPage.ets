import { AppRadius, AppSpacing, AppTypography } from '../../../core/design/DesignTokens'

@Component
export struct LegalDocumentPage {
  @Prop content: string

  build() {
    Column() {
      Text(this.content)
        .width('100%')
        .fontSize(AppTypography.BODY)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(26)
        .textAlign(TextAlign.Start)
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .padding(AppSpacing.XL)
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(AppRadius.LG)
    .border({ width: 1, color: $r('app.color.border_subtle') })
    .alignItems(HorizontalAlign.Start)
  }
}
