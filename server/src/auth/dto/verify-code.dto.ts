import { IsEmail, IsString, Length, Matches, MaxLength } from 'class-validator';

export class VerifyCodeDto {
  @IsEmail()
  @MaxLength(320)
  email!: string;

  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;

  @IsString()
  @Length(8, 128)
  deviceId!: string;
}
