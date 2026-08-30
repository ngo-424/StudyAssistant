import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { SyncChangeEntity } from '../database/entities/sync-change.entity';
import { SyncMutationEntity } from '../database/entities/sync-mutation.entity';
import { SyncRecordEntity } from '../database/entities/sync-record.entity';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([SyncRecordEntity, SyncChangeEntity, SyncMutationEntity]),
  ],
  controllers: [SyncController],
  providers: [SyncService],
})
export class SyncModule {}
