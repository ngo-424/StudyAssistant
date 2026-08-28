export interface CategoryPalette {
  accent: string
  onAccent: string
  container: string
  onContainer: string
}

export class CategoryColor {
  static readonly NEUTRAL: string = '#778291'
  static readonly PRESETS: string[] = [
    '#536F9E', '#4D8068', '#3E7C84', '#78659A',
    '#9A654F', '#96752F', '#8A5F78', '#5E718C'
  ]

  static normalize(value: string): string | null {
    const candidate: string = value.trim().toUpperCase()
    if (!/^#[0-9A-F]{6}$/.test(candidate)) {
      return null
    }
    return candidate
  }

  static palette(value: string): CategoryPalette {
    const accent: string = CategoryColor.normalize(value) ?? CategoryColor.NEUTRAL
    const container: string = CategoryColor.mix(accent, '#FFFFFF', 0.82)
    return {
      accent: accent,
      onAccent: CategoryColor.foregroundFor(accent),
      container: container,
      onContainer: CategoryColor.foregroundFor(container)
    }
  }

  static foregroundFor(background: string): string {
    const normalized: string = CategoryColor.normalize(background) ?? CategoryColor.NEUTRAL
    const whiteContrast: number = CategoryColor.contrastRatio(normalized, '#FFFFFF')
    const darkContrast: number = CategoryColor.contrastRatio(normalized, '#000000')
    return whiteContrast >= darkContrast ? '#FFFFFF' : '#000000'
  }

  static contrastRatio(first: string, second: string): number {
    const firstLuminance: number = CategoryColor.luminance(CategoryColor.normalize(first) ?? CategoryColor.NEUTRAL)
    const secondLuminance: number = CategoryColor.luminance(CategoryColor.normalize(second) ?? CategoryColor.NEUTRAL)
    const lighter: number = Math.max(firstLuminance, secondLuminance)
    const darker: number = Math.min(firstLuminance, secondLuminance)
    return (lighter + 0.05) / (darker + 0.05)
  }

  private static mix(first: string, second: string, secondWeight: number): string {
    const firstChannels: number[] = CategoryColor.channels(first)
    const secondChannels: number[] = CategoryColor.channels(second)
    const red: number = Math.round(firstChannels[0] * (1 - secondWeight) + secondChannels[0] * secondWeight)
    const green: number = Math.round(firstChannels[1] * (1 - secondWeight) + secondChannels[1] * secondWeight)
    const blue: number = Math.round(firstChannels[2] * (1 - secondWeight) + secondChannels[2] * secondWeight)
    return `#${CategoryColor.hex(red)}${CategoryColor.hex(green)}${CategoryColor.hex(blue)}`
  }

  private static luminance(color: string): number {
    const values: number[] = CategoryColor.channels(color)
    const red: number = CategoryColor.linear(values[0] / 255)
    const green: number = CategoryColor.linear(values[1] / 255)
    const blue: number = CategoryColor.linear(values[2] / 255)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue
  }

  private static linear(value: number): number {
    return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
  }

  private static channels(color: string): number[] {
    return [
      parseInt(color.substring(1, 3), 16),
      parseInt(color.substring(3, 5), 16),
      parseInt(color.substring(5, 7), 16)
    ]
  }

  private static hex(value: number): string {
    const result: string = value.toString(16).toUpperCase()
    return result.length === 1 ? `0${result}` : result
  }
}
