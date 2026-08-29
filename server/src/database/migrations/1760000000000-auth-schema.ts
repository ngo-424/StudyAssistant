import { MigrationInterface, QueryRunner } from 'typeorm';

export class AuthSchema1760000000000 implements MigrationInterface {
  name = 'AuthSchema1760000000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS users (
      id uuid PRIMARY KEY,
      email_normalized varchar(320) NOT NULL UNIQUE,
      password_hash varchar(255),
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    )`);
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS verification_codes (
      id uuid PRIMARY KEY,
      email_normalized varchar(320) NOT NULL,
      code_hash char(64) NOT NULL,
      expires_at timestamptz NOT NULL,
      consumed_at timestamptz,
      attempt_count integer NOT NULL DEFAULT 0,
      request_ip_hash char(64) NOT NULL,
      device_hash char(64) NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    )`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS idx_verification_email_created
      ON verification_codes(email_normalized, created_at DESC)`);
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS refresh_tokens (
      id uuid PRIMARY KEY,
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token_hash char(64) NOT NULL UNIQUE,
      device_hash char(64) NOT NULL,
      family_id uuid NOT NULL,
      expires_at timestamptz NOT NULL,
      revoked_at timestamptz,
      rotated_to_id uuid,
      created_at timestamptz NOT NULL DEFAULT now()
    )`);
    await queryRunner.query('CREATE INDEX IF NOT EXISTS idx_refresh_family ON refresh_tokens(family_id)');
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE IF EXISTS refresh_tokens');
    await queryRunner.query('DROP TABLE IF EXISTS verification_codes');
    await queryRunner.query('DROP TABLE IF EXISTS users');
  }
}
