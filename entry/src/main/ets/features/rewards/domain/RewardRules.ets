import {
  AchievementProgress,
  FocusPhase,
  FocusResult,
  FocusSession,
  RewardEvent,
  SyncState
} from '../../../domain/model/StudyModels'
import {
  AchievementDefinition,
  AchievementKey,
  RewardCalculation
} from './RewardModels'

const DAY_MS: number = 24 * 60 * 60 * 1000

export class RewardRules {
  static readonly RULE_VERSION: number = 1
  static readonly BASE_POINTS: number = 10

  static eligible(session: FocusSession): boolean {
    return session.deletedAt === null && session.phase === FocusPhase.FOCUS &&
      session.result === FocusResult.COMPLETED
  }

  static calculate(session: FocusSession, sessions: FocusSession[],
    timezoneOffsetMinutes: number): RewardCalculation {
    const streakDays: number = RewardRules.streakEndingAt(
      sessions, session.endedAt, timezoneOffsetMinutes)
    const multiplier: number = RewardRules.multiplier(streakDays)
    return {
      streakDays: streakDays,
      multiplier: multiplier,
      awardedPoints: Math.round(RewardRules.BASE_POINTS * multiplier)
    }
  }

  static createEvent(session: FocusSession, calculation: RewardCalculation,
    id: string): RewardEvent {
    return {
      id: id,
      profileId: session.profileId,
      sessionId: session.id,
      ruleVersion: RewardRules.RULE_VERSION,
      basePoints: RewardRules.BASE_POINTS,
      multiplier: calculation.multiplier,
      awardedPoints: calculation.awardedPoints,
      awardedAt: session.endedAt,
      syncState: session.profileId === 'guest' ? SyncState.LOCAL_ONLY : SyncState.PENDING
    }
  }

  static definitions(): AchievementDefinition[] {
    return [
      { key: AchievementKey.FIRST_FOCUS, title: '第一次专注', description: '完成第一轮专注', target: 1, usesStreak: false },
      { key: AchievementKey.STREAK_3, title: '连续 3 天', description: '连续三天每天完成至少一轮', target: 3, usesStreak: true },
      { key: AchievementKey.STREAK_7, title: '连续 7 天', description: '保持一整周的专注节奏', target: 7, usesStreak: true },
      { key: AchievementKey.STREAK_30, title: '连续 30 天', description: '连续三十天完成专注', target: 30, usesStreak: true },
      { key: AchievementKey.TOTAL_100, title: '累计 100 轮', description: '累计完成一百轮专注', target: 100, usesStreak: false }
    ]
  }

  static buildAchievements(profileId: string, sessions: FocusSession[],
    existing: AchievementProgress[], timezoneOffsetMinutes: number, updatedAt: number,
    idFactory: () => string): AchievementProgress[] {
    const completed: FocusSession[] = RewardRules.completedSessions(sessions)
    const totalRounds: number = completed.length
    const longestStreak: number = RewardRules.longestStreak(completed, timezoneOffsetMinutes)
    const existingByKey: Map<string, AchievementProgress> = new Map<string, AchievementProgress>()
    existing.forEach((progress: AchievementProgress) => existingByKey.set(progress.achievementKey, progress))
    const syncState: SyncState = profileId === 'guest' ? SyncState.LOCAL_ONLY : SyncState.PENDING
    return RewardRules.definitions().map((definition: AchievementDefinition) => {
      const previous: AchievementProgress | undefined = existingByKey.get(definition.key)
      const measured: number = definition.usesStreak ? longestStreak : totalRounds
      const currentValue: number = Math.max(previous?.currentValue ?? 0, measured)
      const unlockedAt: number | null = previous?.unlockedAt ??
        (currentValue >= definition.target ? updatedAt : null)
      const progress: AchievementProgress = {
        id: previous?.id ?? idFactory(),
        profileId: profileId,
        achievementKey: definition.key,
        currentValue: currentValue,
        targetValue: definition.target,
        unlockedAt: unlockedAt,
        updatedAt: updatedAt,
        syncState: previous?.syncState === SyncState.LOCAL_ONLY ? SyncState.LOCAL_ONLY : syncState
      }
      return progress
    })
  }

  static multiplier(streakDays: number): number {
    if (streakDays >= 30) {
      return 2
    }
    if (streakDays >= 7) {
      return 1.5
    }
    if (streakDays >= 3) {
      return 1.2
    }
    return 1
  }

  static streakEndingAt(sessions: FocusSession[], endedAt: number,
    timezoneOffsetMinutes: number): number {
    const days: Set<number> = RewardRules.completedDays(sessions, timezoneOffsetMinutes)
    let cursor: number = RewardRules.localDayNumber(endedAt, timezoneOffsetMinutes)
    let streak: number = 0
    while (days.has(cursor)) {
      streak++
      cursor--
    }
    return streak
  }

  static longestStreak(sessions: FocusSession[], timezoneOffsetMinutes: number): number {
    const values: number[] = []
    RewardRules.completedDays(sessions, timezoneOffsetMinutes).forEach((day: number) => values.push(day))
    values.sort((first: number, second: number) => first - second)
    let longest: number = 0
    let current: number = 0
    let previous: number | null = null
    values.forEach((day: number) => {
      current = previous !== null && day === previous + 1 ? current + 1 : 1
      longest = Math.max(longest, current)
      previous = day
    })
    return longest
  }

  private static completedSessions(sessions: FocusSession[]): FocusSession[] {
    const unique: Set<string> = new Set<string>()
    const completed: FocusSession[] = []
    sessions.forEach((session: FocusSession) => {
      if (!unique.has(session.id) && RewardRules.eligible(session)) {
        unique.add(session.id)
        completed.push(session)
      }
    })
    return completed
  }

  private static completedDays(sessions: FocusSession[], timezoneOffsetMinutes: number): Set<number> {
    const days: Set<number> = new Set<number>()
    RewardRules.completedSessions(sessions).forEach((session: FocusSession) => {
      days.add(RewardRules.localDayNumber(session.endedAt, timezoneOffsetMinutes))
    })
    return days
  }

  private static localDayNumber(timestamp: number, timezoneOffsetMinutes: number): number {
    return Math.floor((timestamp + timezoneOffsetMinutes * 60 * 1000) / DAY_MS)
  }
}
