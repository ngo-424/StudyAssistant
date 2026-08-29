import { IsString, Length } from 'class-validator';

export class LogoutDto {
  @IsString()
  @Length(32, 256)
  refreshToken!: string;
}
