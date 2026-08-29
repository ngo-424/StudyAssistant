import { AppInitializer } from '../../../app/AppInitializer'
import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { AchievementProgress, FocusSession, RewardEvent, TaskCategory } from '../../../domain/model/StudyModels'
import { InsightsAggregator } from '../domain/InsightsAggregator'
import { InsightsDashboard } from '../domain/InsightsModels'
import { AchievementDisplayItem } from '../../rewards/domain/RewardModels'
import { RewardPresentation } from '../../rewards/presentation/RewardPresentation'

export interface InsightsScreenData {
  dashboard: InsightsDashboard
  achievements: AchievementDisplayItem[]
}

export class InsightsViewModel {
  async load(): Promise<InsightsScreenData> {
    await AppInitializer.whenReady()
    const sessions: FocusSession[] = await RepositoryRegistry.focusSessions().findAll(GUEST_PROFILE_ID)
    const categories: TaskCategory[] = await RepositoryRegistry.categories().findAll(GUEST_PROFILE_ID, true)
    const rewards: RewardEvent[] = await RepositoryRegistry.rewards().findEvents(GUEST_PROFILE_ID)
    const achievements: AchievementProgress[] = await RepositoryRegistry.rewards().findAchievements(GUEST_PROFILE_ID)
    return {
      dashboard: InsightsAggregator.aggregate(sessions, categories, rewards, Date.now()),
      achievements: RewardPresentation.achievements(achievements)
    }
  }
}
