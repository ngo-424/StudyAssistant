import 'dotenv/config';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { RefreshTokenEntity } from './database/entities/refresh-token.entity';
import { UserEntity } from './database/entities/user.entity';
import { VerificationCodeEntity } from './database/entities/verification-code.entity';
import { AuthSchema1760000000000 } from './database/migrations/1760000000000-auth-schema';
import { HealthController } from './health.controller';
import { RedisModule } from './redis/redis.module';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      url: process.env.DATABASE_URL ??
        'postgresql://study:study_dev_password@127.0.0.1:5432/study_assistant',
      entities: [UserEntity, VerificationCodeEntity, RefreshTokenEntity],
      migrations: [AuthSchema1760000000000],
      migrationsRun: true,
      synchronize: false,
      ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: true } : false,
      logging: false,
    }),
    RedisModule,
    AuthModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
