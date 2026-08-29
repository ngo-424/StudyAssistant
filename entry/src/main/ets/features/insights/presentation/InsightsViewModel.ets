import { AppInitializer } from '../../../app/AppInitializer'
import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { FocusSession, RewardEvent, TaskCategory } from '../../../domain/model/StudyModels'
import { InsightsAggregator } from '../domain/InsightsAggregator'
import { InsightsDashboard } from '../domain/InsightsModels'

export class InsightsViewModel {
  async load(): Promise<InsightsDashboard> {
    await AppInitializer.whenReady()
    const sessions: FocusSession[] = await RepositoryRegistry.focusSessions().findAll(GUEST_PROFILE_ID)
    const categories: TaskCategory[] = await RepositoryRegistry.categories().findAll(GUEST_PROFILE_ID, true)
    const rewards: RewardEvent[] = await RepositoryRegistry.rewards().findEvents(GUEST_PROFILE_ID)
    return InsightsAggregator.aggregate(sessions, categories, rewards, Date.now())
  }
}
