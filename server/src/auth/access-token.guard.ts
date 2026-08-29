import { CanActivate, ExecutionContext, Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { AuthConfig, AUTH_CONFIG } from '../config/auth.config';
import { AuthenticatedUser } from './auth.contracts';

interface AccessPayload {
  sub: string;
  sid: string;
  type: string;
}

export interface AuthenticatedRequest extends Request {
  authUser?: AuthenticatedUser;
}

@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    @Inject(AUTH_CONFIG) private readonly config: AuthConfig,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authorization = request.headers.authorization ?? '';
    const [scheme, token] = authorization.split(' ');
    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException({ code: 'AUTH_REQUIRED' });
    }
    try {
      const payload = await this.jwt.verifyAsync<AccessPayload>(token, {
        secret: this.config.jwtSecret,
        algorithms: ['HS256'],
        issuer: 'study-assistant',
        audience: 'study-assistant-app',
      });
      if (payload.type !== 'access' || !payload.sub || !payload.sid) {
        throw new Error('Invalid access token payload');
      }
      request.authUser = { userId: payload.sub, sessionId: payload.sid };
      return true;
    } catch {
      throw new UnauthorizedException({ code: 'INVALID_ACCESS_TOKEN' });
    }
  }
}
