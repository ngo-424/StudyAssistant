import { Column, Entity, Index, PrimaryColumn } from 'typeorm';
import { SyncEntityType, SyncOperation } from '../../sync/sync.contracts';

@Entity({ name: 'sync_records' })
@Index('idx_sync_records_owner_entity', ['userId', 'entityType', 'entityId'], { unique: true })
export class SyncRecordEntity {
  @PrimaryColumn('uuid')
  id!: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @Column({ name: 'entity_type', type: 'varchar', length: 32 })
  entityType!: SyncEntityType;

  @Column({ name: 'entity_id', type: 'varchar', length: 160 })
  entityId!: string;

  @Column({ type: 'integer' })
  revision!: number;

  @Column({ type: 'varchar', length: 16 })
  operation!: SyncOperation;

  @Column({ type: 'jsonb' })
  payload!: Record<string, unknown>;

  @Column({ name: 'client_updated_at', type: 'bigint' })
  clientUpdatedAt!: string;

  @Column({ name: 'server_updated_at', type: 'timestamptz' })
  serverUpdatedAt!: Date;
}
