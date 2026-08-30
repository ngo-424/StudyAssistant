import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  GoneException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash } from 'node:crypto';
import { DataSource, QueryFailedError, Repository } from 'typeorm';
import { ContinuationTransferEntity } from '../database/entities/continuation-transfer.entity';
import { ClaimContinuationDto } from './dto/claim-continuation.dto';
import { PrepareContinuationDto } from './dto/prepare-continuation.dto';
import {
  ContinuationClaimDecision,
  ContinuationTransferStatus,
} from './continuation.contracts';
import { ContinuationRules } from './continuation-rules';

const TRANSFER_TTL_MS = 2 * 60 * 1000;

@Injectable()
export class ContinuationService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(ContinuationTransferEntity)
    private readonly transfers: Repository<ContinuationTransferEntity>,
  ) {}

  async prepare(userId: string, dto: PrepareContinuationDto): Promise<{ expiresAt: string }> {
    const now = new Date();
    const transfer = this.transfers.create({
      tokenHash: this.hash(dto.token),
      userId,
      flowId: dto.flowId,
      phaseSessionId: dto.phaseSessionId,
      sourceDeviceId: dto.sourceDeviceId,
      sourceVersion: dto.sourceVersion,
      expiresAt: new Date(now.getTime() + TRANSFER_TTL_MS),
      claimedAt: null,
      targetDeviceId: null,
      createdAt: now,
    });
    await this.transfers.insert(transfer);
    return { expiresAt: transfer.expiresAt.toISOString() };
  }

  async claim(userId: string, dto: ClaimContinuationDto): Promise<{
    accepted: boolean;
    alreadyClaimed: boolean;
    claimedAt: string;
  }> {
    try {
      return await this.dataSource.transaction(async (manager) => {
      const repository = manager.getRepository(ContinuationTransferEntity);
      const transfer = await repository.findOne({
        where: { tokenHash: this.hash(dto.token) },
        lock: { mode: 'pessimistic_write' },
      });
      if (!transfer || transfer.flowId !== dto.flowId ||
        transfer.phaseSessionId !== dto.phaseSessionId) {
        throw new NotFoundException({ code: 'CONTINUATION_INVALID' });
      }
      const decision = ContinuationRules.decideClaim(transfer, {
        userId,
        targetDeviceId: dto.targetDeviceId,
        targetVersion: dto.targetVersion,
        now: new Date(),
      });
      this.assertClaimable(decision);
      if (decision === ContinuationClaimDecision.ACCEPT) {
        transfer.claimedAt = new Date();
        transfer.targetDeviceId = dto.targetDeviceId;
        await repository.save(transfer);
      }
      return {
        accepted: true,
        alreadyClaimed: decision === ContinuationClaimDecision.IDEMPOTENT,
        claimedAt: transfer.claimedAt!.toISOString(),
      };
      });
    } catch (error) {
      if (error instanceof QueryFailedError &&
        (error.driverError as { code?: string }).code === '23505') {
        throw new ConflictException({ code: 'CONTINUATION_ALREADY_CLAIMED' });
      }
      throw error;
    }
  }

  async status(userId: string, token: string): Promise<{
    status: ContinuationTransferStatus;
    claimedAt: string | null;
  }> {
    const transfer = await this.transfers.findOne({ where: { tokenHash: this.hash(token) } });
    if (!transfer) {
      throw new NotFoundException({ code: 'CONTINUATION_INVALID' });
    }
    if (transfer.userId !== userId) {
      throw new ForbiddenException({ code: 'CONTINUATION_ACCOUNT_MISMATCH' });
    }
    const expired = transfer.claimedAt === null && transfer.expiresAt.getTime() <= Date.now();
    const status = transfer.claimedAt !== null ? ContinuationTransferStatus.CLAIMED :
      (expired ? ContinuationTransferStatus.EXPIRED : ContinuationTransferStatus.PENDING);
    return { status, claimedAt: transfer.claimedAt?.toISOString() ?? null };
  }

  private assertClaimable(decision: ContinuationClaimDecision): void {
    if (decision === ContinuationClaimDecision.ACCEPT ||
      decision === ContinuationClaimDecision.IDEMPOTENT) {
      return;
    }
    if (decision === ContinuationClaimDecision.ACCOUNT_MISMATCH) {
      throw new ForbiddenException({ code: 'CONTINUATION_ACCOUNT_MISMATCH' });
    }
    if (decision === ContinuationClaimDecision.EXPIRED) {
      throw new GoneException({ code: 'CONTINUATION_EXPIRED' });
    }
    if (decision === ContinuationClaimDecision.VERSION_MISMATCH) {
      throw new ConflictException({ code: 'CONTINUATION_VERSION_MISMATCH' });
    }
    if (decision === ContinuationClaimDecision.ALREADY_CLAIMED) {
      throw new ConflictException({ code: 'CONTINUATION_ALREADY_CLAIMED' });
    }
    throw new BadRequestException({ code: 'CONTINUATION_SOURCE_DEVICE' });
  }

  private hash(token: string): string {
    return createHash('sha256').update(token, 'utf8').digest('hex');
  }
}
