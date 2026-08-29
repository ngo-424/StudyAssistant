import { HttpException } from '@nestjs/common';
import Redis from 'ioredis';
import { RedisRateLimiter } from '../src/auth/rate-limit/redis-rate-limiter';
import { AuthConfig } from '../src/config/auth.config';

class FakeRedis {
  count = 1;
  capturedKey = '';

  multi(): FakeRedisMulti {
    return new FakeRedisMulti(this);
  }

  async ttl(): Promise<number> {
    return 42;
  }
}

class FakeRedisMulti {
  private readonly redis: FakeRedis;

  constructor(redis: FakeRedis) {
    this.redis = redis;
  }

  incr(key: string): FakeRedisMulti {
    this.redis.capturedKey = key;
    return this;
  }

  expire(): FakeRedisMulti {
    return this;
  }

  async exec(): Promise<Array<[Error | null, number]>> {
    return [[null, this.redis.count], [null, 1]];
  }
}

const config: AuthConfig = {
  jwtSecret: 'test-jwt-secret-with-sufficient-entropy',
  codePepper: 'test-code-pepper-with-sufficient-entropy',
  tokenPepper: 'test-token-pepper-with-sufficient-entropy',
  verificationCodeSeconds: 600,
  accessTokenSeconds: 900,
  refreshTokenSeconds: 2_592_000,
};

describe('RedisRateLimiter', () => {
  it('uses a privacy-safe subject fingerprint and accepts requests within the window', async () => {
    const redis = new FakeRedis();
    const limiter = new RedisRateLimiter(redis as unknown as Redis, config);
    await expect(limiter.consume('code-email', 'learner@example.com', 5, 600)).resolves.toBeUndefined();
    expect(redis.capturedKey).not.toContain('learner@example.com');
  });

  it('rejects requests above the fixed-window limit', async () => {
    const redis = new FakeRedis();
    redis.count = 6;
    const limiter = new RedisRateLimiter(redis as unknown as Redis, config);
    await expect(limiter.consume('code-email', 'learner@example.com', 5, 600))
      .rejects.toBeInstanceOf(HttpException);
  });
});
