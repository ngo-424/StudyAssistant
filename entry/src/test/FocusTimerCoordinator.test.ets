import { describe, expect, it } from '@ohos/hypium'
import {
  ActiveTimerSnapshot,
  FocusSession,
  TimerConfig,
  TimerRunState
} from '../main/ets/domain/model/StudyModels'
import { FocusSessionRepository, TimerStateRepository } from '../main/ets/domain/repository/StudyRepositories'
import { FocusTimerCoordinator } from '../main/ets/features/focus/application/FocusTimerCoordinator'
import { TimerRuntimeState } from '../main/ets/features/focus/domain/TimerModels'

class MemoryTimerStateRepository implements TimerStateRepository {
  config: TimerConfig | null = null
  snapshot: ActiveTimerSnapshot | null = null
  deviceId: string = ''

  async saveConfig(profileId: string, config: TimerConfig): Promise<void> {
    this.config = config
  }

  async loadConfig(profileId: string): Promise<TimerConfig | null> {
    return this.config
  }

  async saveSnapshot(snapshot: ActiveTimerSnapshot): Promise<void> {
    this.snapshot = snapshot
  }

  async loadSnapshot(profileId: string): Promise<ActiveTimerSnapshot | null> {
    return this.snapshot
  }

  async clearSnapshot(profileId: string): Promise<void> {
    this.snapshot = null
  }

  async getOrCreateDeviceId(profileId: string, idFactory: () => string): Promise<string> {
    if (this.deviceId.length === 0) {
      this.deviceId = idFactory()
    }
    return this.deviceId
  }
}

class MemoryFocusSessionRepository implements FocusSessionRepository {
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

export default function focusTimerCoordinatorTest(): void {
  describe('focusTimerCoordinator', () => {
    it('restoresAndSettlesExpiredSessionIdempotently', 0, async () => {
      const timerState: MemoryTimerStateRepository = new MemoryTimerStateRepository()
      const sessions: MemoryFocusSessionRepository = new MemoryFocusSessionRepository()
      let now: number = 1000
      let idSequence: number = 0
      const coordinator: FocusTimerCoordinator = new FocusTimerCoordinator(
        timerState, sessions, 'guest', () => now, () => {
          idSequence += 1
          return `id-${idSequence}`
        })

      await coordinator.start(null, null)
      now = 1502000
      const restored: TimerRuntimeState = await coordinator.restore()
      expect(restored.snapshot?.state).assertEqual(TimerRunState.COMPLETED)
      expect(sessions.sessions.length).assertEqual(1)
      const sessionId: string = sessions.sessions[0].id

      await coordinator.restore()
      expect(sessions.sessions.length).assertEqual(1)
      expect(sessions.sessions[0].id).assertEqual(sessionId)
    })

    it('persistsCustomConfigurationForNextFlow', 0, async () => {
      const timerState: MemoryTimerStateRepository = new MemoryTimerStateRepository()
      const sessions: MemoryFocusSessionRepository = new MemoryFocusSessionRepository()
      const coordinator: FocusTimerCoordinator = new FocusTimerCoordinator(
        timerState, sessions, 'guest', () => 1000, () => 'stable-id')
      const custom: TimerConfig = {
        focusMinutes: 45, shortBreakMinutes: 8, longBreakMinutes: 20, longBreakEvery: 3
      }
      await coordinator.saveConfig(custom)
      const started: TimerRuntimeState = await coordinator.start('task-1', 'category-1')
      expect(started.snapshot?.plannedSeconds).assertEqual(2700)
      expect(started.snapshot?.taskId).assertEqual('task-1')
      expect(started.snapshot?.categoryId).assertEqual('category-1')
    })
  })
}
