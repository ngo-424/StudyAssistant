import { AchievementProgress, FocusSession, RewardEvent } from '../../../domain/model/StudyModels'
import { FocusSessionRepository, RewardRepository } from '../../../domain/repository/StudyRepositories'
import { RewardCalculation, RewardSettlementOutcome } from '../domain/RewardModels'
import { RewardRules } from '../domain/RewardRules'

export class RewardSettlementService {
  private readonly sessions: FocusSessionRepository
  private readonly rewards: RewardRepository
  private readonly idFactory: () => string
  private readonly timezoneOffsetProvider: (timestamp: number) => number

  constructor(sessions: FocusSessionRepository, rewards: RewardRepository, idFactory: () => string,
    timezoneOffsetProvider: (timestamp: number) => number) {
    this.sessions = sessions
    this.rewards = rewards
    this.idFactory = idFactory
    this.timezoneOffsetProvider = timezoneOffsetProvider
  }

  async settle(session: FocusSession): Promise<RewardSettlementOutcome> {
    if (!RewardRules.eligible(session)) {
      return { awardedEvent: null, achievements: [], calculation: null }
    }
    const allSessions: FocusSession[] = await this.sessions.findAll(session.profileId)
    const history: FocusSession[] = allSessions.filter((item: FocusSession) =>
      item.endedAt <= session.endedAt)
    const offset: number = this.timezoneOffsetProvider(session.endedAt)
    const calculation: RewardCalculation = RewardRules.calculate(session, history, offset)
    const existingEvent: RewardEvent | null = await this.rewards.findEvent(session.id)
    let awardedEvent: RewardEvent | null = null
    if (existingEvent === null) {
      const candidate: RewardEvent = RewardRules.createEvent(session, calculation, this.idFactory())
      await this.rewards.saveEvent(candidate)
      const stored: RewardEvent | null = await this.rewards.findEvent(session.id)
      if (stored?.id === candidate.id) {
        awardedEvent = candidate
      }
    }

    const existingAchievements: AchievementProgress[] = await this.rewards.findAchievements(session.profileId)
    const achievements: AchievementProgress[] = RewardRules.buildAchievements(
      session.profileId, history, existingAchievements, offset, session.endedAt, this.idFactory)
    for (let index: number = 0; index < achievements.length; index++) {
      await this.rewards.saveAchievement(achievements[index])
    }
    return { awardedEvent: awardedEvent, achievements: achievements, calculation: calculation }
  }

  async reconcileProfile(profileId: string): Promise<number> {
    const allSessions: FocusSession[] = await this.sessions.findAll(profileId)
    const eligible: FocusSession[] = allSessions.filter((session: FocusSession) => RewardRules.eligible(session))
    eligible.sort((first: FocusSession, second: FocusSession) => first.endedAt - second.endedAt)
    const existingEvents: RewardEvent[] = await this.rewards.findEvents(profileId)
    const settledSessionIds: Set<string> = new Set<string>()
    existingEvents.forEach((event: RewardEvent) => settledSessionIds.add(event.sessionId))
    let settled: number = 0
    for (let index: number = 0; index < eligible.length; index++) {
      if (!settledSessionIds.has(eligible[index].id)) {
        const outcome: RewardSettlementOutcome = await this.settle(eligible[index])
        if (outcome.awardedEvent !== null) {
          settled++
          settledSessionIds.add(eligible[index].id)
        }
      }
    }
    if (eligible.length > 0) {
      const latest: FocusSession = eligible[eligible.length - 1]
      const existingAchievements: AchievementProgress[] = await this.rewards.findAchievements(profileId)
      const achievements: AchievementProgress[] = RewardRules.buildAchievements(
        profileId, eligible, existingAchievements, this.timezoneOffsetProvider(latest.endedAt),
        latest.endedAt, this.idFactory)
      for (let index: number = 0; index < achievements.length; index++) {
        await this.rewards.saveAchievement(achievements[index])
      }
    }
    return settled
  }
}
