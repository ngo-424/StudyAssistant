import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'node:crypto';
import { DataSource, EntityManager, MoreThan, Repository } from 'typeorm';
import { SyncChangeEntity } from '../database/entities/sync-change.entity';
import { SyncMutationEntity } from '../database/entities/sync-mutation.entity';
import { SyncRecordEntity } from '../database/entities/sync-record.entity';
import { PullSyncDto } from './dto/pull-sync.dto';
import { PushMutationDto, PushSyncDto } from './dto/push-sync.dto';
import {
  SyncChangePayload,
  SyncMutationResult,
  SyncMutationStatus,
  SyncRecordSnapshot,
} from './sync.contracts';
import { SyncDecision, SyncRules } from './sync-rules';

@Injectable()
export class SyncService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(SyncChangeEntity) private readonly changes: Repository<SyncChangeEntity>,
  ) {}

  async push(userId: string, dto: PushSyncDto): Promise<{ results: SyncMutationResult[] }> {
    const results: SyncMutationResult[] = [];
    for (const mutation of dto.mutations) {
      results.push(await this.dataSource.transaction((manager) => this.apply(manager, userId, mutation)));
    }
    return { results };
  }

  async pull(userId: string, dto: PullSyncDto): Promise<{
    changes: SyncChangePayload[];
    nextCursor: string;
    hasMore: boolean;
  }> {
    const cursor = dto.cursor ?? '0';
    const rows = await this.changes.find({
      where: { userId, id: MoreThan(cursor) },
      order: { id: 'ASC' },
      take: dto.limit + 1,
    });
    const hasMore = rows.length > dto.limit;
    const page = hasMore ? rows.slice(0, dto.limit) : rows;
    return {
      changes: page.map((change) => ({
        cursor: change.id,
        entityType: change.entityType,
        entityId: change.entityId,
        revision: change.revision,
        operation: change.operation,
        payload: change.payload,
        updatedAt: Number(change.clientUpdatedAt),
      })),
      nextCursor: page.at(-1)?.id ?? cursor,
      hasMore,
    };
  }

  private async apply(manager: EntityManager, userId: string,
    mutation: PushMutationDto): Promise<SyncMutationResult> {
    const mutations = manager.getRepository(SyncMutationEntity);
    const processed = await mutations.findOne({ where: { mutationId: mutation.mutationId, userId } });
    if (processed) {
      return processed.result;
    }

    const records = manager.getRepository(SyncRecordEntity);
    const current = await records.findOne({
      where: { userId, entityType: mutation.entityType, entityId: mutation.entityId },
      lock: { mode: 'pessimistic_write' },
    });
    const decision = SyncRules.evaluate(current, mutation);
    if (decision === SyncDecision.CONFLICT) {
      const result: SyncMutationResult = {
        mutationId: mutation.mutationId,
        status: SyncMutationStatus.CONFLICT,
        revision: current?.revision ?? 0,
        serverRecord: current ? this.snapshot(current) : undefined,
      };
      await mutations.save(mutations.create({ mutationId: mutation.mutationId, userId, result }));
      return result;
    }

    if (decision === SyncDecision.DUPLICATE && current) {
      const result: SyncMutationResult = {
        mutationId: mutation.mutationId,
        status: SyncMutationStatus.APPLIED,
        revision: current.revision,
      };
      await mutations.save(mutations.create({ mutationId: mutation.mutationId, userId, result }));
      return result;
    }

    const now = new Date();
    const record = current ?? records.create({
      id: randomUUID(),
      userId,
      entityType: mutation.entityType,
      entityId: mutation.entityId,
    });
    record.revision = (current?.revision ?? 0) + 1;
    record.operation = mutation.operation;
    record.payload = mutation.payload;
    record.clientUpdatedAt = String(mutation.updatedAt);
    record.serverUpdatedAt = now;
    await records.save(record);

    const changes = manager.getRepository(SyncChangeEntity);
    await changes.save(changes.create({
      userId,
      entityType: record.entityType,
      entityId: record.entityId,
      revision: record.revision,
      operation: record.operation,
      payload: record.payload,
      clientUpdatedAt: record.clientUpdatedAt,
      serverUpdatedAt: now,
    }));
    const result: SyncMutationResult = {
      mutationId: mutation.mutationId,
      status: SyncMutationStatus.APPLIED,
      revision: record.revision,
    };
    await mutations.save(mutations.create({ mutationId: mutation.mutationId, userId, result }));
    return result;
  }

  private snapshot(record: SyncRecordEntity): SyncRecordSnapshot {
    return {
      entityType: record.entityType,
      entityId: record.entityId,
      revision: record.revision,
      operation: record.operation,
      payload: record.payload,
      updatedAt: Number(record.clientUpdatedAt),
    };
  }
}
