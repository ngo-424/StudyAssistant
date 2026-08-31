import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard, AuthenticatedRequest } from '../auth/access-token.guard';
import { ContinuationService } from './continuation.service';
import { ClaimContinuationDto } from './dto/claim-continuation.dto';
import { ContinuationStatusDto } from './dto/continuation-status.dto';
import { PrepareContinuationDto } from './dto/prepare-continuation.dto';

@Controller('continuation')
@UseGuards(AccessTokenGuard)
export class ContinuationController {
  constructor(private readonly continuation: ContinuationService) {}

  @Post('prepare')
  prepare(@Req() request: AuthenticatedRequest, @Body() dto: PrepareContinuationDto) {
    return this.continuation.prepare(request.authUser!.userId, dto);
  }

  @Post('claim')
  claim(@Req() request: AuthenticatedRequest, @Body() dto: ClaimContinuationDto) {
    return this.continuation.claim(request.authUser!.userId, dto);
  }

  @Get('status')
  status(@Req() request: AuthenticatedRequest, @Query() dto: ContinuationStatusDto) {
    return this.continuation.status(request.authUser!.userId, dto.token);
  }
}
