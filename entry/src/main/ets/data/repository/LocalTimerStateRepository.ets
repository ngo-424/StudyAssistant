import { ActiveTimerSnapshot, SettingEntry, TimerConfig } from '../../domain/model/StudyModels'
import { SettingsRepository, TimerStateRepository } from '../../domain/repository/StudyRepositories'
import { TimerStateCodec } from './TimerStateCodec'

const CONFIG_KEY: string = 'focus_timer_config_v1'
const SNAPSHOT_KEY: string = 'active_timer_snapshot_v1'
const DEVICE_ID_KEY: string = 'local_device_id_v1'

export class LocalTimerStateRepository implements TimerStateRepository {
  private readonly settings: SettingsRepository

  constructor(settings: SettingsRepository) {
    this.settings = settings
  }

  async saveConfig(profileId: string, config: TimerConfig): Promise<void> {
    await this.settings.save(this.entry(profileId, CONFIG_KEY, TimerStateCodec.encodeConfig(config)))
  }

  async loadConfig(profileId: string): Promise<TimerConfig | null> {
    const entry: SettingEntry | null = await this.settings.find(profileId, CONFIG_KEY)
    return entry === null ? null : TimerStateCodec.decodeConfig(entry.value)
  }

  async saveSnapshot(snapshot: ActiveTimerSnapshot): Promise<void> {
    await this.settings.save(this.entry(
      snapshot.profileId, SNAPSHOT_KEY, TimerStateCodec.encodeSnapshot(snapshot), snapshot.updatedAt))
  }

  async loadSnapshot(profileId: string): Promise<ActiveTimerSnapshot | null> {
    const entry: SettingEntry | null = await this.settings.find(profileId, SNAPSHOT_KEY)
    return entry === null ? null : TimerStateCodec.decodeSnapshot(entry.value)
  }

  async clearSnapshot(profileId: string): Promise<void> {
    await this.settings.remove(profileId, SNAPSHOT_KEY)
  }

  async getOrCreateDeviceId(profileId: string, idFactory: () => string): Promise<string> {
    const existing: SettingEntry | null = await this.settings.find(profileId, DEVICE_ID_KEY)
    if (existing !== null && existing.value.length > 0) {
      return existing.value
    }
    const deviceId: string = idFactory()
    await this.settings.save(this.entry(profileId, DEVICE_ID_KEY, deviceId))
    return deviceId
  }

  private entry(profileId: string, key: string, value: string, updatedAt: number = Date.now()): SettingEntry {
    return { profileId: profileId, key: key, value: value, updatedAt: updatedAt }
  }
}
