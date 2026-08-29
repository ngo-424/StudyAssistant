import { AchievementProgress, RewardEvent } from '../../../domain/model/StudyModels'

export enum AchievementKey {
  FIRST_FOCUS = 'first_focus',
  STREAK_3 = 'streak_3',
  STREAK_7 = 'streak_7',
  STREAK_30 = 'streak_30',
  TOTAL_100 = 'total_100'
}

export interface AchievementDefinition {
  key: AchievementKey
  title: string
  description: string
  target: number
  usesStreak: boolean
}

export interface RewardCalculation {
  streakDays: number
  multiplier: number
  awardedPoints: number
}

export interface RewardSettlementOutcome {
  awardedEvent: RewardEvent | null
  achievements: AchievementProgress[]
  calculation: RewardCalculation | null
}

export interface AchievementDisplayItem {
  key: string
  title: string
  description: string
  currentValue: number
  targetValue: number
  unlockedAt: number | null
}
