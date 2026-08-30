import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsInt,
  IsObject,
  IsString,
  IsUUID,
  Length,
  Min,
  ValidateNested,
} from 'class-validator';
import { SyncEntityType, SyncOperation } from '../sync.contracts';

export class PushMutationDto {
  @IsUUID()
  mutationId!: string;

  @IsEnum(SyncEntityType)
  entityType!: SyncEntityType;

  @IsString()
  @Length(1, 160)
  entityId!: string;

  @IsInt()
  @Min(0)
  baseRevision!: number;

  @IsEnum(SyncOperation)
  operation!: SyncOperation;

  @IsObject()
  payload!: Record<string, unknown>;

  @IsInt()
  @Min(0)
  updatedAt!: number;
}

export class PushSyncDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => PushMutationDto)
  mutations!: PushMutationDto[];
}
