import { ContinuationTransferEntity } from '../database/entities/continuation-transfer.entity';
import { ContinuationClaimDecision, ContinuationClaimInput } from './continuation.contracts';

export class ContinuationRules {
  static decideClaim(transfer: ContinuationTransferEntity,
    input: ContinuationClaimInput): ContinuationClaimDecision {
    if (transfer.userId !== input.userId) {
      return ContinuationClaimDecision.ACCOUNT_MISMATCH;
    }
    if (transfer.sourceDeviceId === input.targetDeviceId) {
      return ContinuationClaimDecision.SOURCE_DEVICE;
    }
    if (transfer.sourceVersion !== input.targetVersion) {
      return ContinuationClaimDecision.VERSION_MISMATCH;
    }
    if (transfer.expiresAt.getTime() <= input.now.getTime()) {
      return ContinuationClaimDecision.EXPIRED;
    }
    if (transfer.claimedAt !== null) {
      return transfer.targetDeviceId === input.targetDeviceId ?
        ContinuationClaimDecision.IDEMPOTENT : ContinuationClaimDecision.ALREADY_CLAIMED;
    }
    return ContinuationClaimDecision.ACCEPT;
  }
}
