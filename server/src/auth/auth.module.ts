import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { createAuthConfig, AUTH_CONFIG } from '../config/auth.config';
import { RefreshTokenEntity } from '../database/entities/refresh-token.entity';
import { UserEntity } from '../database/entities/user.entity';
import { VerificationCodeEntity } from '../database/entities/verification-code.entity';
import { AccessTokenGuard } from './access-token.guard';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { MAIL_ADAPTER } from './mail/mail-adapter';
import { SmtpMailAdapter } from './mail/smtp-mail.adapter';
import { RATE_LIMITER } from './rate-limit/rate-limiter';
import { RedisRateLimiter } from './rate-limit/redis-rate-limiter';

@Module({
  imports: [
    JwtModule.register({}),
    TypeOrmModule.forFeature([UserEntity, VerificationCodeEntity, RefreshTokenEntity]),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    AccessTokenGuard,
    { provide: AUTH_CONFIG, useFactory: createAuthConfig },
    { provide: MAIL_ADAPTER, useClass: SmtpMailAdapter },
    { provide: RATE_LIMITER, useClass: RedisRateLimiter },
  ],
  exports: [AccessTokenGuard, JwtModule, AUTH_CONFIG],
})
export class AuthModule {}
