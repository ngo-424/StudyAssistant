import { IsInt, IsString, IsUUID, Length, Max, Min } from 'class-validator';

export class PrepareContinuationDto {
  @IsString()
  @Length(32, 128)
  token!: string;

  @IsUUID()
  flowId!: string;

  @IsUUID()
  phaseSessionId!: string;

  @IsString()
  @Length(1, 160)
  sourceDeviceId!: string;

  @IsInt()
  @Min(1)
  @Max(1000)
  sourceVersion!: number;
}
