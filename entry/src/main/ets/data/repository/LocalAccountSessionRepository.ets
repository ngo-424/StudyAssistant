import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { AccountSessionRepository } from '../../domain/repository/AccountSessionRepository'
import { AccountSession } from '../../features/auth/domain/AuthModels'
import { DatabaseTable } from '../database/DatabaseSchema'
import { ResultSetReader } from '../database/ResultSetReader'

const CURRENT_SESSION_KEY: string = 'current'

export class LocalAccountSessionRepository implements AccountSessionRepository {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  async save(session: AccountSession): Promise<void> {
    try {
      await this.store.executeSql(
        `INSERT INTO ${DatabaseTable.ACCOUNT_SESSION} (
          session_key, account_id, email, access_token, refresh_token,
          access_expires_at, refresh_expires_at, device_id, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(session_key) DO UPDATE SET
          account_id=excluded.account_id, email=excluded.email,
          access_token=excluded.access_token, refresh_token=excluded.refresh_token,
          access_expires_at=excluded.access_expires_at, refresh_expires_at=excluded.refresh_expires_at,
          device_id=excluded.device_id, updated_at=excluded.updated_at`,
        [CURRENT_SESSION_KEY, session.accountId, session.email, session.accessToken, session.refreshToken,
          session.accessExpiresAt, session.refreshExpiresAt, session.deviceId, session.updatedAt])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to save account session: ${JSON.stringify(error)}`)
    }
  }

  async current(): Promise<AccountSession | null> {
    let resultSet: relationalStore.ResultSet | null = null
    try {
      resultSet = await this.store.querySql(
        `SELECT account_id, email, access_token, refresh_token, access_expires_at,
          refresh_expires_at, device_id, updated_at FROM ${DatabaseTable.ACCOUNT_SESSION}
          WHERE session_key = ? LIMIT 1`, [CURRENT_SESSION_KEY])
      if (!resultSet.goToFirstRow()) {
        return null
      }
      return {
        accountId: ResultSetReader.string(resultSet, 'account_id'),
        email: ResultSetReader.string(resultSet, 'email'),
        accessToken: ResultSetReader.string(resultSet, 'access_token'),
        refreshToken: ResultSetReader.string(resultSet, 'refresh_token'),
        accessExpiresAt: ResultSetReader.number(resultSet, 'access_expires_at'),
        refreshExpiresAt: ResultSetReader.number(resultSet, 'refresh_expires_at'),
        deviceId: ResultSetReader.string(resultSet, 'device_id'),
        updatedAt: ResultSetReader.number(resultSet, 'updated_at')
      }
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to read account session: ${JSON.stringify(error)}`)
    } finally {
      if (resultSet !== null) {
        try {
          resultSet.close()
        } catch (closeError) {
        }
      }
    }
  }

  async clear(): Promise<void> {
    try {
      await this.store.executeSql(
        `DELETE FROM ${DatabaseTable.ACCOUNT_SESSION} WHERE session_key = ?`, [CURRENT_SESSION_KEY])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to clear account session: ${JSON.stringify(error)}`)
    }
  }
}
