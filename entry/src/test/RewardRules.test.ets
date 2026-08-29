import { describe, expect, it } from '@ohos/hypium'
import {
  AchievementProgress,
  FocusPhase,
  FocusResult,
  FocusSession,
  RewardEvent,
  SyncState
} from '../main/ets/domain/model/StudyModels'
import { FocusSessionRepository, RewardRepository } from '../main/ets/domain/repository/StudyRepositories'
import { RewardSettlementService } from '../main/ets/features/rewards/application/RewardSettlementService'
import {
  AchievementDisplayItem,
  AchievementKey,
  RewardCalculation,
  RewardSettlementOutcome
} from '../main/ets/features/rewards/domain/RewardModels'
import { RewardRules } from '../main/ets/features/rewards/domain/RewardRules'
import { RewardPresentation } from '../main/ets/features/rewards/presentation/RewardPresentation'

class MemorySessions implements FocusSessionRepository {
  sessions: FocusSession[] = []

  async save(session: FocusSession): Promise<void> {
    const index: number = this.sessions.findIndex((item: FocusSession) => item.id === session.id)
    if (index >= 0) {
      this.sessions[index] = session
    } else {
      this.sessions.push(session)
    }
  }

  async findAll(profileId: string): Promise<FocusSession[]> {
    return this.sessions.filter((session: FocusSession) => session.profileId === profileId)
  }
}

class MemoryRewards implements RewardRepository {
  events: RewardEvent[] = []
  achievements: AchievementProgress[] = []

  async saveEvent(event: RewardEvent): Promise<void> {
    const existing: RewardEvent | undefined = this.events.find((item: RewardEvent) =>
      item.sessionId === event.sessionId)
    if (existing === undefined) {
      this.events.push(event)
    }
  }

  async saveAchievement(progress: AchievementProgress): Promise<void> {
    const index: number = this.achievements.findIndex((item: AchievementProgress) =>
      item.profileId === progress.profileId && item.achievementKey === progress.achievementKey)
    if (index >= 0) {
      this.achievements[index] = progress
    } else {
      this.achievements.push(progress)
    }
  }

  async findEvents(profileId: string): Promise<RewardEvent[]> {
    return this.events.filter((event: RewardEvent) => event.profileId === profileId)
  }

  async findEvent(sessionId: string): Promise<RewardEvent | null> {
    return this.events.find((event: RewardEvent) => event.sessionId === sessionId) ?? null
  }

  async findAchievements(profileId: string): Promise<AchievementProgress[]> {
    return this.achievements.filter((progress: AchievementProgress) => progress.profileId === profileId)
  }
}

function completedSession(id: string, endedAt: number, result: FocusResult = FocusResult.COMPLETED,
  phase: FocusPhase = FocusPhase.FOCUS): FocusSession {
  return {
    id: id,
    profileId: 'guest',
    taskId: null,
    categoryId: null,
    deviceId: 'device',
    phase: phase,
    plannedSeconds: 1500,
    focusedSeconds: 1500,
    startedAt: endedAt - 1500000,
    endedAt: endedAt,
    result: result,
    createdAt: endedAt,
    updatedAt: endedAt,
    deletedAt: null,
    revision: 0,
    syncState: SyncState.LOCAL_ONLY
  }
}

function utcDay(day: number): number {
  return Date.UTC(2026, 0, day, 12, 0, 0, 0)
}

function achievement(values: AchievementProgress[], key: AchievementKey): AchievementProgress {
  return values.find((item: AchievementProgress) => item.achievementKey === key) as AchievementProgress
}

export default function rewardRulesTest(): void {
  describe('rewardRules', () => {
    it('usesExactStreakMultiplierBoundaries', 0, () => {
      expect(RewardRules.multiplier(1)).assertEqual(1)
      expect(RewardRules.multiplier(2)).assertEqual(1)
      expect(RewardRules.multiplier(3)).assertEqual(1.2)
      expect(RewardRules.multiplier(6)).assertEqual(1.2)
      expect(RewardRules.multiplier(7)).assertEqual(1.5)
      expect(RewardRules.multiplier(29)).assertEqual(1.5)
      expect(RewardRules.multiplier(30)).assertEqual(2)
    })

    it('rejectsBreakAbandonAndInterruptedSessions', 0, () => {
      expect(RewardRules.eligible(completedSession('completed', utcDay(1)))).assertTrue()
      expect(RewardRules.eligible(completedSession(
        'abandoned', utcDay(1), FocusResult.ABANDONED))).assertFalse()
      expect(RewardRules.eligible(completedSession(
        'interrupted', utcDay(1), FocusResult.INTERRUPTED))).assertFalse()
      expect(RewardRules.eligible(completedSession(
        'break', utcDay(1), FocusResult.COMPLETED, FocusPhase.SHORT_BREAK))).assertFalse()
    })

    it('countsOneNaturalDayOnceForStreaks', 0, () => {
      const sessions: FocusSession[] = [
        completedSession('day-one-a', utcDay(1)),
        completedSession('day-one-b', utcDay(1) + 3600000),
        completedSession('day-two', utcDay(2)),
        completedSession('day-three', utcDay(3))
      ]
      const calculation: RewardCalculation = RewardRules.calculate(sessions[3], sessions, 480)
      expect(calculation.streakDays).assertEqual(3)
      expect(calculation.multiplier).assertEqual(1.2)
      expect(calculation.awardedPoints).assertEqual(12)
    })

    it('settlesEverySessionOnlyOnceAcrossTimezoneChanges', 0, async () => {
      const sessions: MemorySessions = new MemorySessions()
      const rewards: MemoryRewards = new MemoryRewards()
      const focus: FocusSession = completedSession('session-one', utcDay(1))
      await sessions.save(focus)
      let offset: number = 480
      let ids: number = 0
      const service: RewardSettlementService = new RewardSettlementService(
        sessions, rewards, () => `reward-${++ids}`, () => offset)
      const first: RewardSettlementOutcome = await service.settle(focus)
      offset = -300
      const repeated: RewardSettlementOutcome = await service.settle(focus)
      expect(first.awardedEvent?.awardedPoints).assertEqual(10)
      expect(repeated.awardedEvent).assertEqual(null)
      expect(rewards.events.length).assertEqual(1)
      expect(achievement(rewards.achievements, AchievementKey.FIRST_FOCUS).unlockedAt === null).assertFalse()
    })

    it('unlocksStreakAndTotalAchievementsWithoutRegressingProgress', 0, () => {
      const sessions: FocusSession[] = []
      for (let day: number = 1; day <= 30; day++) {
        sessions.push(completedSession(`streak-${day}`, utcDay(day)))
      }
      for (let index: number = 30; index < 100; index++) {
        sessions.push(completedSession(`total-${index}`, utcDay(30) + index * 1000))
      }
      let id: number = 0
      const progress: AchievementProgress[] = RewardRules.buildAchievements(
        'guest', sessions, [], 480, utcDay(30), () => `achievement-${++id}`)
      expect(achievement(progress, AchievementKey.STREAK_3).unlockedAt === null).assertFalse()
      expect(achievement(progress, AchievementKey.STREAK_7).unlockedAt === null).assertFalse()
      expect(achievement(progress, AchievementKey.STREAK_30).unlockedAt === null).assertFalse()
      expect(achievement(progress, AchievementKey.TOTAL_100).currentValue).assertEqual(100)
      expect(achievement(progress, AchievementKey.TOTAL_100).unlockedAt === null).assertFalse()
    })

    it('reconcilesMissingEventsWithoutDuplicatingExistingOnes', 0, async () => {
      const sessions: MemorySessions = new MemorySessions()
      const rewards: MemoryRewards = new MemoryRewards()
      await sessions.save(completedSession('first', utcDay(1)))
      await sessions.save(completedSession('second', utcDay(2)))
      await sessions.save(completedSession('ignored', utcDay(3), FocusResult.ABANDONED))
      let ids: number = 0
      const service: RewardSettlementService = new RewardSettlementService(
        sessions, rewards, () => `reconcile-${++ids}`, () => 480)
      expect(await service.reconcileProfile('guest')).assertEqual(2)
      expect(await service.reconcileProfile('guest')).assertEqual(0)
      expect(rewards.events.length).assertEqual(2)
      expect(rewards.achievements.length).assertEqual(5)
    })

    it('exposesFiveReadableAchievementCards', 0, () => {
      const items: AchievementDisplayItem[] = RewardPresentation.achievements([])
      expect(items.length).assertEqual(5)
      expect(RewardPresentation.progressText(items[0])).assertEqual('0 / 1')
      expect(RewardPresentation.progressPercent(items[0])).assertEqual(0)
    })
  })
}
