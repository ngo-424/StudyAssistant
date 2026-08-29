import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AccessTokenGuard, AuthenticatedRequest } from '../src/auth/access-token.guard';
import { AuthConfig } from '../src/config/auth.config';

const config: AuthConfig = {
  jwtSecret: 'test-jwt-secret-with-sufficient-entropy',
  codePepper: 'test-code-pepper-with-sufficient-entropy',
  tokenPepper: 'test-token-pepper-with-sufficient-entropy',
  verificationCodeSeconds: 600,
  accessTokenSeconds: 900,
  refreshTokenSeconds: 2_592_000,
};

function context(request: Partial<AuthenticatedRequest>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

describe('AccessTokenGuard', () => {
  const jwt = new JwtService();
  const guard = new AccessTokenGuard(jwt, config);

  it('rejects a request without bearer authentication', async () => {
    await expect(guard.canActivate(context({ headers: {} }))).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('accepts a valid 15-minute access token and attaches only identifiers', async () => {
    const token = await jwt.signAsync(
      { sub: 'user-id', sid: 'session-id', type: 'access' },
      {
        secret: config.jwtSecret,
        algorithm: 'HS256',
        issuer: 'study-assistant',
        audience: 'study-assistant-app',
        expiresIn: config.accessTokenSeconds,
      },
    );
    const request = { headers: { authorization: `Bearer ${token}` } } as Partial<AuthenticatedRequest>;
    await expect(guard.canActivate(context(request))).resolves.toBe(true);
    expect(request.authUser).toEqual({ userId: 'user-id', sessionId: 'session-id' });
  });

  it('rejects a token with the wrong purpose', async () => {
    const token = await jwt.signAsync(
      { sub: 'user-id', sid: 'session-id', type: 'refresh' },
      {
        secret: config.jwtSecret,
        issuer: 'study-assistant',
        audience: 'study-assistant-app',
        expiresIn: 900,
      },
    );
    await expect(guard.canActivate(context({ headers: { authorization: `Bearer ${token}` } })))
      .rejects.toBeInstanceOf(UnauthorizedException);
  });
});
