import { Body, Controller, Delete, HttpCode, Ip, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthSessionResponse } from './auth.contracts';
import { AccessTokenGuard, AuthenticatedRequest } from './access-token.guard';
import { LogoutDto } from './dto/logout.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RequestCodeDto } from './dto/request-code.dto';
import { VerifyCodeDto } from './dto/verify-code.dto';

@Controller()
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('auth/code/request')
  @HttpCode(202)
  requestCode(@Body() dto: RequestCodeDto, @Ip() ipAddress: string): Promise<{
    accepted: true;
    expiresInSeconds: number;
  }> {
    return this.auth.requestCode(dto, ipAddress);
  }

  @Post('auth/code/verify')
  @HttpCode(200)
  verifyCode(@Body() dto: VerifyCodeDto, @Ip() ipAddress: string): Promise<AuthSessionResponse> {
    return this.auth.verifyCode(dto, ipAddress);
  }

  @Post('auth/refresh')
  @HttpCode(200)
  refresh(@Body() dto: RefreshTokenDto, @Ip() ipAddress: string): Promise<AuthSessionResponse> {
    return this.auth.refresh(dto, ipAddress);
  }

  @Post('auth/logout')
  @HttpCode(200)
  logout(@Body() dto: LogoutDto): Promise<{ loggedOut: true }> {
    return this.auth.logout(dto);
  }

  @Delete('account')
  @UseGuards(AccessTokenGuard)
  deleteAccount(@Req() request: AuthenticatedRequest): Promise<{ deleted: true }> {
    return this.auth.deleteAccount(request.authUser!.userId);
  }
}
