export interface AuthConfig {
  jwtSecret: string;
  codePepper: string;
  tokenPepper: string;
  verificationCodeSeconds: number;
  accessTokenSeconds: number;
  refreshTokenSeconds: number;
}

export const AUTH_CONFIG = Symbol('AUTH_CONFIG');

function secret(name: string, developmentFallback: string): string {
  const value = process.env[name]?.trim();
  if (value) {
    return value;
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error(`${name} must be configured in production`);
  }
  return developmentFallback;
}

export function createAuthConfig(): AuthConfig {
  return {
    jwtSecret: secret('JWT_SECRET', 'development-jwt-secret-change-before-deploy'),
    codePepper: secret('CODE_PEPPER', 'development-code-pepper-change-before-deploy'),
    tokenPepper: secret('TOKEN_PEPPER', 'development-token-pepper-change-before-deploy'),
    verificationCodeSeconds: 10 * 60,
    accessTokenSeconds: 15 * 60,
    refreshTokenSeconds: 30 * 24 * 60 * 60,
  };
}
