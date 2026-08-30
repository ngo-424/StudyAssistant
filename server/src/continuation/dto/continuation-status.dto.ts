import { IsString, Length } from 'class-validator';

export class ContinuationStatusDto {
  @IsString()
  @Length(32, 128)
  token!: string;
}
