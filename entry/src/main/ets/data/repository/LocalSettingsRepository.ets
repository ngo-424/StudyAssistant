import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { SettingEntry } from '../../domain/model/StudyModels'
import { SettingsRepository } from '../../domain/repository/StudyRepositories'
import { DatabaseTable } from '../database/DatabaseSchema'
import { ResultSetReader } from '../database/ResultSetReader'

export class LocalSettingsRepository implements SettingsRepository {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  async save(entry: SettingEntry): Promise<void> {
    try {
      await this.store.executeSql(
        `INSERT INTO ${DatabaseTable.SETTINGS} (profile_id, setting_key, setting_value, updated_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(profile_id, setting_key) DO UPDATE SET
         setting_value=excluded.setting_value, updated_at=excluded.updated_at`,
        [entry.profileId, entry.key, entry.value, entry.updatedAt])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to save setting: ${JSON.stringify(error)}`)
    }
  }

  async find(profileId: string, key: string): Promise<SettingEntry | null> {
    let resultSet: relationalStore.ResultSet | null = null
    try {
      resultSet = await this.store.querySql(
        `SELECT profile_id, setting_key, setting_value, updated_at FROM ${DatabaseTable.SETTINGS}
         WHERE profile_id = ? AND setting_key = ? LIMIT 1`, [profileId, key])
      if (!resultSet.goToFirstRow()) {
        return null
      }
      return {
        profileId: ResultSetReader.string(resultSet, 'profile_id'),
        key: ResultSetReader.string(resultSet, 'setting_key'),
        value: ResultSetReader.string(resultSet, 'setting_value'),
        updatedAt: ResultSetReader.number(resultSet, 'updated_at')
      }
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to read setting: ${JSON.stringify(error)}`)
    } finally {
      if (resultSet !== null) {
        try {
          resultSet.close()
        } catch (closeError) {
        }
      }
    }
  }

  async remove(profileId: string, key: string): Promise<void> {
    try {
      await this.store.executeSql(
        `DELETE FROM ${DatabaseTable.SETTINGS} WHERE profile_id = ? AND setting_key = ?`, [profileId, key])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to remove setting: ${JSON.stringify(error)}`)
    }
  }
}
