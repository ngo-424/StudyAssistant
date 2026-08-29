import { Column, CreateDateColumn, Entity, Index, PrimaryColumn } from 'typeorm';

@Entity({ name: 'verification_codes' })
@Index('idx_verification_email_created', ['emailNormalized', 'createdAt'])
export class VerificationCodeEntity {
  @PrimaryColumn('uuid')
  id!: string;

  @Column({ name: 'email_normalized', type: 'varchar', length: 320 })
  emailNormalized!: string;

  @Column({ name: 'code_hash', type: 'char', length: 64 })
  codeHash!: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt!: Date;

  @Column({ name: 'consumed_at', type: 'timestamptz', nullable: true })
  consumedAt!: Date | null;

  @Column({ name: 'attempt_count', type: 'integer', default: 0 })
  attemptCount!: number;

  @Column({ name: 'request_ip_hash', type: 'char', length: 64 })
  requestIpHash!: string;

  @Column({ name: 'device_hash', type: 'char', length: 64 })
  deviceHash!: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
