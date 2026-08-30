import { PushMutationDto } from '../src/sync/dto/push-sync.dto';
import { SyncEntityType, SyncOperation } from '../src/sync/sync.contracts';
import { SyncDecision, SyncRules } from '../src/sync/sync-rules';
import { SyncRecordEntity } from '../src/database/entities/sync-record.entity';

function mutation(entityType: SyncEntityType, baseRevision: number,
  payload: Record<string, unknown> = { title: 'Local' }): PushMutationDto {
  return {
    mutationId: '00000000-0000-4000-8000-000000000010',
    entityType,
    entityId: 'entity-1',
    baseRevision,
    operation: SyncOperation.UPSERT,
    payload,
    updatedAt: 1,
  };
}

function record(entityType: SyncEntityType, revision: number,
  payload: Record<string, unknown> = { title: 'Server' }): SyncRecordEntity {
  return Object.assign(new SyncRecordEntity(), {
    id: '00000000-0000-4000-8000-000000000011',
    userId: '00000000-0000-4000-8000-000000000012',
    entityType,
    entityId: 'entity-1',
    revision,
    operation: SyncOperation.UPSERT,
    payload,
    clientUpdatedAt: '1',
    serverUpdatedAt: new Date(),
  });
}

describe('SyncRules', () => {
  it('accepts a new entity only from revision zero', () => {
    expect(SyncRules.evaluate(null, mutation(SyncEntityType.TASK, 0))).toBe(SyncDecision.APPLY);
    expect(SyncRules.evaluate(null, mutation(SyncEntityType.TASK, 2))).toBe(SyncDecision.CONFLICT);
  });

  it('checks mutable entity revisions', () => {
    const current = record(SyncEntityType.TASK, 3);
    expect(SyncRules.evaluate(current, mutation(SyncEntityType.TASK, 3))).toBe(SyncDecision.APPLY);
    expect(SyncRules.evaluate(current, mutation(SyncEntityType.TASK, 2))).toBe(SyncDecision.CONFLICT);
  });

  it('deduplicates identical append-only records and conflicts on changed payloads', () => {
    const current = record(SyncEntityType.FOCUS_SESSION, 1, { focusedSeconds: 1500 });
    expect(SyncRules.evaluate(current,
      mutation(SyncEntityType.FOCUS_SESSION, 0, { focusedSeconds: 1500 })))
      .toBe(SyncDecision.DUPLICATE);
    expect(SyncRules.evaluate(current,
      mutation(SyncEntityType.FOCUS_SESSION, 0, { focusedSeconds: 1200 })))
      .toBe(SyncDecision.CONFLICT);
  });
});
