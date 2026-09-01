import { common } from '@kit.AbilityKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { ProfileContext } from '../../sync/application/ProfileContext'
import { DataExportDocument, DataExportSerializer } from '../domain/DataExportModels'

export class DataManagementService {
  async createExport(): Promise<DataExportDocument> {
    const profileId: string = ProfileContext.currentProfileId()
    return DataExportSerializer.build(
      ProfileContext.isGuest() ? 'guest' : 'account',
      Date.now(),
      await RepositoryRegistry.categories().findAll(profileId, true),
      await RepositoryRegistry.tasks().findAll(profileId, true),
      await RepositoryRegistry.focusSessions().findAll(profileId),
      await RepositoryRegistry.rewards().findEvents(profileId),
      await RepositoryRegistry.rewards().findAchievements(profileId),
      await RepositoryRegistry.settings().findAll(profileId))
  }

  async exportToUserFile(context: common.UIAbilityContext): Promise<string> {
    const document: DataExportDocument = await this.createExport()
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    options.newFileNames = [`时芽数据-${this.dateKey(document.generatedAt)}.json`]
    options.fileSuffixChoices = ['JSON|.json']
    let file: fileIo.File | null = null
    try {
      const uris: string[] = await new picker.DocumentViewPicker(context).save(options)
      if (uris.length === 0) {
        throw new Error('EXPORT_CANCELLED')
      }
      file = fileIo.openSync(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(file.fd, DataExportSerializer.serialize(document))
      return uris[0]
    } catch (error) {
      throw new Error('EXPORT_NOT_COMPLETED')
    } finally {
      if (file !== null) {
        try {
          fileIo.closeSync(file.fd)
        } catch (closeError) {
        }
      }
    }
  }

  private dateKey(timestamp: number): string {
    const date: Date = new Date(timestamp)
    const month: string = `${date.getMonth() + 1}`.padStart(2, '0')
    const day: string = `${date.getDate()}`.padStart(2, '0')
    return `${date.getFullYear()}-${month}-${day}`
  }
}
