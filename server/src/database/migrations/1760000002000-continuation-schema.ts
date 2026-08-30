import { MigrationInterface, QueryRunner } from 'typeorm';

export class ContinuationSchema1760000002000 implements MigrationInterface {
  name = 'ContinuationSchema1760000002000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS continuation_transfers (
      token_hash varchar(64) PRIMARY KEY,
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      flow_id uuid NOT NULL,
      phase_session_id uuid NOT NULL,
      source_device_id varchar(160) NOT NULL,
      source_version integer NOT NULL,
      expires_at timestamptz NOT NULL,
      claimed_at timestamptz,
      target_device_id varchar(160),
      created_at timestamptz NOT NULL
    )`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_continuation_owner_flow
      ON continuation_transfers(user_id, flow_id)`);
    await queryRunner.query(`CREATE UNIQUE INDEX IF NOT EXISTS idx_continuation_claimed_session
      ON continuation_transfers(user_id, phase_session_id)
      WHERE claimed_at IS NOT NULL`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE IF EXISTS continuation_transfers');
  }
}
