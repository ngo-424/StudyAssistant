import { isDeepStrictEqual } from 'node:util';
import { SyncRecordEntity } from '../database/entities/sync-record.entity';
import { PushMutationDto } from './dto/push-sync.dto';
import { SyncEntityType } from './sync.contracts';

export enum SyncDecision {
  APPLY = 'apply',
  DUPLICATE = 'duplicate',
  CONFLICT = 'conflict',
}

export class SyncRules {
  static readonly APPEND_ONLY: ReadonlySet<SyncEntityType> = new Set([
    SyncEntityType.FOCUS_SESSION,
    SyncEntityType.REWARD_EVENT,
  ]);

  static evaluate(current: SyncRecordEntity | null, mutation: PushMutationDto): SyncDecision {
    if (current === null) {
      return mutation.baseRevision === 0 ? SyncDecision.APPLY : SyncDecision.CONFLICT;
    }
    if (SyncRules.APPEND_ONLY.has(mutation.entityType)) {
      const sameValue = current.operation === mutation.operation &&
        isDeepStrictEqual(current.payload, mutation.payload);
      return sameValue ? SyncDecision.DUPLICATE : SyncDecision.CONFLICT;
    }
    return mutation.baseRevision === current.revision ? SyncDecision.APPLY : SyncDecision.CONFLICT;
  }
}
