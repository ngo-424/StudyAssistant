import { util } from '@kit.ArkTS'
import { AppInitializer } from '../../../app/AppInitializer'
import { RepositoryRegistry } from '../../../data/repository/RepositoryRegistry'
import { ActiveTimerSnapshot, SettingEntry, TimerRunState } from '../../../domain/model/StudyModels'
import { SettingsRepository, TimerStateRepository } from '../../../domain/repository/StudyRepositories'
import { AuthService } from '../../auth/application/AuthService'
import { AccountSession } from '../../auth/domain/AuthModels'
import { HarmonyAuthApi } from '../../auth/infrastructure/HarmonyAuthApi'
import { TimerRuntimeState, TimerControlGuard } from '../../focus/domain/TimerModels'
import { ProfileContext } from '../../sync/application/ProfileContext'
import { ContinuationApi, ContinuationApiError } from '../domain/ContinuationApi'
import {
  CONTINUATION_APP_VERSION_CODE,
  CONTINUATION_PROTOCOL_VERSION,
  ClaimContinuationBody,
  ContinuationControlRecord,
  ContinuationControlState,
  ContinuationEnvelope,
  ContinuationRemoteStatus,
  ContinuationStatus,
  PrepareContinuationBody,
  PrepareContinuationResult
} from '../domain/ContinuationModels'
import { ContinuationRules } from '../domain/ContinuationRules'
import { HarmonyContinuationApi } from '../infrastructure/HarmonyContinuationApi'
import { ContinuationBridge } from './ContinuationBridge'

const CONTROL_KEY: string = 'focus_continuation_control_v1'
const MIN_OFFER_LIFETIME_MS: number = 5000
const POLL_INTERVAL_MS: number = 5000

export class FocusContinuationService implements TimerControlGuard {
  private static instance: FocusContinuationService | null = null
  private readonly api: ContinuationApi
  private readonly settings: SettingsRepository
  private readonly timerState: TimerStateRepository
  private readonly auth: AuthService
  private readonly clock: () => number
  private volatileStatus: ContinuationStatus | null = null

  constructor(api: ContinuationApi, settings: SettingsRepository, timerState: TimerStateRepository,
    auth: AuthService, clock: () => number = () => Date.now()) {
    this.api = api
    this.settings = settings
    this.timerState = timerState
    this.auth = auth
    this.clock = clock
  }

  static shared(): FocusContinuationService {
    if (FocusContinuationService.instance === null) {
      const auth: AuthService = new AuthService(
        new HarmonyAuthApi(), RepositoryRegistry.accountSession(),
        () => RepositoryRegistry.timerState().getOrCreateDeviceId(
          ProfileContext.currentProfileId(), () => AuthService.fallbackDeviceId()))
      FocusContinuationService.instance = new FocusContinuationService(
        new HarmonyContinuationApi(), RepositoryRegistry.settings(), RepositoryRegistry.timerState(), auth)
    }
    return FocusContinuationService.instance
  }

  async createTransferPayload(): Promise<string> {
    await AppInitializer.whenReady()
    const session: AccountSession = await this.auth.sessionForRequest()
    const profileId: string = ProfileContext.accountProfileId(session.accountId)
    const snapshot = await this.timerState.loadSnapshot(profileId)
    if (snapshot === null || (snapshot.state !== TimerRunState.RUNNING &&
      snapshot.state !== TimerRunState.PAUSED)) {
      throw new Error('CONTINUATION_TIMER_NOT_ACTIVE')
    }
    let record: ContinuationControlRecord | null = await this.loadRecord(profileId)
    if (!this.reusable(record, snapshot.phaseSessionId)) {
      record = await this.prepare(session, snapshot.flowId, snapshot.phaseSessionId)
    }
    const activeRecord: ContinuationControlRecord = record as ContinuationControlRecord
    const envelope: ContinuationEnvelope = {
      protocolVersion: CONTINUATION_PROTOCOL_VERSION,
      appVersionCode: CONTINUATION_APP_VERSION_CODE,
      accountId: session.accountId,
      sourceDeviceId: session.deviceId,
      token: activeRecord.token,
      preparedAt: this.clock(),
      expiresAt: activeRecord.expiresAt,
      snapshot: snapshot
    }
    activeRecord.state = ContinuationControlState.TRANSFER_PENDING
    activeRecord.errorCode = ''
    activeRecord.updatedAt = this.clock()
    await this.saveRecord(profileId, activeRecord)
    return ContinuationRules.encode(envelope)
  }

  async acceptPending(): Promise<boolean> {
    const payload: string = ContinuationBridge.pending()
    if (payload.length === 0) {
      return false
    }
    const envelope: ContinuationEnvelope | null = ContinuationRules.decode(payload)
    if (envelope === null) {
      this.volatileStatus = this.failedStatus('接续数据无效，原设备将继续计时', false)
      ContinuationBridge.clear()
      return false
    }
    try {
      const session: AccountSession = await this.auth.sessionForRequest()
      if (session.accountId !== envelope.accountId) {
        this.volatileStatus = this.failedStatus('应用账号不同，原设备将继续计时', false)
        ContinuationBridge.clear()
        return false
      }
      const profileId: string = ProfileContext.accountProfileId(session.accountId)
      const existing = await this.timerState.loadSnapshot(profileId)
      if (existing !== null && existing.flowId !== envelope.snapshot.flowId &&
        (existing.state === TimerRunState.RUNNING || existing.state === TimerRunState.PAUSED)) {
        this.volatileStatus = this.failedStatus('本机已有进行中的计时，未接管其他设备', true)
        return false
      }
      const body: ClaimContinuationBody = {
        token: envelope.token,
        flowId: envelope.snapshot.flowId,
        phaseSessionId: envelope.snapshot.phaseSessionId,
        targetDeviceId: session.deviceId,
        targetVersion: CONTINUATION_APP_VERSION_CODE
      }
      await this.api.claim(session.accessToken, body)
      envelope.snapshot.profileId = profileId
      await this.timerState.saveSnapshot(envelope.snapshot)
      await this.saveRecord(profileId, {
        flowId: envelope.snapshot.flowId,
        phaseSessionId: envelope.snapshot.phaseSessionId,
        token: envelope.token,
        state: ContinuationControlState.TARGET_CONTROL,
        expiresAt: envelope.expiresAt,
        lastPolledAt: this.clock(),
        errorCode: '',
        updatedAt: this.clock()
      })
      this.volatileStatus = null
      ContinuationBridge.clear()
      return true
    } catch (error) {
      const code: string = error instanceof ContinuationApiError ? error.errorCode : 'NETWORK_UNAVAILABLE'
      const retry: boolean = code === 'NETWORK_UNAVAILABLE' || code === 'CONTINUATION_REQUEST_FAILED'
      this.volatileStatus = this.failedStatus(this.errorMessage(code), retry)
      if (!retry) {
        ContinuationBridge.clear()
      }
      return false
    }
  }

  async update(runtime: TimerRuntimeState, pollRemote: boolean): Promise<ContinuationStatus> {
    if (ProfileContext.isGuest()) {
      return this.volatileStatus ?? this.statusFor(ContinuationControlState.GUEST, '')
    }
    if (runtime.snapshot === null) {
      return this.volatileStatus ?? this.statusFor(ContinuationControlState.IDLE, '')
    }
    if (runtime.snapshot.state !== TimerRunState.RUNNING && runtime.snapshot.state !== TimerRunState.PAUSED) {
      return this.statusFor(ContinuationControlState.IDLE, '')
    }
    const profileId: string = runtime.snapshot.profileId
    let record: ContinuationControlRecord | null = await this.loadRecord(profileId)
    if (record !== null && record.phaseSessionId === runtime.snapshot.phaseSessionId &&
      (record.state === ContinuationControlState.TRANSFERRED ||
        record.state === ContinuationControlState.TARGET_CONTROL)) {
      return this.statusFor(record.state, record.errorCode)
    }
    try {
      const session: AccountSession = await this.auth.sessionForRequest()
      if (record === null || !this.reusable(record, runtime.snapshot.phaseSessionId)) {
        record = await this.prepare(session, runtime.snapshot.flowId, runtime.snapshot.phaseSessionId)
      }
      if (pollRemote && this.clock() - record.lastPolledAt >= POLL_INTERVAL_MS) {
        const remote: ContinuationRemoteStatus = await this.api.status(session.accessToken, record.token)
        record.lastPolledAt = this.clock()
        if (remote.status === 'claimed') {
          record.state = ContinuationControlState.TRANSFERRED
        } else if (remote.status === 'expired') {
          record = await this.prepare(session, runtime.snapshot.flowId, runtime.snapshot.phaseSessionId)
        } else if (record.state !== ContinuationControlState.TRANSFER_PENDING) {
          record.state = ContinuationControlState.READY
        }
        record.errorCode = ''
        record.updatedAt = this.clock()
        await this.saveRecord(profileId, record)
      }
      this.volatileStatus = null
      return this.statusFor(record.state, record.errorCode)
    } catch (error) {
      const code: string = error instanceof ContinuationApiError ? error.errorCode : 'NETWORK_UNAVAILABLE'
      if (record !== null) {
        record.state = ContinuationControlState.OFFLINE
        record.errorCode = code
        record.updatedAt = this.clock()
        await this.saveRecord(profileId, record)
      }
      return this.statusFor(ContinuationControlState.OFFLINE, code)
    }
  }

  async canControl(snapshot: ActiveTimerSnapshot): Promise<boolean> {
    const record: ContinuationControlRecord | null = await this.loadRecord(snapshot.profileId)
    return record === null || record.phaseSessionId !== snapshot.phaseSessionId ||
      record.state !== ContinuationControlState.TRANSFERRED
  }

  currentVolatileStatus(): ContinuationStatus | null {
    return this.volatileStatus
  }

  private async prepare(session: AccountSession, flowId: string,
    phaseSessionId: string): Promise<ContinuationControlRecord> {
    const token: string = `${util.generateRandomUUID(true)}${util.generateRandomUUID(true)}`
    const body: PrepareContinuationBody = {
      token: token,
      flowId: flowId,
      phaseSessionId: phaseSessionId,
      sourceDeviceId: session.deviceId,
      sourceVersion: CONTINUATION_APP_VERSION_CODE
    }
    const result: PrepareContinuationResult = await this.api.prepare(session.accessToken, body)
    const record: ContinuationControlRecord = {
      flowId: flowId,
      phaseSessionId: phaseSessionId,
      token: token,
      state: ContinuationControlState.READY,
      expiresAt: Date.parse(result.expiresAt),
      lastPolledAt: this.clock(),
      errorCode: '',
      updatedAt: this.clock()
    }
    await this.saveRecord(ProfileContext.accountProfileId(session.accountId), record)
    return record
  }

  private reusable(record: ContinuationControlRecord | null, phaseSessionId: string): boolean {
    return record !== null && record.phaseSessionId === phaseSessionId && record.token.length >= 32 &&
      record.expiresAt - this.clock() > MIN_OFFER_LIFETIME_MS &&
      record.state !== ContinuationControlState.TRANSFERRED
  }

  private async loadRecord(profileId: string): Promise<ContinuationControlRecord | null> {
    const entry: SettingEntry | null = await this.settings.find(profileId, CONTROL_KEY)
    if (entry === null) {
      return null
    }
    try {
      return JSON.parse(entry.value) as ContinuationControlRecord
    } catch (error) {
      return null
    }
  }

  private saveRecord(profileId: string, record: ContinuationControlRecord): Promise<void> {
    return this.settings.save({
      profileId: profileId,
      key: CONTROL_KEY,
      value: JSON.stringify(record),
      updatedAt: record.updatedAt
    })
  }

  private statusFor(state: ContinuationControlState, errorCode: string): ContinuationStatus {
    if (state === ContinuationControlState.GUEST) {
      return { state, message: '登录应用账号后可使用跨设备接续', canRetry: false, isController: true }
    }
    if (state === ContinuationControlState.READY) {
      return { state, message: '已准备接续，可从同账号设备继续本次计时', canRetry: false, isController: true }
    }
    if (state === ContinuationControlState.TRANSFER_PENDING) {
      return { state, message: '正在等待目标设备确认，当前设备继续计时', canRetry: false, isController: true }
    }
    if (state === ContinuationControlState.TRANSFERRED) {
      return { state, message: '计时已转移到另一设备，本机提醒已停止', canRetry: false, isController: false }
    }
    if (state === ContinuationControlState.TARGET_CONTROL) {
      return { state, message: '已在本机接续，本机拥有唯一控制权', canRetry: false, isController: true }
    }
    if (state === ContinuationControlState.OFFLINE) {
      return { state, message: '网络不可用，接续暂不可用；本机继续计时', canRetry: true, isController: true }
    }
    if (state === ContinuationControlState.FAILED) {
      return this.failedStatus(this.errorMessage(errorCode), false)
    }
    return { state, message: '开始计时后可使用跨设备接续', canRetry: false, isController: true }
  }

  private failedStatus(message: string, retry: boolean): ContinuationStatus {
    return {
      state: ContinuationControlState.FAILED,
      message: message,
      canRetry: retry,
      isController: true
    }
  }

  private errorMessage(code: string): string {
    if (code === 'CONTINUATION_ACCOUNT_MISMATCH') {
      return '应用账号不同，原设备将继续计时'
    }
    if (code === 'CONTINUATION_VERSION_MISMATCH') {
      return '应用版本不兼容，原设备将继续计时'
    }
    if (code === 'CONTINUATION_ALREADY_CLAIMED') {
      return '本次计时已由另一设备接管'
    }
    if (code === 'CONTINUATION_EXPIRED' || code === 'CONTINUATION_INVALID') {
      return '接续请求已过期，原设备将继续计时'
    }
    return '接续暂时失败，原设备将继续计时'
  }
}
