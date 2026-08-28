export class WindowLayoutPolicy {
  static isCompact(width: number, height: number): boolean {
    return width < 520 && height < 640
  }
}
