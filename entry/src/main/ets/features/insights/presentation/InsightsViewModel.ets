import { AppInitializer } from '../../../app/AppInitializer'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { AchievementProgress, FocusSession, RewardEvent, TaskCategory } from '../../../domain/model/StudyModels'
import { InsightsAggregator } from '../domain/InsightsAggregator'
import { InsightsDashboard } from '../domain/InsightsModels'
import { AchievementDisplayItem } from '../../rewards/domain/RewardModels'
import { RewardPresentation } from '../../rewards/presentation/RewardPresentation'
import { ProfileContext } from '../../sync/application/ProfileContext'

export interface InsightsScreenData {
  dashboard: InsightsDashboard
  achievements: AchievementDisplayItem[]
}

export class InsightsViewModel {
  async load(): Promise<InsightsScreenData> {
    await AppInitializer.whenReady()
    const profileId: string = ProfileContext.currentProfileId()
    const sessions: FocusSession[] = await RepositoryRegistry.focusSessions().findAll(profileId)
    const categories: TaskCategory[] = await RepositoryRegistry.categories().findAll(profileId, true)
    const rewards: RewardEvent[] = await RepositoryRegistry.rewards().findEvents(profileId)
    const achievements: AchievementProgress[] = await RepositoryRegistry.rewards().findAchievements(profileId)
    return {
      dashboard: InsightsAggregator.aggregate(sessions, categories, rewards, Date.now()),
      achievements: RewardPresentation.achievements(achievements)
    }
  }
}
