import { relationalStore } from '@kit.ArkData'
import { AppError, AppErrorCode } from '../../core/error/AppError'

export class ResultSetReader {
  static string(resultSet: relationalStore.ResultSet, column: string): string {
    try {
      return resultSet.getString(resultSet.getColumnIndex(column))
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to read text column ${column}`)
    }
  }

  static nullableString(resultSet: relationalStore.ResultSet, column: string): string | null {
    try {
      const index: number = resultSet.getColumnIndex(column)
      return resultSet.isColumnNull(index) ? null : resultSet.getString(index)
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to read optional text column ${column}`)
    }
  }

  static number(resultSet: relationalStore.ResultSet, column: string): number {
    try {
      return resultSet.getLong(resultSet.getColumnIndex(column))
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to read number column ${column}`)
    }
  }

  static nullableNumber(resultSet: relationalStore.ResultSet, column: string): number | null {
    try {
      const index: number = resultSet.getColumnIndex(column)
      return resultSet.isColumnNull(index) ? null : resultSet.getLong(index)
    } catch (error) {
      throw new AppError(AppErrorCode.DATABASE, `Unable to read optional number column ${column}`)
    }
  }
}
