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

interface PushResult {
  results: Array<{
    mutationId: string;
    status: string;
    revision: number;
    serverRecord?: { revision: number; payload: Record<string, unknown> };
  }>;
}

interface PullResult {
  changes: Array<{ cursor: string; entityId: string; revision: number }>;
  nextCursor: string;
  hasMore: boolean;
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
  const createdIsAccepted: boolean = expectedStatus === 200 && method === 'POST' && response.status === 201;
  if (response.status !== expectedStatus && !createdIsAccepted) {
    throw new Error(`${method} ${path} returned ${response.status}; expected ${expectedStatus}`);
  }
  const text = await response.text();
  return (text ? JSON.parse(text) : {}) as T;
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

async function accessToken(): Promise<string> {
  const suffix = randomUUID().replaceAll('-', '').slice(0, 12);
  const email = `module10-${suffix}@example.test`;
  const deviceId = `sync-e2e-${suffix}`;
  await api('/auth/code/request', 'POST', { email, deviceId }, undefined, 202);
  const code = await latestCode(email);
  const session = await api<SessionResponse>('/auth/code/verify', 'POST', { email, code, deviceId });
  return session.tokens.accessToken;
}

function mutation(mutationId: string, entityType: string, entityId: string,
  baseRevision: number, payload: Record<string, unknown>) {
  return { mutationId, entityType, entityId, baseRevision, operation: 'upsert', payload, updatedAt: Date.now() };
}

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

async function run(): Promise<void> {
  const token = await accessToken();
  const taskId = randomUUID();
  const firstId = randomUUID();
  const firstBody = { mutations: [mutation(firstId, 'task', taskId, 0, { title: 'device-a' })] };
  const first = await api<PushResult>('/sync/push', 'POST', firstBody, token);
  const replay = await api<PushResult>('/sync/push', 'POST', firstBody, token);
  assert(first.results[0].status === 'applied' && first.results[0].revision === 1,
    'First task mutation was not applied');
  assert(replay.results[0].mutationId === first.results[0].mutationId &&
    replay.results[0].status === first.results[0].status &&
    replay.results[0].revision === first.results[0].revision,
  'Mutation replay was not idempotent');

  const initialPull = await api<PullResult>('/sync/pull?cursor=0', 'GET', undefined, token);
  assert(initialPull.changes.some((change) => change.entityId === taskId), 'Initial pull missed task change');
  const emptyPull = await api<PullResult>(`/sync/pull?cursor=${initialPull.nextCursor}`, 'GET', undefined, token);
  assert(emptyPull.changes.length === 0, 'Incremental cursor replayed old changes');

  const second = await api<PushResult>('/sync/push', 'POST', {
    mutations: [mutation(randomUUID(), 'task', taskId, 1, { title: 'device-b' })],
  }, token);
  assert(second.results[0].revision === 2, 'Second device update did not advance revision');
  const stale = await api<PushResult>('/sync/push', 'POST', {
    mutations: [mutation(randomUUID(), 'task', taskId, 1, { title: 'stale-device-a' })],
  }, token);
  assert(stale.results[0].status === 'conflict' && stale.results[0].serverRecord?.revision === 2,
    'Stale multi-device update did not preserve a conflict snapshot');

  const sessionId = randomUUID();
  const focusPayload = { focusedSeconds: 1500, result: 'completed' };
  const appended = await api<PushResult>('/sync/push', 'POST', {
    mutations: [mutation(randomUUID(), 'focus_session', sessionId, 0, focusPayload)],
  }, token);
  const duplicate = await api<PushResult>('/sync/push', 'POST', {
    mutations: [mutation(randomUUID(), 'focus_session', sessionId, 0, focusPayload)],
  }, token);
  assert(appended.results[0].revision === 1 && duplicate.results[0].revision === 1,
    'Append-only session was duplicated');
  const changedAppend = await api<PushResult>('/sync/push', 'POST', {
    mutations: [mutation(randomUUID(), 'focus_session', sessionId, 0,
      { focusedSeconds: 1200, result: 'completed' })],
  }, token);
  assert(changedAppend.results[0].status === 'conflict', 'Changed append-only session was overwritten');

  await api('/sync/push', 'POST', firstBody, undefined, 401);
  console.log('Live sync E2E passed: idempotency, cursor pull, conflicts, append-only records, and auth.');
}

void run().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : 'Unknown sync E2E failure');
  process.exitCode = 1;
});
