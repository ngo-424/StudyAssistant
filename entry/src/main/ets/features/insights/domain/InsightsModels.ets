import { DailyStatistics } from '../../../domain/model/StudyModels'

export interface CategoryFocusSegment {
  categoryId: string | null
  name: string
  colorSeed: string
  focusSeconds: number
}

export interface TrendPoint extends DailyStatistics {
  label: string
  categorySegments: CategoryFocusSegment[]
}

export interface HeatmapDay {
  dateKey: string
  dayOfMonth: number
  focusSeconds: number
  level: number
  isFuture: boolean
}

export interface CategoryFocusShare extends CategoryFocusSegment {
  percentage: number
  categoryDeleted: boolean
}

export interface InsightsDashboard {
  today: DailyStatistics
  currentStreak: number
  totalPoints: number
  totalFocusSeconds: number
  completedFocusRounds: number
  trend: TrendPoint[]
  heatmapWeeks: HeatmapDay[][]
  categoryDistribution: CategoryFocusShare[]
  hasFocusData: boolean
}
