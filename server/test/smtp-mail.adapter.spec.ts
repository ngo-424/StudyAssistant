import { SmtpMailAdapter } from '../src/auth/mail/smtp-mail.adapter';

describe('SmtpMailAdapter', () => {
  it('creates a CommonJS-compatible Nodemailer transport', () => {
    expect(() => new SmtpMailAdapter()).not.toThrow();
  });
});
