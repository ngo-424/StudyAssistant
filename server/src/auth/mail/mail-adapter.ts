export const MAIL_ADAPTER = Symbol('MAIL_ADAPTER');

export interface MailAdapter {
  sendVerificationCode(email: string, code: string, expiresInMinutes: number): Promise<void>;
}
