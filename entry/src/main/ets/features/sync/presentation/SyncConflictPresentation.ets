import { SyncConflict, SyncEntityType } from '../../../domain/model/StudyModels'

interface TaskPayload {
  title: string
  notes: string
  plannedMinutes: number
  updatedAt: number
}

interface CategoryPayload {
  name: string
  updatedAt: number
}

interface FocusPayload {
  focusedSeconds: number
  endedAt: number
  updatedAt: number
}

interface RewardPayload {
  awardedPoints: number
  awardedAt: number
}

interface SettingPayload {
  value: string
  updatedAt: number
}

export interface SyncConflictVersionDisplay {
  name: string
  content: string
  modifiedText: string
}

export interface SyncConflictDisplay {
  title: string
  local: SyncConflictVersionDisplay
  cloud: SyncConflictVersionDisplay
  previewable: boolean
}

export class SyncConflictPresentation {
  static map(conflict: SyncConflict): SyncConflictDisplay {
    const local: SyncConflictVersionDisplay | null = SyncConflictPresentation.parse(
      conflict.entityType, conflict.localPayload)
    const cloud: SyncConflictVersionDisplay | null = SyncConflictPresentation.parse(
      conflict.entityType, conflict.serverPayload)
    const fallback: SyncConflictVersionDisplay = {
      name: '内容暂时无法读取',
      content: '为保护数据，请稍后重试同步后再处理。',
      modifiedText: '修改时间未知'
    }
    return {
      title: SyncConflictPresentation.title(conflict.entityType),
      local: local ?? fallback,
      cloud: cloud ?? fallback,
      previewable: local !== null && cloud !== null
    }
  }

  private static parse(type: SyncEntityType, payload: string): SyncConflictVersionDisplay | null {
    try {
      if (type === SyncEntityType.TASK) {
        const task: TaskPayload = JSON.parse(payload) as TaskPayload
        if (typeof task.title !== 'string' || typeof task.notes !== 'string' ||
          typeof task.plannedMinutes !== 'number' || !SyncConflictPresentation.validTime(task.updatedAt)) {
          return null
        }
        return {
          name: task.title,
          content: task.notes.length > 0 ? SyncConflictPresentation.short(task.notes) :
            `计划专注 ${task.plannedMinutes} 分钟`,
          modifiedText: SyncConflictPresentation.time(task.updatedAt)
        }
      }
      if (type === SyncEntityType.CATEGORY) {
        const category: CategoryPayload = JSON.parse(payload) as CategoryPayload
        if (typeof category.name !== 'string' || !SyncConflictPresentation.validTime(category.updatedAt)) {
          return null
        }
        return {
          name: category.name,
          content: '任务类别的名称或颜色有所不同',
          modifiedText: SyncConflictPresentation.time(category.updatedAt)
        }
      }
      if (type === SyncEntityType.FOCUS_SESSION) {
        const session: FocusPayload = JSON.parse(payload) as FocusPayload
        if (typeof session.focusedSeconds !== 'number' || !SyncConflictPresentation.validTime(session.updatedAt) ||
          !SyncConflictPresentation.validTime(session.endedAt)) {
          return null
        }
        return {
          name: '一次专注记录',
          content: `专注 ${Math.max(1, Math.round(session.focusedSeconds / 60))} 分钟`,
          modifiedText: SyncConflictPresentation.time(session.updatedAt)
        }
      }
      if (type === SyncEntityType.REWARD_EVENT) {
        const reward: RewardPayload = JSON.parse(payload) as RewardPayload
        if (typeof reward.awardedPoints !== 'number' || !SyncConflictPresentation.validTime(reward.awardedAt)) {
          return null
        }
        return {
          name: '一次专注积分记录',
          content: `${reward.awardedPoints} 积分`,
          modifiedText: SyncConflictPresentation.time(reward.awardedAt)
        }
      }
      if (type === SyncEntityType.SETTING) {
        const setting: SettingPayload = JSON.parse(payload) as SettingPayload
        if (typeof setting.value !== 'string' || !SyncConflictPresentation.validTime(setting.updatedAt)) {
          return null
        }
        return {
          name: '专注与休息设置',
          content: '时长或自动开始偏好有所不同',
          modifiedText: SyncConflictPresentation.time(setting.updatedAt)
        }
      }
    } catch (_) {
      return null
    }
    return null
  }

  private static title(type: SyncEntityType): string {
    if (type === SyncEntityType.TASK) {
      return '任务在两台设备上都改过'
    }
    if (type === SyncEntityType.CATEGORY) {
      return '任务类别在两台设备上都改过'
    }
    if (type === SyncEntityType.FOCUS_SESSION) {
      return '专注记录需要确认'
    }
    if (type === SyncEntityType.REWARD_EVENT) {
      return '积分记录需要确认'
    }
    return '专注设置在两台设备上都改过'
  }

  private static validTime(value: number): boolean {
    return typeof value === 'number' && Number.isFinite(value) && value > 0
  }

  private static short(value: string): string {
    return value.length > 72 ? `${value.substring(0, 72)}…` : value
  }

  private static time(value: number): string {
    const date: Date = new Date(value)
    const month: number = date.getMonth() + 1
    const day: number = date.getDate()
    const hours: string = date.getHours() < 10 ? `0${date.getHours()}` : `${date.getHours()}`
    const minutes: string = date.getMinutes() < 10 ? `0${date.getMinutes()}` : `${date.getMinutes()}`
    return `${month}月${day}日 ${hours}:${minutes} 修改`
  }
}
