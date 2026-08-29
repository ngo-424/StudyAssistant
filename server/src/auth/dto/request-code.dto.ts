import { IsEmail, IsString, Length, MaxLength } from 'class-validator';

export class RequestCodeDto {
  @IsEmail()
  @MaxLength(320)
  email!: string;

  @IsString()
  @Length(8, 128)
  deviceId!: string;
}
