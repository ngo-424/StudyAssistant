import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'
import { AchievementProgress, RewardEvent, SyncState } from '../../domain/model/StudyModels'
import { RewardRepository } from '../../domain/repository/StudyRepositories'
import { DatabaseTable } from '../database/DatabaseSchema'
import { ResultSetReader } from '../database/ResultSetReader'

export class LocalRewardRepository implements RewardRepository {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  async saveEvent(event: RewardEvent): Promise<void> {
    try {
      await this.store.executeSql(
        `INSERT INTO ${DatabaseTable.REWARD_EVENTS}
         (id, profile_id, session_id, rule_version, base_points, multiplier,
          awarded_points, awarded_at, sync_state)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
          profile_id=excluded.profile_id, session_id=excluded.session_id,
          rule_version=excluded.rule_version, base_points=excluded.base_points,
          multiplier=excluded.multiplier, awarded_points=excluded.awarded_points,
          awarded_at=excluded.awarded_at, sync_state=excluded.sync_state`,
        [event.id, event.profileId, event.sessionId, event.ruleVersion, event.basePoints,
          event.multiplier, event.awardedPoints, event.awardedAt, event.syncState])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to save reward event: ${JSON.stringify(error)}`)
    }
  }

  async saveAchievement(progress: AchievementProgress): Promise<void> {
    try {
      await this.store.executeSql(
        `INSERT INTO ${DatabaseTable.ACHIEVEMENTS}
         (id, profile_id, achievement_key, current_value, target_value,
          unlocked_at, updated_at, sync_state)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
          current_value=excluded.current_value, target_value=excluded.target_value,
          unlocked_at=excluded.unlocked_at, updated_at=excluded.updated_at,
          sync_state=excluded.sync_state`,
        [progress.id, progress.profileId, progress.achievementKey, progress.currentValue,
          progress.targetValue, progress.unlockedAt, progress.updatedAt, progress.syncState])
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to save achievement: ${JSON.stringify(error)}`)
    }
  }

  async findEvents(profileId: string): Promise<RewardEvent[]> {
    let resultSet: relationalStore.ResultSet | null = null
    const events: RewardEvent[] = []
    try {
      resultSet = await this.store.querySql(
        `SELECT id, profile_id, session_id, rule_version, base_points, multiplier,
         awarded_points, awarded_at, sync_state
         FROM ${DatabaseTable.REWARD_EVENTS}
         WHERE profile_id = ? ORDER BY awarded_at DESC`, [profileId])
      while (resultSet.goToNextRow()) {
        events.push({
          id: ResultSetReader.string(resultSet, 'id'),
          profileId: ResultSetReader.string(resultSet, 'profile_id'),
          sessionId: ResultSetReader.string(resultSet, 'session_id'),
          ruleVersion: ResultSetReader.number(resultSet, 'rule_version'),
          basePoints: ResultSetReader.number(resultSet, 'base_points'),
          multiplier: ResultSetReader.number(resultSet, 'multiplier'),
          awardedPoints: ResultSetReader.number(resultSet, 'awarded_points'),
          awardedAt: ResultSetReader.number(resultSet, 'awarded_at'),
          syncState: ResultSetReader.string(resultSet, 'sync_state') as SyncState
        })
      }
      return events
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to list reward events: ${JSON.stringify(error)}`)
    } finally {
      if (resultSet !== null) {
        try {
          resultSet.close()
        } catch (closeError) {
        }
      }
    }
  }
}
