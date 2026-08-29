export const RATE_LIMITER = Symbol('RATE_LIMITER');

export interface RateLimiter {
  consume(scope: string, subject: string, limit: number, windowSeconds: number): Promise<void>;
}
