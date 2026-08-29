import { HttpException, HttpStatus, Inject, Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { AuthConfig, AUTH_CONFIG } from '../../config/auth.config';
import { REDIS_CLIENT } from '../../redis/redis.module';
import { AuthSecurity } from '../auth-security';
import { RateLimiter } from './rate-limiter';

@Injectable()
export class RedisRateLimiter implements RateLimiter {
  constructor(
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
    @Inject(AUTH_CONFIG) private readonly config: AuthConfig,
  ) {}

  async consume(scope: string, subject: string, limit: number, windowSeconds: number): Promise<void> {
    const fingerprint = AuthSecurity.digest(subject, this.config.tokenPepper);
    const key = `rate:${scope}:${fingerprint}`;
    const results = await this.redis.multi().incr(key).expire(key, windowSeconds, 'NX').exec();
    const count = Number(results?.[0]?.[1] ?? 0);
    if (count > limit) {
      const retryAfter = Math.max(await this.redis.ttl(key), 1);
      throw new HttpException({ code: 'RATE_LIMITED', retryAfter }, HttpStatus.TOO_MANY_REQUESTS);
    }
  }
}
