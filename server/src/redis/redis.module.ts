import { Global, Module, OnApplicationShutdown } from '@nestjs/common';
import Redis from 'ioredis';

export const REDIS_CLIENT = Symbol('REDIS_CLIENT');

class RedisShutdown implements OnApplicationShutdown {
  constructor(private readonly client: Redis) {}

  async onApplicationShutdown(): Promise<void> {
    await this.client.quit();
  }
}

@Global()
@Module({
  providers: [
    {
      provide: REDIS_CLIENT,
      useFactory: (): Redis => new Redis(process.env.REDIS_URL ?? 'redis://127.0.0.1:6379', {
        enableOfflineQueue: false,
        maxRetriesPerRequest: 1,
      }),
    },
    {
      provide: RedisShutdown,
      useFactory: (client: Redis): RedisShutdown => new RedisShutdown(client),
      inject: [REDIS_CLIENT],
    },
  ],
  exports: [REDIS_CLIENT],
})
export class RedisModule {}
