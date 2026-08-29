import { AchievementProgress } from '../../../domain/model/StudyModels'
import { AchievementDefinition, AchievementDisplayItem } from '../domain/RewardModels'
import { RewardRules } from '../domain/RewardRules'

export class RewardPresentation {
  static achievements(progressValues: AchievementProgress[]): AchievementDisplayItem[] {
    const progressByKey: Map<string, AchievementProgress> = new Map<string, AchievementProgress>()
    progressValues.forEach((progress: AchievementProgress) =>
      progressByKey.set(progress.achievementKey, progress))
    return RewardRules.definitions().map((definition: AchievementDefinition) => {
      const progress: AchievementProgress | undefined = progressByKey.get(definition.key)
      const item: AchievementDisplayItem = {
        key: definition.key,
        title: definition.title,
        description: definition.description,
        currentValue: progress?.currentValue ?? 0,
        targetValue: definition.target,
        unlockedAt: progress?.unlockedAt ?? null
      }
      return item
    })
  }

  static progressText(item: AchievementDisplayItem): string {
    if (item.unlockedAt !== null) {
      return '已解锁'
    }
    return `${Math.min(item.currentValue, item.targetValue)} / ${item.targetValue}`
  }

  static progressPercent(item: AchievementDisplayItem): number {
    if (item.targetValue <= 0) {
      return 0
    }
    return Math.max(0, Math.min(100, item.currentValue / item.targetValue * 100))
  }
}
