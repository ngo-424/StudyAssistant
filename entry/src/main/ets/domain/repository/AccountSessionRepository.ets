import { AccountSession } from '../../features/auth/domain/AuthModels'

export interface AccountSessionRepository {
  save(session: AccountSession): Promise<void>
  current(): Promise<AccountSession | null>
  clear(): Promise<void>
}
