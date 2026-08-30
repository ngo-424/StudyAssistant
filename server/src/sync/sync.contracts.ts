export enum SyncEntityType {
  TASK = 'task',
  CATEGORY = 'category',
  FOCUS_SESSION = 'focus_session',
  REWARD_EVENT = 'reward_event',
  SETTING = 'setting',
}

export enum SyncOperation {
  UPSERT = 'upsert',
  DELETE = 'delete',
}

export enum SyncMutationStatus {
  APPLIED = 'applied',
  CONFLICT = 'conflict',
}

export interface SyncRecordSnapshot {
  entityType: SyncEntityType;
  entityId: string;
  revision: number;
  operation: SyncOperation;
  payload: Record<string, unknown>;
  updatedAt: number;
}

export interface SyncMutationResult {
  mutationId: string;
  status: SyncMutationStatus;
  revision: number;
  serverRecord?: SyncRecordSnapshot;
}

export interface SyncChangePayload extends SyncRecordSnapshot {
  cursor: string;
}
