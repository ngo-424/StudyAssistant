import { Column, CreateDateColumn, Entity, OneToMany, PrimaryColumn, UpdateDateColumn } from 'typeorm';
import { RefreshTokenEntity } from './refresh-token.entity';

@Entity({ name: 'users' })
export class UserEntity {
  @PrimaryColumn('uuid')
  id!: string;

  @Column({ name: 'email_normalized', type: 'varchar', length: 320, unique: true })
  emailNormalized!: string;

  @Column({ name: 'password_hash', type: 'varchar', length: 255, nullable: true })
  passwordHash!: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;

  @OneToMany(() => RefreshTokenEntity, (token) => token.user)
  refreshTokens!: RefreshTokenEntity[];
}
