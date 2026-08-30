import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard, AuthenticatedRequest } from '../auth/access-token.guard';
import { PullSyncDto } from './dto/pull-sync.dto';
import { PushSyncDto } from './dto/push-sync.dto';
import { SyncService } from './sync.service';

@Controller('sync')
@UseGuards(AccessTokenGuard)
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  @Post('push')
  push(@Req() request: AuthenticatedRequest, @Body() dto: PushSyncDto) {
    return this.sync.push(request.authUser!.userId, dto);
  }

  @Get('pull')
  pull(@Req() request: AuthenticatedRequest, @Query() dto: PullSyncDto) {
    return this.sync.pull(request.authUser!.userId, dto);
  }
}
