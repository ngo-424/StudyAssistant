import { ContinuationTransferEntity } from '../database/entities/continuation-transfer.entity';
import { ContinuationClaimDecision, ContinuationClaimInput } from './continuation.contracts';

export class ContinuationRules {
  private static readonly VERSION_1_0 = 1_000_000;
  private static readonly VERSION_1_1 = 1_010_000;

  static decideClaim(transfer: ContinuationTransferEntity,
    input: ContinuationClaimInput): ContinuationClaimDecision {
    if (transfer.userId !== input.userId) {
      return ContinuationClaimDecision.ACCOUNT_MISMATCH;
    }
    if (transfer.sourceDeviceId === input.targetDeviceId) {
      return ContinuationClaimDecision.SOURCE_DEVICE;
    }
    if (!ContinuationRules.compatibleVersions(transfer.sourceVersion, input.targetVersion)) {
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

  static compatibleVersions(sourceVersion: number, targetVersion: number): boolean {
    const supportedSource = sourceVersion === ContinuationRules.VERSION_1_0 ||
      sourceVersion === ContinuationRules.VERSION_1_1;
    const supportedTarget = targetVersion === ContinuationRules.VERSION_1_0 ||
      targetVersion === ContinuationRules.VERSION_1_1;
    return supportedSource && supportedTarget;
  }
}
