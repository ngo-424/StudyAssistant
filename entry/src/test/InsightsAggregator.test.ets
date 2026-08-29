import { describe, expect, it } from '@ohos/hypium'
import {
  FocusPhase,
  FocusResult,
  FocusSession,
  RewardEvent,
  SyncState,
  TaskCategory
} from '../main/ets/domain/model/StudyModels'
import { InsightsAggregator } from '../main/ets/features/insights/domain/InsightsAggregator'
import { InsightsDashboard } from '../main/ets/features/insights/domain/InsightsModels'
import { InsightsPresentation } from '../main/ets/features/insights/presentation/InsightsPresentation'

function session(id: string, startedAt: number, endedAt: number, focusedSeconds: number,
  result: FocusResult = FocusResult.COMPLETED, categoryId: string | null = null,
  phase: FocusPhase = FocusPhase.FOCUS): FocusSession {
  return {
    id: id,
    profileId: 'guest',
    taskId: null,
    categoryId: categoryId,
    deviceId: 'device-1',
    phase: phase,
    plannedSeconds: 1500,
    focusedSeconds: focusedSeconds,
    startedAt: startedAt,
    endedAt: endedAt,
    result: result,
    createdAt: endedAt,
    updatedAt: endedAt,
    deletedAt: null,
    revision: 0,
    syncState: SyncState.LOCAL_ONLY
  }
}

function category(id: string, name: string, color: string, deletedAt: number | null = null): TaskCategory {
  return {
    id: id,
    profileId: 'guest',
    name: name,
    colorSeed: color,
    createdAt: 1,
    updatedAt: 1,
    deletedAt: deletedAt,
    revision: 0,
    syncState: SyncState.LOCAL_ONLY
  }
}

function reward(id: string, awardedAt: number, points: number): RewardEvent {
  return {
    id: id,
    profileId: 'guest',
    sessionId: `session-${id}`,
    ruleVersion: 1,
    basePoints: 10,
    multiplier: 1,
    awardedPoints: points,
    awardedAt: awardedAt,
    syncState: SyncState.LOCAL_ONLY
  }
}

function atDay(now: number, offset: number, hour: number = 12, minute: number = 0): number {
  const date: Date = new Date(now)
  date.setHours(hour, minute, 0, 0)
  date.setDate(date.getDate() + offset)
  return date.getTime()
}

export default function insightsAggregatorTest(): void {
  describe('insightsAggregator', () => {
    const now: number = new Date(2026, 7, 29, 12, 0, 0, 0).getTime()

    it('createsCompleteEmptyDashboard', 0, () => {
      const dashboard: InsightsDashboard = InsightsAggregator.empty(now)
      expect(dashboard.today.focusSeconds).assertEqual(0)
      expect(dashboard.currentStreak).assertEqual(0)
      expect(dashboard.trend.length).assertEqual(7)
      expect(dashboard.heatmapWeeks.length).assertEqual(12)
      expect(dashboard.heatmapWeeks[0].length).assertEqual(7)
      expect(dashboard.hasFocusData).assertFalse()
    })

    it('aggregatesFocusRoundsActualTimeAndSettledPointsOnly', 0, () => {
      const start: number = atDay(now, 0, 9)
      const completed: FocusSession = session('completed', start, start + 1500000, 1500)
      const interrupted: FocusSession = session(
        'interrupted', start + 2000000, start + 2600000, 600, FocusResult.INTERRUPTED)
      const breakSession: FocusSession = session(
        'break', start, start + 300000, 300, FocusResult.COMPLETED, null, FocusPhase.SHORT_BREAK)
      const dashboard: InsightsDashboard = InsightsAggregator.aggregate(
        [completed, completed, interrupted, breakSession], [], [reward('one', now, 12), reward('one', now, 12)], now)
      expect(dashboard.today.focusSeconds).assertEqual(2100)
      expect(dashboard.today.completedRounds).assertEqual(1)
      expect(dashboard.completedFocusRounds).assertEqual(1)
      expect(dashboard.totalPoints).assertEqual(12)
      expect(dashboard.categoryDistribution.length).assertEqual(1)
    })

    it('splitsCrossMidnightFocusAcrossBothLocalDates', 0, () => {
      const startedAt: number = atDay(now, -1, 23, 50)
      const endedAt: number = atDay(now, 0, 0, 10)
      const dashboard: InsightsDashboard = InsightsAggregator.aggregate(
        [session('cross-midnight', startedAt, endedAt, 1200, FocusResult.INTERRUPTED)], [], [], now)
      expect(dashboard.trend[5].focusSeconds).assertEqual(600)
      expect(dashboard.trend[6].focusSeconds).assertEqual(600)
      expect(dashboard.today.focusSeconds).assertEqual(600)
    })

    it('preservesDeletedCategoryIdentityAndColorForHistory', 0, () => {
      const deleted: TaskCategory = category('math', '数学', '#536F9E', now)
      const dashboard: InsightsDashboard = InsightsAggregator.aggregate(
        [session('math-session', now - 60000, now, 60, FocusResult.COMPLETED, 'math')],
        [deleted], [], now)
      expect(dashboard.categoryDistribution[0].name).assertEqual('数学（已删除）')
      expect(dashboard.categoryDistribution[0].colorSeed).assertEqual('#536F9E')
      expect(dashboard.categoryDistribution[0].categoryDeleted).assertTrue()
      expect(dashboard.trend[6].categorySegments[0].colorSeed).assertEqual('#536F9E')
    })

    it('continuesStreakFromYesterdayUntilTodayEnds', 0, () => {
      const sessions: FocusSession[] = []
      for (let offset: number = -3; offset <= -1; offset++) {
        const end: number = atDay(now, offset)
        sessions.push(session(`day-${offset}`, end - 1500000, end, 1500))
      }
      expect(InsightsAggregator.aggregate(sessions, [], [], now).currentStreak).assertEqual(3)
      sessions.push(session('today', now - 1500000, now, 1500))
      expect(InsightsAggregator.aggregate(sessions, [], [], now).currentStreak).assertEqual(4)
    })

    it('aggregatesLargeSessionCollectionsInOnePass', 0, () => {
      const sessions: FocusSession[] = []
      for (let index: number = 0; index < 5000; index++) {
        sessions.push(session(`large-${index}`, now - 60000, now, 60, FocusResult.INTERRUPTED))
      }
      const dashboard: InsightsDashboard = InsightsAggregator.aggregate(sessions, [], [], now)
      expect(dashboard.today.focusSeconds).assertEqual(300000)
      expect(dashboard.categoryDistribution[0].focusSeconds).assertEqual(300000)
      expect(dashboard.completedFocusRounds).assertEqual(0)
    })

    it('formatsDurationsWithoutMisleadingZeroValues', 0, () => {
      expect(InsightsPresentation.focusMinutes(30)).assertEqual('<1 分钟')
      expect(InsightsPresentation.duration(3600)).assertEqual('1 小时')
      expect(InsightsPresentation.percentage(0.426)).assertEqual('43%')
    })
  })
}
