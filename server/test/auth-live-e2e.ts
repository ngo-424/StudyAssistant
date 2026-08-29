import { randomUUID } from 'node:crypto';

const API_URL = process.env.E2E_API_URL ?? 'http://127.0.0.1:3000/v1';
const MAILPIT_URL = process.env.E2E_MAILPIT_URL ?? 'http://127.0.0.1:8025';

interface SessionResponse {
  account: { id: string; email: string };
  tokens: { accessToken: string; refreshToken: string };
}

interface MailpitMessage {
  Created: string;
  Snippet: string;
  To: Array<{ Address: string }>;
}

interface MailpitResponse {
  messages: MailpitMessage[];
}

async function api<T>(path: string, method: string, body?: object,
  accessToken?: string, expectedStatus: number = 200): Promise<T> {
  const response = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(accessToken ? { authorization: `Bearer ${accessToken}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (response.status !== expectedStatus) {
    throw new Error(`${method} ${path} returned ${response.status}; expected ${expectedStatus}`);
  }
  const text = await response.text();
  return (text ? JSON.parse(text) : {}) as T;
}

async function expectUnauthorized(path: string, body: object): Promise<void> {
  await api(path, 'POST', body, undefined, 401);
}

async function latestCode(email: string): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const response = await fetch(`${MAILPIT_URL}/api/v1/messages`);
    if (!response.ok) {
      throw new Error(`Mailpit returned ${response.status}`);
    }
    const mailbox = await response.json() as MailpitResponse;
    const message = mailbox.messages
      .filter((item) => item.To.some((recipient) => recipient.Address === email))
      .sort((left, right) => right.Created.localeCompare(left.Created))[0];
    const code = message?.Snippet.match(/(?<!\d)\d{6}(?!\d)/)?.[0];
    if (code) {
      return code;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error('Verification email did not arrive in Mailpit');
}

async function createSession(scenario: string): Promise<{ session: SessionResponse; deviceId: string }> {
  const suffix = randomUUID().replaceAll('-', '').slice(0, 12);
  const email = `module09-${scenario}-${suffix}@example.test`;
  const deviceId = `e2e-${scenario}-${suffix}`;
  await api('/auth/code/request', 'POST', { email, deviceId }, undefined, 202);
  const code = await latestCode(email);
  const session = await api<SessionResponse>('/auth/code/verify', 'POST', { email, code, deviceId });
  if (session.account.email !== email) {
    throw new Error('Verified account does not match the requested email');
  }
  return { session, deviceId };
}

async function run(): Promise<void> {
  const rotation = await createSession('rotation');
  const rotated = await api<SessionResponse>('/auth/refresh', 'POST', {
    refreshToken: rotation.session.tokens.refreshToken,
    deviceId: rotation.deviceId,
  });
  if (rotated.tokens.refreshToken === rotation.session.tokens.refreshToken) {
    throw new Error('Refresh token was not rotated');
  }
  await expectUnauthorized('/auth/refresh', {
    refreshToken: rotation.session.tokens.refreshToken,
    deviceId: rotation.deviceId,
  });
  await expectUnauthorized('/auth/refresh', {
    refreshToken: rotated.tokens.refreshToken,
    deviceId: rotation.deviceId,
  });

  const logout = await createSession('logout');
  await api('/auth/logout', 'POST', { refreshToken: logout.session.tokens.refreshToken });
  await expectUnauthorized('/auth/refresh', {
    refreshToken: logout.session.tokens.refreshToken,
    deviceId: logout.deviceId,
  });

  const deletion = await createSession('deletion');
  await api('/account', 'DELETE', undefined, deletion.session.tokens.accessToken);
  await expectUnauthorized('/auth/refresh', {
    refreshToken: deletion.session.tokens.refreshToken,
    deviceId: deletion.deviceId,
  });

  console.log('Live auth E2E passed: email, login, rotation, replay, logout, and deletion.');
}

void run().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : 'Unknown E2E failure';
  console.error(message);
  process.exitCode = 1;
});
