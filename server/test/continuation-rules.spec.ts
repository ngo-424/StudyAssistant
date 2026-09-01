import { ContinuationRules } from '../src/continuation/continuation-rules';
import {
  ContinuationClaimDecision,
  ContinuationClaimInput,
} from '../src/continuation/continuation.contracts';
import { ContinuationTransferEntity } from '../src/database/entities/continuation-transfer.entity';

const NOW = new Date('2026-08-30T08:00:00.000Z');

function transfer(overrides: Partial<ContinuationTransferEntity> = {}): ContinuationTransferEntity {
  return Object.assign(new ContinuationTransferEntity(), {
    tokenHash: 'a'.repeat(64),
    userId: '00000000-0000-4000-8000-000000000001',
    flowId: '00000000-0000-4000-8000-000000000002',
    phaseSessionId: '00000000-0000-4000-8000-000000000003',
    sourceDeviceId: 'source-device',
    sourceVersion: 1_000_000,
    expiresAt: new Date(NOW.getTime() + 60_000),
    claimedAt: null,
    targetDeviceId: null,
    createdAt: NOW,
    ...overrides,
  });
}

function input(overrides: Partial<ContinuationClaimInput> = {}): ContinuationClaimInput {
  return {
    userId: '00000000-0000-4000-8000-000000000001',
    targetDeviceId: 'target-device',
    targetVersion: 1_010_000,
    now: NOW,
    ...overrides,
  };
}

describe('ContinuationRules', () => {
  it('accepts one matching target and makes its retry idempotent', () => {
    expect(ContinuationRules.decideClaim(transfer(), input()))
      .toBe(ContinuationClaimDecision.ACCEPT);
    expect(ContinuationRules.decideClaim(transfer({ claimedAt: NOW, targetDeviceId: 'target-device' }), input()))
      .toBe(ContinuationClaimDecision.IDEMPOTENT);
  });

  it('rejects a second target after ownership was claimed', () => {
    const claimed = transfer({ claimedAt: NOW, targetDeviceId: 'first-target' });
    expect(ContinuationRules.decideClaim(claimed, input({ targetDeviceId: 'second-target' })))
      .toBe(ContinuationClaimDecision.ALREADY_CLAIMED);
  });

  it('keeps ownership at the source for account, network-independent expiry and version failures', () => {
    expect(ContinuationRules.decideClaim(transfer(), input({ userId: 'other-account' })))
      .toBe(ContinuationClaimDecision.ACCOUNT_MISMATCH);
    expect(ContinuationRules.decideClaim(transfer(), input({ targetVersion: 2_000_000 })))
      .toBe(ContinuationClaimDecision.VERSION_MISMATCH);
    expect(ContinuationRules.decideClaim(transfer({ expiresAt: NOW }), input()))
      .toBe(ContinuationClaimDecision.EXPIRED);
  });

  it('does not allow a source device to claim its own transfer token', () => {
    expect(ContinuationRules.decideClaim(transfer(), input({ targetDeviceId: 'source-device' })))
      .toBe(ContinuationClaimDecision.SOURCE_DEVICE);
  });

  it('allows 1.0 and 1.1 devices to exchange protocol v1 payloads', () => {
    expect(ContinuationRules.compatibleVersions(1_000_000, 1_010_000)).toBe(true);
    expect(ContinuationRules.compatibleVersions(1_010_000, 1_000_000)).toBe(true);
    expect(ContinuationRules.compatibleVersions(1_010_000, 1_010_000)).toBe(true);
    expect(ContinuationRules.compatibleVersions(1_010_000, 1_020_000)).toBe(false);
  });
});
