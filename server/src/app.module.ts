import 'dotenv/config';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { RefreshTokenEntity } from './database/entities/refresh-token.entity';
import { UserEntity } from './database/entities/user.entity';
import { VerificationCodeEntity } from './database/entities/verification-code.entity';
import { AuthSchema1760000000000 } from './database/migrations/1760000000000-auth-schema';
import { SyncChangeEntity } from './database/entities/sync-change.entity';
import { SyncMutationEntity } from './database/entities/sync-mutation.entity';
import { SyncRecordEntity } from './database/entities/sync-record.entity';
import { SyncSchema1760000001000 } from './database/migrations/1760000001000-sync-schema';
import { HealthController } from './health.controller';
import { RedisModule } from './redis/redis.module';
import { SyncModule } from './sync/sync.module';
import { ContinuationTransferEntity } from './database/entities/continuation-transfer.entity';
import { ContinuationSchema1760000002000 } from './database/migrations/1760000002000-continuation-schema';
import { ContinuationModule } from './continuation/continuation.module';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      url: process.env.DATABASE_URL ??
        'postgresql://study:study_dev_password@127.0.0.1:5432/study_assistant',
      entities: [
        UserEntity,
        VerificationCodeEntity,
        RefreshTokenEntity,
        SyncRecordEntity,
        SyncChangeEntity,
        SyncMutationEntity,
        ContinuationTransferEntity,
      ],
      migrations: [
        AuthSchema1760000000000,
        SyncSchema1760000001000,
        ContinuationSchema1760000002000,
      ],
      migrationsRun: true,
      synchronize: false,
      ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: true } : false,
      logging: false,
    }),
    RedisModule,
    AuthModule,
    SyncModule,
    ContinuationModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
