import { SettingEntry } from '../../../domain/model/StudyModels'
import { SettingsRepository } from '../../../domain/repository/StudyRepositories'
import { FocusSystemMetadata } from '../system/FocusSystemModels'

const SYSTEM_EXPERIENCE_KEY: string = 'focus_system_experience_v1'

export class SystemExperienceStore {
  private readonly settings: SettingsRepository
  private readonly profileId: string

  constructor(settings: SettingsRepository, profileId: string) {
    this.settings = settings
    this.profileId = profileId
  }

  async load(): Promise<FocusSystemMetadata | null> {
    const entry: SettingEntry | null = await this.settings.find(this.profileId, SYSTEM_EXPERIENCE_KEY)
    if (entry === null) {
      return null
    }
    try {
      const metadata: FocusSystemMetadata = JSON.parse(entry.value) as FocusSystemMetadata
      return this.isValid(metadata) ? metadata : null
    } catch (error) {
      return null
    }
  }

  async save(metadata: FocusSystemMetadata): Promise<void> {
    await this.settings.save({
      profileId: this.profileId,
      key: SYSTEM_EXPERIENCE_KEY,
      value: JSON.stringify(metadata),
      updatedAt: metadata.updatedAt
    })
  }

  async clear(): Promise<void> {
    await this.settings.remove(this.profileId, SYSTEM_EXPERIENCE_KEY)
  }

  private isValid(metadata: FocusSystemMetadata): boolean {
    return metadata !== null && metadata.flowId.length > 0 &&
      Number.isFinite(metadata.notificationId) && Number.isFinite(metadata.liveViewId) &&
      (metadata.reminderId === null || Number.isFinite(metadata.reminderId)) &&
      Number.isFinite(metadata.updatedAt)
  }
}
