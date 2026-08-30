import { Column, Entity, Index, PrimaryColumn } from 'typeorm';

@Entity({ name: 'continuation_transfers' })
@Index('idx_continuation_owner_flow', ['userId', 'flowId'])
export class ContinuationTransferEntity {
  @PrimaryColumn({ name: 'token_hash', type: 'varchar', length: 64 })
  tokenHash!: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @Column({ name: 'flow_id', type: 'uuid' })
  flowId!: string;

  @Column({ name: 'phase_session_id', type: 'uuid' })
  phaseSessionId!: string;

  @Column({ name: 'source_device_id', type: 'varchar', length: 160 })
  sourceDeviceId!: string;

  @Column({ name: 'source_version', type: 'integer' })
  sourceVersion!: number;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt!: Date;

  @Column({ name: 'claimed_at', type: 'timestamptz', nullable: true })
  claimedAt!: Date | null;

  @Column({ name: 'target_device_id', type: 'varchar', length: 160, nullable: true })
  targetDeviceId!: string | null;

  @Column({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
