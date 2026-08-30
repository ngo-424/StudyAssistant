import { GUEST_PROFILE_ID } from '../../../data/database/DatabaseSchema'

export class ProfileContext {
  private static profileId: string = GUEST_PROFILE_ID
  private static accountId: string | null = null

  static currentProfileId(): string {
    return ProfileContext.profileId
  }

  static currentAccountId(): string | null {
    return ProfileContext.accountId
  }

  static accountProfileId(accountId: string): string {
    return `account:${accountId}`
  }

  static activateAccount(accountId: string): void {
    ProfileContext.accountId = accountId
    ProfileContext.profileId = ProfileContext.accountProfileId(accountId)
  }

  static activateGuest(): void {
    ProfileContext.accountId = null
    ProfileContext.profileId = GUEST_PROFILE_ID
  }

  static isGuest(): boolean {
    return ProfileContext.profileId === GUEST_PROFILE_ID
  }
}
