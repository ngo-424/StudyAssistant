import { GuestDataSummary, SyncConflict, SyncMetadata, SyncMutation } from '../model/StudyModels'

export interface SyncRepository {
  saveMetadata(metadata: SyncMetadata): Promise<void>
  findMetadata(profileId: string, key: string): Promise<SyncMetadata | null>
  removeMetadata(profileId: string, key: string): Promise<void>
  guestSummary(): Promise<GuestDataSummary>
  saveMutation(mutation: SyncMutation): Promise<void>
  findMutations(profileId: string): Promise<SyncMutation[]>
  findMutation(profileId: string, entityType: string, entityId: string): Promise<SyncMutation | null>
  removeMutation(mutationId: string): Promise<void>
  saveConflict(conflict: SyncConflict): Promise<void>
  findConflicts(profileId: string): Promise<SyncConflict[]>
  resolveConflict(id: string, resolvedAt: number): Promise<void>
  deleteGuestData(): Promise<void>
}
