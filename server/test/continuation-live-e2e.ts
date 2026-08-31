import { randomUUID } from 'node:crypto';

const API_URL = process.env.E2E_API_URL ?? 'http://127.0.0.1:3000/v1';
const MAILPIT_URL = process.env.E2E_MAILPIT_URL ?? 'http://127.0.0.1:8025';

interface SessionResponse {
  tokens: { accessToken: string };
}

interface MailpitMessage {
  Created: string;
  Snippet: string;
  To: Array<{ Address: string }>;
}

interface ApiFailure {
  code?: string;
}

async function api<T>(path: string, method: string, body?: object,
  token?: string, expectedStatus: number = 200): Promise<T> {
  const response = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const createdIsAccepted = expectedStatus === 200 && method === 'POST' && response.status === 201;
  const text = await response.text();
  if (response.status !== expectedStatus && !createdIsAccepted) {
    throw new Error(`${method} ${path} returned ${response.status}; expected ${expectedStatus}; ${text}`);
  }
  return (text ? JSON.parse(text) : {}) as T;
}

async function expectFailure(path: string, body: object, token: string,
  expectedStatus: number, expectedCode: string): Promise<void> {
  const response = await fetch(`${API_URL}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
  const payload = await response.json() as ApiFailure;
  assert(response.status === expectedStatus && payload.code === expectedCode,
    `${path} returned ${response.status}/${payload.code}; expected ${expectedStatus}/${expectedCode}`);
}

async function latestCode(email: string): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const response = await fetch(`${MAILPIT_URL}/api/v1/messages`);
    const mailbox = await response.json() as { messages: MailpitMessage[] };
    const message = mailbox.messages
      .filter((item) => item.To.some((recipient) => recipient.Address === email))
      .sort((left, right) => right.Created.localeCompare(left.Created))[0];
    const code = message?.Snippet.match(/(?<!\d)\d{6}(?!\d)/)?.[0];
    if (code) return code;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error('Verification email did not arrive');
}

async function accessToken(label: string): Promise<string> {
  const suffix = randomUUID().replaceAll('-', '').slice(0, 12);
  const email = `module11-${label}-${suffix}@example.test`;
  const deviceId = `${label}-${suffix}`;
  await api('/auth/code/request', 'POST', { email, deviceId }, undefined, 202);
  const code = await latestCode(email);
  const session = await api<SessionResponse>('/auth/code/verify', 'POST', { email, code, deviceId });
  return session.tokens.accessToken;
}

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

async function run(): Promise<void> {
  const ownerToken = await accessToken('owner');
  const otherToken = await accessToken('other');
  const transferToken = `${randomUUID()}${randomUUID()}`;
  const flowId = randomUUID();
  const phaseSessionId = randomUUID();
  const prepare = {
    token: transferToken,
    flowId,
    phaseSessionId,
    sourceDeviceId: 'source-device',
    sourceVersion: 1,
  };
  const prepared = await api<{ expiresAt: string }>(
    '/continuation/prepare', 'POST', prepare, ownerToken);
  assert(Date.parse(prepared.expiresAt) > Date.now(), 'Prepared transfer has no future expiry');

  const claim = {
    token: transferToken,
    flowId,
    phaseSessionId,
    targetDeviceId: 'target-device',
    targetVersion: 1,
  };
  await expectFailure('/continuation/claim', claim, otherToken, 403,
    'CONTINUATION_ACCOUNT_MISMATCH');
  const accepted = await api<{ accepted: boolean; alreadyClaimed: boolean }>(
    '/continuation/claim', 'POST', claim, ownerToken);
  assert(accepted.accepted && !accepted.alreadyClaimed, 'First target did not acquire ownership');
  const replay = await api<{ accepted: boolean; alreadyClaimed: boolean }>(
    '/continuation/claim', 'POST', claim, ownerToken);
  assert(replay.accepted && replay.alreadyClaimed, 'Target retry was not idempotent');
  await expectFailure('/continuation/claim', { ...claim, targetDeviceId: 'second-target' },
    ownerToken, 409, 'CONTINUATION_ALREADY_CLAIMED');

  const status = await api<{ status: string }>(
    `/continuation/status?token=${encodeURIComponent(transferToken)}`, 'GET', undefined, ownerToken);
  assert(status.status === 'claimed', 'Source did not observe transferred ownership');

  const versionToken = `${randomUUID()}${randomUUID()}`;
  const versionFlowId = randomUUID();
  const versionSessionId = randomUUID();
  await api('/continuation/prepare', 'POST', {
    ...prepare, token: versionToken, flowId: versionFlowId, phaseSessionId: versionSessionId,
  }, ownerToken);
  await expectFailure('/continuation/claim', {
    token: versionToken,
    flowId: versionFlowId,
    phaseSessionId: versionSessionId,
    targetDeviceId: 'version-target',
    targetVersion: 2,
  }, ownerToken, 409, 'CONTINUATION_VERSION_MISMATCH');

  console.log('Live continuation E2E passed: account binding, atomic claim, replay, duplicate target, version, and status.');
}

void run().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : 'Unknown continuation E2E failure');
  process.exitCode = 1;
});
