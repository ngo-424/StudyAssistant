import { Column, CreateDateColumn, Entity, Index, PrimaryColumn } from 'typeorm';
import { SyncMutationResult } from '../../sync/sync.contracts';

@Entity({ name: 'sync_mutations' })
@Index('idx_sync_mutations_owner_created', ['userId', 'createdAt'])
export class SyncMutationEntity {
  @PrimaryColumn({ name: 'mutation_id', type: 'uuid' })
  mutationId!: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @Column({ type: 'jsonb' })
  result!: SyncMutationResult;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
