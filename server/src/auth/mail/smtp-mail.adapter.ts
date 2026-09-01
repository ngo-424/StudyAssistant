import { Injectable } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import { Transporter } from 'nodemailer';
import { MailAdapter } from './mail-adapter';

@Injectable()
export class SmtpMailAdapter implements MailAdapter {
  private readonly transporter: Transporter;

  constructor() {
    const port = Number(process.env.SMTP_PORT ?? 1025);
    this.transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST ?? '127.0.0.1',
      port,
      secure: (process.env.SMTP_SECURE ?? 'false') === 'true',
      requireTLS: (process.env.SMTP_REQUIRE_TLS ?? 'false') === 'true',
      auth: process.env.SMTP_USER ? {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASSWORD ?? '',
      } : undefined,
    });
  }

  async sendVerificationCode(email: string, code: string, expiresInMinutes: number): Promise<void> {
    await this.transporter.sendMail({
      from: process.env.MAIL_FROM ?? '时芽 <no-reply@studyassistant.local>',
      to: email,
      subject: '时芽登录验证码',
      text: `你的时芽验证码是 ${code}，${expiresInMinutes} 分钟内有效。请勿转发给他人。`,
      html: `<p>你的时芽验证码是 <strong>${code}</strong>，${expiresInMinutes} 分钟内有效。</p><p>请勿转发给他人。</p>`,
    });
  }
}
