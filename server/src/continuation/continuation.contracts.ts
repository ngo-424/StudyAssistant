export enum ContinuationClaimDecision {
  ACCEPT = 'accept',
  IDEMPOTENT = 'idempotent',
  ACCOUNT_MISMATCH = 'account_mismatch',
  ALREADY_CLAIMED = 'already_claimed',
  EXPIRED = 'expired',
  VERSION_MISMATCH = 'version_mismatch',
  SOURCE_DEVICE = 'source_device',
}

export enum ContinuationTransferStatus {
  PENDING = 'pending',
  CLAIMED = 'claimed',
  EXPIRED = 'expired',
}

export interface ContinuationClaimInput {
  userId: string;
  targetDeviceId: string;
  targetVersion: number;
  now: Date;
}
