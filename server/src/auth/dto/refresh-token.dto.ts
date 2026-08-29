import { IsString, Length } from 'class-validator';

export class RefreshTokenDto {
  @IsString()
  @Length(32, 256)
  refreshToken!: string;

  @IsString()
  @Length(8, 128)
  deviceId!: string;
}
