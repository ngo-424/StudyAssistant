import { MigrationInterface, QueryRunner } from 'typeorm';

export class SyncSchema1760000001000 implements MigrationInterface {
  name = 'SyncSchema1760000001000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS sync_records (
      id uuid PRIMARY KEY,
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      entity_type varchar(32) NOT NULL,
      entity_id varchar(160) NOT NULL,
      revision integer NOT NULL,
      operation varchar(16) NOT NULL,
      payload jsonb NOT NULL,
      client_updated_at bigint NOT NULL,
      server_updated_at timestamptz NOT NULL,
      CONSTRAINT uq_sync_records_owner_entity UNIQUE(user_id, entity_type, entity_id)
    )`);
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS sync_changes (
      id bigserial PRIMARY KEY,
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      entity_type varchar(32) NOT NULL,
      entity_id varchar(160) NOT NULL,
      revision integer NOT NULL,
      operation varchar(16) NOT NULL,
      payload jsonb NOT NULL,
      client_updated_at bigint NOT NULL,
      server_updated_at timestamptz NOT NULL
    )`);
    await queryRunner.query('CREATE INDEX IF NOT EXISTS idx_sync_changes_owner_cursor ON sync_changes(user_id, id)');
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS sync_mutations (
      mutation_id uuid PRIMARY KEY,
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      result jsonb NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    )`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_sync_mutations_owner_created
      ON sync_mutations(user_id, created_at)`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE IF EXISTS sync_mutations');
    await queryRunner.query('DROP TABLE IF EXISTS sync_changes');
    await queryRunner.query('DROP TABLE IF EXISTS sync_records');
  }
}
