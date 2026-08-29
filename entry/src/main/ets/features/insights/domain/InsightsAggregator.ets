import {
  DailyStatistics,
  FocusPhase,
  FocusResult,
  FocusSession,
  RewardEvent,
  TaskCategory
} from '../../../domain/model/StudyModels'
import { CategoryColor } from '../../tasks/domain/CategoryColor'
import {
  CategoryFocusSegment,
  CategoryFocusShare,
  HeatmapDay,
  InsightsDashboard,
  TrendPoint
} from './InsightsModels'

const UNCATEGORIZED_KEY: string = '__uncategorized__'
const HEATMAP_DAYS: number = 84

interface CategoryIdentity {
  id: string | null
  name: string
  colorSeed: string
  deleted: boolean
}

export class InsightsAggregator {
  static aggregate(sessions: FocusSession[], categories: TaskCategory[], rewards: RewardEvent[],
    now: number): InsightsDashboard {
    const todayStart: number = InsightsAggregator.startOfDay(now)
    const tomorrowStart: number = InsightsAggregator.addDays(todayStart, 1)
    const heatmapStart: number = InsightsAggregator.heatmapStart(todayStart)
    const categoryIndex: Map<string, CategoryIdentity> = InsightsAggregator.categoryIndex(categories)
    const daily: Map<string, DailyStatistics> = new Map<string, DailyStatistics>()
    const dailyCategories: Map<string, Map<string, number>> = new Map<string, Map<string, number>>()
    const categoryTotals: Map<string, number> = new Map<string, number>()
    const completedDays: Set<string> = new Set<string>()
    const sessionIds: Set<string> = new Set<string>()
    let totalFocusSeconds: number = 0
    let completedFocusRounds: number = 0

    sessions.forEach((session: FocusSession) => {
      if (sessionIds.has(session.id) || session.deletedAt !== null || session.phase !== FocusPhase.FOCUS) {
        return
      }
      sessionIds.add(session.id)
      const focusedSeconds: number = InsightsAggregator.safeSeconds(session.focusedSeconds)
      const categoryKey: string = InsightsAggregator.categoryKey(session.categoryId, categoryIndex)
      totalFocusSeconds += focusedSeconds
      categoryTotals.set(categoryKey, (categoryTotals.get(categoryKey) ?? 0) + focusedSeconds)
      InsightsAggregator.allocateDaily(session, focusedSeconds, categoryKey, heatmapStart, tomorrowStart,
        daily, dailyCategories)
      if (session.result === FocusResult.COMPLETED) {
        completedFocusRounds++
        const completionKey: string = InsightsAggregator.dateKey(session.endedAt)
        completedDays.add(completionKey)
        if (session.endedAt >= heatmapStart && session.endedAt < tomorrowStart) {
          const statistic: DailyStatistics = InsightsAggregator.statistic(daily, completionKey)
          statistic.completedRounds++
        }
      }
    })

    const rewardIds: Set<string> = new Set<string>()
    let totalPoints: number = 0
    rewards.forEach((event: RewardEvent) => {
      if (rewardIds.has(event.id)) {
        return
      }
      rewardIds.add(event.id)
      const points: number = Math.max(0, Math.floor(event.awardedPoints))
      totalPoints += points
      if (event.awardedAt >= heatmapStart && event.awardedAt < tomorrowStart) {
        InsightsAggregator.statistic(daily, InsightsAggregator.dateKey(event.awardedAt)).awardedPoints += points
      }
    })

    const todayKey: string = InsightsAggregator.dateKey(todayStart)
    const today: DailyStatistics = InsightsAggregator.copyStatistic(
      daily.get(todayKey) ?? InsightsAggregator.emptyStatistic(todayKey))
    const trend: TrendPoint[] = InsightsAggregator.buildTrend(
      todayStart, daily, dailyCategories, categoryIndex)
    const heatmapWeeks: HeatmapDay[][] = InsightsAggregator.buildHeatmap(
      heatmapStart, todayStart, daily)
    const distribution: CategoryFocusShare[] = InsightsAggregator.buildDistribution(
      categoryTotals, categoryIndex, totalFocusSeconds)

    return {
      today: today,
      currentStreak: InsightsAggregator.currentStreak(todayStart, completedDays),
      totalPoints: totalPoints,
      totalFocusSeconds: totalFocusSeconds,
      completedFocusRounds: completedFocusRounds,
      trend: trend,
      heatmapWeeks: heatmapWeeks,
      categoryDistribution: distribution,
      hasFocusData: totalFocusSeconds > 0
    }
  }

  static empty(now: number): InsightsDashboard {
    return InsightsAggregator.aggregate([], [], [], now)
  }

  private static allocateDaily(session: FocusSession, focusedSeconds: number, categoryKey: string,
    rangeStart: number, rangeEnd: number, daily: Map<string, DailyStatistics>,
    dailyCategories: Map<string, Map<string, number>>): void {
    if (focusedSeconds <= 0) {
      return
    }
    const sessionStart: number = Math.min(session.startedAt, session.endedAt)
    const sessionEnd: number = Math.max(session.startedAt, session.endedAt)
    if (sessionEnd <= sessionStart) {
      if (session.endedAt >= rangeStart && session.endedAt < rangeEnd) {
        InsightsAggregator.addDaily(daily, dailyCategories, InsightsAggregator.dateKey(session.endedAt),
          categoryKey, focusedSeconds)
      }
      return
    }
    let cursor: number = Math.max(sessionStart, rangeStart)
    const clippedEnd: number = Math.min(sessionEnd, rangeEnd)
    if (cursor >= clippedEnd) {
      return
    }
    const duration: number = sessionEnd - sessionStart
    while (cursor < clippedEnd) {
      const dayStart: number = InsightsAggregator.startOfDay(cursor)
      const nextDay: number = InsightsAggregator.addDays(dayStart, 1)
      const segmentEnd: number = Math.min(nextDay, clippedEnd)
      const seconds: number = focusedSeconds * (segmentEnd - cursor) / duration
      InsightsAggregator.addDaily(daily, dailyCategories, InsightsAggregator.dateKey(dayStart),
        categoryKey, seconds)
      cursor = segmentEnd
    }
  }

  private static addDaily(daily: Map<string, DailyStatistics>,
    dailyCategories: Map<string, Map<string, number>>, dateKey: string, categoryKey: string,
    focusSeconds: number): void {
    InsightsAggregator.statistic(daily, dateKey).focusSeconds += focusSeconds
    let categories: Map<string, number> | undefined = dailyCategories.get(dateKey)
    if (categories === undefined) {
      categories = new Map<string, number>()
      dailyCategories.set(dateKey, categories)
    }
    categories.set(categoryKey, (categories.get(categoryKey) ?? 0) + focusSeconds)
  }

  private static buildTrend(todayStart: number, daily: Map<string, DailyStatistics>,
    dailyCategories: Map<string, Map<string, number>>,
    categoryIndex: Map<string, CategoryIdentity>): TrendPoint[] {
    const trend: TrendPoint[] = []
    for (let offset: number = -6; offset <= 0; offset++) {
      const day: number = InsightsAggregator.addDays(todayStart, offset)
      const key: string = InsightsAggregator.dateKey(day)
      const statistic: DailyStatistics = InsightsAggregator.copyStatistic(
        daily.get(key) ?? InsightsAggregator.emptyStatistic(key))
      trend.push({
        dateKey: statistic.dateKey,
        focusSeconds: statistic.focusSeconds,
        completedRounds: statistic.completedRounds,
        awardedPoints: statistic.awardedPoints,
        label: InsightsAggregator.weekdayLabel(day),
        categorySegments: InsightsAggregator.buildSegments(dailyCategories.get(key), categoryIndex)
      })
    }
    return trend
  }

  private static buildSegments(values: Map<string, number> | undefined,
    categoryIndex: Map<string, CategoryIdentity>): CategoryFocusSegment[] {
    const segments: CategoryFocusSegment[] = []
    if (values === undefined) {
      return segments
    }
    values.forEach((seconds: number, key: string) => {
      const identity: CategoryIdentity = InsightsAggregator.identity(key, categoryIndex)
      segments.push({
        categoryId: identity.id,
        name: identity.name,
        colorSeed: identity.colorSeed,
        focusSeconds: Math.round(seconds)
      })
    })
    segments.sort((first: CategoryFocusSegment, second: CategoryFocusSegment) =>
      second.focusSeconds - first.focusSeconds)
    return segments
  }

  private static buildHeatmap(start: number, todayStart: number,
    daily: Map<string, DailyStatistics>): HeatmapDay[][] {
    const values: number[] = []
    for (let offset: number = 0; offset < HEATMAP_DAYS; offset++) {
      const key: string = InsightsAggregator.dateKey(InsightsAggregator.addDays(start, offset))
      values.push(daily.get(key)?.focusSeconds ?? 0)
    }
    let maximum: number = 0
    values.forEach((value: number) => maximum = Math.max(maximum, value))
    const weeks: HeatmapDay[][] = []
    for (let weekIndex: number = 0; weekIndex < 12; weekIndex++) {
      const week: HeatmapDay[] = []
      for (let dayIndex: number = 0; dayIndex < 7; dayIndex++) {
        const offset: number = weekIndex * 7 + dayIndex
        const timestamp: number = InsightsAggregator.addDays(start, offset)
        const seconds: number = Math.round(values[offset])
        week.push({
          dateKey: InsightsAggregator.dateKey(timestamp),
          dayOfMonth: new Date(timestamp).getDate(),
          focusSeconds: seconds,
          level: InsightsAggregator.heatLevel(seconds, maximum),
          isFuture: timestamp > todayStart
        })
      }
      weeks.push(week)
    }
    return weeks
  }

  private static buildDistribution(totals: Map<string, number>,
    categoryIndex: Map<string, CategoryIdentity>, totalSeconds: number): CategoryFocusShare[] {
    const distribution: CategoryFocusShare[] = []
    totals.forEach((seconds: number, key: string) => {
      if (seconds <= 0) {
        return
      }
      const identity: CategoryIdentity = InsightsAggregator.identity(key, categoryIndex)
      distribution.push({
        categoryId: identity.id,
        name: identity.name,
        colorSeed: identity.colorSeed,
        focusSeconds: Math.round(seconds),
        percentage: totalSeconds <= 0 ? 0 : seconds / totalSeconds,
        categoryDeleted: identity.deleted
      })
    })
    distribution.sort((first: CategoryFocusShare, second: CategoryFocusShare) =>
      second.focusSeconds - first.focusSeconds)
    return distribution
  }

  private static currentStreak(todayStart: number, completedDays: Set<string>): number {
    let cursor: number = todayStart
    if (!completedDays.has(InsightsAggregator.dateKey(cursor))) {
      cursor = InsightsAggregator.addDays(cursor, -1)
      if (!completedDays.has(InsightsAggregator.dateKey(cursor))) {
        return 0
      }
    }
    let streak: number = 0
    while (completedDays.has(InsightsAggregator.dateKey(cursor))) {
      streak++
      cursor = InsightsAggregator.addDays(cursor, -1)
    }
    return streak
  }

  private static categoryIndex(categories: TaskCategory[]): Map<string, CategoryIdentity> {
    const index: Map<string, CategoryIdentity> = new Map<string, CategoryIdentity>()
    categories.forEach((category: TaskCategory) => {
      index.set(category.id, {
        id: category.id,
        name: category.deletedAt === null ? category.name : `${category.name}（已删除）`,
        colorSeed: CategoryColor.normalize(category.colorSeed) ?? CategoryColor.NEUTRAL,
        deleted: category.deletedAt !== null
      })
    })
    return index
  }

  private static categoryKey(categoryId: string | null,
    categoryIndex: Map<string, CategoryIdentity>): string {
    return categoryId !== null && categoryIndex.has(categoryId) ? categoryId : UNCATEGORIZED_KEY
  }

  private static identity(key: string, categoryIndex: Map<string, CategoryIdentity>): CategoryIdentity {
    return categoryIndex.get(key) ?? {
      id: null,
      name: '未分类',
      colorSeed: CategoryColor.NEUTRAL,
      deleted: false
    }
  }

  private static statistic(values: Map<string, DailyStatistics>, dateKey: string): DailyStatistics {
    let statistic: DailyStatistics | undefined = values.get(dateKey)
    if (statistic === undefined) {
      statistic = InsightsAggregator.emptyStatistic(dateKey)
      values.set(dateKey, statistic)
    }
    return statistic
  }

  private static emptyStatistic(dateKey: string): DailyStatistics {
    return { dateKey: dateKey, focusSeconds: 0, completedRounds: 0, awardedPoints: 0 }
  }

  private static copyStatistic(value: DailyStatistics): DailyStatistics {
    return {
      dateKey: value.dateKey,
      focusSeconds: Math.round(value.focusSeconds),
      completedRounds: value.completedRounds,
      awardedPoints: value.awardedPoints
    }
  }

  private static heatLevel(seconds: number, maximum: number): number {
    if (seconds <= 0 || maximum <= 0) {
      return 0
    }
    return Math.max(1, Math.min(4, Math.ceil(seconds / maximum * 4)))
  }

  private static safeSeconds(value: number): number {
    return Number.isFinite(value) ? Math.max(0, Math.floor(value)) : 0
  }

  private static heatmapStart(todayStart: number): number {
    const day: number = new Date(todayStart).getDay()
    const daysSinceMonday: number = day === 0 ? 6 : day - 1
    return InsightsAggregator.addDays(todayStart, -daysSinceMonday - 11 * 7)
  }

  private static startOfDay(timestamp: number): number {
    const date: Date = new Date(timestamp)
    date.setHours(0, 0, 0, 0)
    return date.getTime()
  }

  private static addDays(timestamp: number, count: number): number {
    const date: Date = new Date(timestamp)
    date.setDate(date.getDate() + count)
    return date.getTime()
  }

  private static dateKey(timestamp: number): string {
    const date: Date = new Date(timestamp)
    return `${date.getFullYear()}-${InsightsAggregator.pad(date.getMonth() + 1)}-${InsightsAggregator.pad(date.getDate())}`
  }

  private static weekdayLabel(timestamp: number): string {
    const labels: string[] = ['日', '一', '二', '三', '四', '五', '六']
    return `周${labels[new Date(timestamp).getDay()]}`
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : value.toString()
  }
}
