export interface TaskDraft {
  title: string
  notes: string
  categoryId: string | null
  plannedMinutes: number
  dueAt: number | null
}

export interface CategoryDraft {
  name: string
  colorSeed: string
}
