import {
  Inject,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'node:crypto';
import { DataSource, EntityManager, IsNull, Repository } from 'typeorm';
import { AuthConfig, AUTH_CONFIG } from '../config/auth.config';
import { RefreshTokenEntity } from '../database/entities/refresh-token.entity';
import { UserEntity } from '../database/entities/user.entity';
import { VerificationCodeEntity } from '../database/entities/verification-code.entity';
import { AuthSecurity } from './auth-security';
import { AuthSessionResponse, VerificationDecision } from './auth.contracts';
import { LogoutDto } from './dto/logout.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RequestCodeDto } from './dto/request-code.dto';
import { VerifyCodeDto } from './dto/verify-code.dto';
import { MailAdapter, MAIL_ADAPTER } from './mail/mail-adapter';
import { RateLimiter, RATE_LIMITER } from './rate-limit/rate-limiter';
import { RefreshTokenDecision, RefreshTokenSecurity } from './refresh-token-security';

interface VerificationOutcome {
  decision: VerificationDecision;
  session?: AuthSessionResponse;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly jwt: JwtService,
    @InjectRepository(UserEntity) private readonly users: Repository<UserEntity>,
    @InjectRepository(VerificationCodeEntity) private readonly codes: Repository<VerificationCodeEntity>,
    @InjectRepository(RefreshTokenEntity) private readonly refreshTokens: Repository<RefreshTokenEntity>,
    @Inject(AUTH_CONFIG) private readonly config: AuthConfig,
    @Inject(MAIL_ADAPTER) private readonly mail: MailAdapter,
    @Inject(RATE_LIMITER) private readonly rateLimiter: RateLimiter,
  ) {}

  async requestCode(dto: RequestCodeDto, ipAddress: string): Promise<{ accepted: true; expiresInSeconds: number }> {
    const email = AuthSecurity.normalizeEmail(dto.email);
    await Promise.all([
      this.rateLimiter.consume('code-email', email, 5, 10 * 60),
      this.rateLimiter.consume('code-ip', ipAddress, 20, 10 * 60),
      this.rateLimiter.consume('code-device', dto.deviceId, 10, 10 * 60),
    ]);

    const now = new Date();
    const code = AuthSecurity.sixDigitCode();
    const record = this.codes.create({
      id: randomUUID(),
      emailNormalized: email,
      codeHash: AuthSecurity.codeDigest(email, code, this.config.codePepper),
      expiresAt: new Date(now.getTime() + this.config.verificationCodeSeconds * 1000),
      consumedAt: null,
      attemptCount: 0,
      requestIpHash: AuthSecurity.digest(ipAddress, this.config.tokenPepper),
      deviceHash: AuthSecurity.digest(dto.deviceId, this.config.tokenPepper),
    });

    await this.dataSource.transaction(async (manager) => {
      await manager.getRepository(VerificationCodeEntity).update(
        { emailNormalized: email, consumedAt: IsNull() },
        { consumedAt: now },
      );
      await manager.getRepository(VerificationCodeEntity).save(record);
    });

    try {
      await this.mail.sendVerificationCode(email, code, this.config.verificationCodeSeconds / 60);
    } catch {
      await this.codes.delete({ id: record.id });
      throw new ServiceUnavailableException({ code: 'MAIL_UNAVAILABLE' });
    }
    return { accepted: true, expiresInSeconds: this.config.verificationCodeSeconds };
  }

  async verifyCode(dto: VerifyCodeDto, ipAddress: string): Promise<AuthSessionResponse> {
    const email = AuthSecurity.normalizeEmail(dto.email);
    await Promise.all([
      this.rateLimiter.consume('verify-email', email, 10, 10 * 60),
      this.rateLimiter.consume('verify-ip', ipAddress, 30, 10 * 60),
      this.rateLimiter.consume('verify-device', dto.deviceId, 15, 10 * 60),
    ]);
    const now = new Date();
    const suppliedHash = AuthSecurity.codeDigest(email, dto.code, this.config.codePepper);
    const outcome = await this.dataSource.transaction(async (manager): Promise<VerificationOutcome> => {
      const codeRepository = manager.getRepository(VerificationCodeEntity);
      const record = await codeRepository.findOne({
        where: { emailNormalized: email, consumedAt: IsNull() },
        order: { createdAt: 'DESC' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!record) {
        return { decision: VerificationDecision.INVALID };
      }
      const expectedDeviceHash = AuthSecurity.digest(dto.deviceId, this.config.tokenPepper);
      const sameDevice = AuthSecurity.safeEqual(record.deviceHash, expectedDeviceHash);
      const decision = sameDevice ? AuthSecurity.evaluateCode(record, suppliedHash, now) :
        VerificationDecision.INVALID;
      if (decision !== VerificationDecision.ACCEPT) {
        record.attemptCount += 1;
        if (decision === VerificationDecision.EXPIRED || record.attemptCount >= 5) {
          record.consumedAt = now;
        }
        await codeRepository.save(record);
        return { decision };
      }

      record.consumedAt = now;
      await codeRepository.save(record);
      const userRepository = manager.getRepository(UserEntity);
      let user = await userRepository.findOne({ where: { emailNormalized: email } });
      if (!user) {
        user = userRepository.create({
          id: randomUUID(),
          emailNormalized: email,
          passwordHash: null,
        });
        await userRepository.save(user);
      }
      const session = await this.issueSession(manager, user, dto.deviceId, now);
      return { decision: VerificationDecision.ACCEPT, session };
    });

    if (outcome.decision !== VerificationDecision.ACCEPT || !outcome.session) {
      throw new UnauthorizedException({
        code: outcome.decision === VerificationDecision.EXPIRED ? 'CODE_EXPIRED' : 'INVALID_CODE',
      });
    }
    return outcome.session;
  }

  async refresh(dto: RefreshTokenDto, ipAddress: string): Promise<AuthSessionResponse> {
    const tokenHash = AuthSecurity.digest(dto.refreshToken, this.config.tokenPepper);
    await Promise.all([
      this.rateLimiter.consume('refresh-token', tokenHash, 8, 10 * 60),
      this.rateLimiter.consume('refresh-ip', ipAddress, 40, 10 * 60),
    ]);
    const now = new Date();
    const result = await this.dataSource.transaction(async (manager): Promise<AuthSessionResponse | null> => {
      const repository = manager.getRepository(RefreshTokenEntity);
      const current = await repository.findOne({
        where: { tokenHash },
        lock: { mode: 'pessimistic_write' },
      });
      if (!current) {
        return null;
      }
      const tokenDecision = RefreshTokenSecurity.evaluate(current, dto.deviceId, this.config.tokenPepper, now);
      if (tokenDecision === RefreshTokenDecision.REPLAYED) {
        await repository.update({ familyId: current.familyId, revokedAt: IsNull() }, { revokedAt: now });
        return null;
      }
      if (tokenDecision !== RefreshTokenDecision.ACCEPT) {
        current.revokedAt = now;
        await repository.save(current);
        return null;
      }

      const user = await manager.getRepository(UserEntity).findOne({ where: { id: current.userId } });
      if (!user) {
        current.revokedAt = now;
        await repository.save(current);
        return null;
      }
      const rotated = await this.issueSession(manager, user, dto.deviceId, now, current.familyId);
      current.revokedAt = now;
      current.rotatedToId = this.readRefreshTokenId(rotated.tokens.refreshToken);
      await repository.save(current);
      return rotated;
    });
    if (!result) {
      throw new UnauthorizedException({ code: 'INVALID_REFRESH_TOKEN' });
    }
    return result;
  }

  async logout(dto: LogoutDto): Promise<{ loggedOut: true }> {
    const tokenHash = AuthSecurity.digest(dto.refreshToken, this.config.tokenPepper);
    await this.refreshTokens.update({ tokenHash, revokedAt: IsNull() }, { revokedAt: new Date() });
    return { loggedOut: true };
  }

  async deleteAccount(userId: string): Promise<{ deleted: true }> {
    await this.dataSource.transaction(async (manager) => {
      const user = await manager.getRepository(UserEntity).findOne({ where: { id: userId } });
      if (!user) {
        return;
      }
      await manager.getRepository(VerificationCodeEntity).delete({ emailNormalized: user.emailNormalized });
      await manager.getRepository(UserEntity).delete({ id: userId });
    });
    return { deleted: true };
  }

  private async issueSession(manager: EntityManager, user: UserEntity, deviceId: string, now: Date,
    familyId: string = randomUUID()): Promise<AuthSessionResponse> {
    const refreshId = randomUUID();
    const secret = AuthSecurity.opaqueToken();
    const rawRefreshToken = `${refreshId}.${secret}`;
    const refreshExpiresAt = new Date(now.getTime() + this.config.refreshTokenSeconds * 1000);
    const refresh = manager.getRepository(RefreshTokenEntity).create({
      id: refreshId,
      userId: user.id,
      user,
      tokenHash: AuthSecurity.digest(rawRefreshToken, this.config.tokenPepper),
      deviceHash: AuthSecurity.digest(deviceId, this.config.tokenPepper),
      familyId,
      expiresAt: refreshExpiresAt,
      revokedAt: null,
      rotatedToId: null,
    });
    await manager.getRepository(RefreshTokenEntity).save(refresh);
    const accessExpiresAt = new Date(now.getTime() + this.config.accessTokenSeconds * 1000);
    const accessToken = await this.jwt.signAsync(
      { sub: user.id, sid: refreshId, type: 'access' },
      {
        secret: this.config.jwtSecret,
        algorithm: 'HS256',
        issuer: 'study-assistant',
        audience: 'study-assistant-app',
        expiresIn: this.config.accessTokenSeconds,
      },
    );
    return {
      account: { id: user.id, email: user.emailNormalized },
      tokens: {
        accessToken,
        refreshToken: rawRefreshToken,
        accessExpiresAt: accessExpiresAt.toISOString(),
        refreshExpiresAt: refreshExpiresAt.toISOString(),
      },
    };
  }

  private readRefreshTokenId(rawToken: string): string {
    return rawToken.split('.', 1)[0];
  }
}
