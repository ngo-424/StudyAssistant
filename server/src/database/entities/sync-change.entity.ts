import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';
import { SyncEntityType, SyncOperation } from '../../sync/sync.contracts';

@Entity({ name: 'sync_changes' })
export class SyncChangeEntity {
  @PrimaryGeneratedColumn({ type: 'bigint' })
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
