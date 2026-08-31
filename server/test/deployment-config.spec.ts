import { productionConfigurationErrors } from '../src/config/deployment.config';

describe('production deployment configuration', () => {
  it('does not constrain the local development environment', () => {
    expect(productionConfigurationErrors({ NODE_ENV: 'development' })).toEqual([]);
  });

  it('rejects loopback, clear-text, and placeholder production services', () => {
    const errors = productionConfigurationErrors({
      NODE_ENV: 'production',
      DATABASE_URL: 'postgresql://user:password@127.0.0.1:5432/db',
      REDIS_URL: 'redis://127.0.0.1:6379',
      DATABASE_SSL: 'false',
      JWT_SECRET: 'a'.repeat(32), CODE_PEPPER: 'b'.repeat(32), TOKEN_PEPPER: 'c'.repeat(32),
      SMTP_HOST: 'localhost', SMTP_PORT: '1025', SMTP_SECURE: 'false', SMTP_REQUIRE_TLS: 'false',
      MAIL_FROM: '时芽 <no-reply@example.local>',
    });
    expect(errors).toContain('DATABASE_URL must not use a loopback host');
    expect(errors).toContain('REDIS_URL must use rediss:');
    expect(errors).toContain('SMTP_HOST must not be a loopback host');
    expect(errors).toContain('MAIL_FROM must use the production sender domain');
  });

  it('accepts encrypted production endpoints and a real sender domain', () => {
    expect(productionConfigurationErrors({
      NODE_ENV: 'production',
      DATABASE_URL: 'postgresql://user:password@db.internal.example.cn:5432/shiya',
      REDIS_URL: 'rediss://redis.internal.example.cn:6380',
      DATABASE_SSL: 'true',
      JWT_SECRET: 'a'.repeat(32), CODE_PEPPER: 'b'.repeat(32), TOKEN_PEPPER: 'c'.repeat(32),
      SMTP_HOST: 'smtp.mail-provider.cn', SMTP_PORT: '465', SMTP_SECURE: 'true',
      SMTP_REQUIRE_TLS: 'false', MAIL_FROM: '时芽 <no-reply@shiya.cn>',
    })).toEqual([]);
  });
});
