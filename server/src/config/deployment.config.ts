const LOOPBACK_HOSTS = new Set(['127.0.0.1', 'localhost', '::1']);

export function productionConfigurationErrors(environment: NodeJS.ProcessEnv): string[] {
  if (environment.NODE_ENV !== 'production') {
    return [];
  }
  const errors: string[] = [];
  const required = [
    'DATABASE_URL', 'REDIS_URL', 'JWT_SECRET', 'CODE_PEPPER', 'TOKEN_PEPPER',
    'SMTP_HOST', 'SMTP_PORT', 'MAIL_FROM',
  ];
  for (const name of required) {
    if (!environment[name]?.trim()) {
      errors.push(`${name} is required`);
    }
  }
  validateUrl(environment.DATABASE_URL, ['postgres:', 'postgresql:'], 'DATABASE_URL', errors);
  validateUrl(environment.REDIS_URL, ['rediss:'], 'REDIS_URL', errors);
  if (environment.DATABASE_SSL !== 'true') {
    errors.push('DATABASE_SSL must be true');
  }
  const smtpHost = environment.SMTP_HOST?.trim().toLowerCase();
  if (smtpHost && LOOPBACK_HOSTS.has(smtpHost)) {
    errors.push('SMTP_HOST must not be a loopback host');
  }
  if (environment.SMTP_SECURE !== 'true' && environment.SMTP_REQUIRE_TLS !== 'true') {
    errors.push('SMTP_SECURE or SMTP_REQUIRE_TLS must be true');
  }
  const mailFrom = environment.MAIL_FROM?.toLowerCase() ?? '';
  if (mailFrom.includes('.local') || mailFrom.includes('.example')) {
    errors.push('MAIL_FROM must use the production sender domain');
  }
  return errors;
}

export function assertProductionConfiguration(environment: NodeJS.ProcessEnv): void {
  const errors = productionConfigurationErrors(environment);
  if (errors.length > 0) {
    throw new Error(`Invalid production configuration: ${errors.join('; ')}`);
  }
}

function validateUrl(value: string | undefined, allowedProtocols: string[],
  name: string, errors: string[]): void {
  if (!value?.trim()) {
    return;
  }
  try {
    const parsed = new URL(value);
    if (!allowedProtocols.includes(parsed.protocol)) {
      errors.push(`${name} must use ${allowedProtocols.join(' or ')}`);
    }
    if (LOOPBACK_HOSTS.has(parsed.hostname.toLowerCase())) {
      errors.push(`${name} must not use a loopback host`);
    }
  } catch {
    errors.push(`${name} must be a valid URL`);
  }
}
