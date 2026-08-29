export interface AuthenticatedUser {
  userId: string;
  sessionId: string;
}

export interface AuthSessionResponse {
  account: {
    id: string;
    email: string;
  };
  tokens: {
    accessToken: string;
    refreshToken: string;
    accessExpiresAt: string;
    refreshExpiresAt: string;
  };
}

export enum VerificationDecision {
  ACCEPT = 'accept',
  INVALID = 'invalid',
  EXPIRED = 'expired',
  LOCKED = 'locked',
}
