import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { ContinuationTransferEntity } from '../database/entities/continuation-transfer.entity';
import { ContinuationController } from './continuation.controller';
import { ContinuationService } from './continuation.service';

@Module({
  imports: [AuthModule, TypeOrmModule.forFeature([ContinuationTransferEntity])],
  controllers: [ContinuationController],
  providers: [ContinuationService],
})
export class ContinuationModule {}
