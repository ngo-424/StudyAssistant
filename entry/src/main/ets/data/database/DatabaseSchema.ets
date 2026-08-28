export const DATABASE_NAME: string = 'study_assistant.db'
export const DATABASE_VERSION: number = 1
export const GUEST_PROFILE_ID: string = 'guest'

export class DatabaseTable {
  static readonly CATEGORIES: string = 'task_categories'
  static readonly TASKS: string = 'study_tasks'
  static readonly FOCUS_SESSIONS: string = 'focus_sessions'
  static readonly REWARD_EVENTS: string = 'reward_events'
  static readonly ACHIEVEMENTS: string = 'achievements'
  static readonly SETTINGS: string = 'app_settings'
  static readonly SYNC_METADATA: string = 'sync_metadata'
  static readonly MIGRATION_HISTORY: string = 'migration_history'
}

export const DATABASE_V1_STATEMENTS: string[] = [
  `CREATE TABLE IF NOT EXISTS task_categories (
    id TEXT PRIMARY KEY NOT NULL,
    profile_id TEXT NOT NULL,
    name TEXT NOT NULL,
    color_seed TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 0,
    sync_state TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS study_tasks (
    id TEXT PRIMARY KEY NOT NULL,
    profile_id TEXT NOT NULL,
    title TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT '',
    category_id TEXT,
    planned_minutes INTEGER NOT NULL,
    due_at INTEGER,
    status TEXT NOT NULL,
    completed_at INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 0,
    sync_state TEXT NOT NULL,
    legacy_code TEXT,
    FOREIGN KEY(category_id) REFERENCES task_categories(id) ON DELETE SET NULL
  )`,
  `CREATE TABLE IF NOT EXISTS focus_sessions (
    id TEXT PRIMARY KEY NOT NULL,
    profile_id TEXT NOT NULL,
    task_id TEXT,
    category_id TEXT,
    device_id TEXT NOT NULL,
    phase TEXT NOT NULL,
    planned_seconds INTEGER NOT NULL,
    focused_seconds INTEGER NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    result TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    revision INTEGER NOT NULL DEFAULT 0,
    sync_state TEXT NOT NULL,
    FOREIGN KEY(task_id) REFERENCES study_tasks(id) ON DELETE SET NULL,
    FOREIGN KEY(category_id) REFERENCES task_categories(id) ON DELETE SET NULL
  )`,
  `CREATE TABLE IF NOT EXISTS reward_events (
    id TEXT PRIMARY KEY NOT NULL,
    profile_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    rule_version INTEGER NOT NULL,
    base_points INTEGER NOT NULL,
    multiplier REAL NOT NULL,
    awarded_points INTEGER NOT NULL,
    awarded_at INTEGER NOT NULL,
    sync_state TEXT NOT NULL,
    UNIQUE(session_id, rule_version)
  )`,
  `CREATE TABLE IF NOT EXISTS achievements (
    id TEXT PRIMARY KEY NOT NULL,
    profile_id TEXT NOT NULL,
    achievement_key TEXT NOT NULL,
    current_value INTEGER NOT NULL,
    target_value INTEGER NOT NULL,
    unlocked_at INTEGER,
    updated_at INTEGER NOT NULL,
    sync_state TEXT NOT NULL,
    UNIQUE(profile_id, achievement_key)
  )`,
  `CREATE TABLE IF NOT EXISTS app_settings (
    profile_id TEXT NOT NULL,
    setting_key TEXT NOT NULL,
    setting_value TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(profile_id, setting_key)
  )`,
  `CREATE TABLE IF NOT EXISTS sync_metadata (
    profile_id TEXT NOT NULL,
    metadata_key TEXT NOT NULL,
    metadata_value TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(profile_id, metadata_key)
  )`,
  `CREATE TABLE IF NOT EXISTS migration_history (
    migration_key TEXT PRIMARY KEY NOT NULL,
    completed_at INTEGER NOT NULL,
    details TEXT NOT NULL
  )`,
  'CREATE INDEX IF NOT EXISTS idx_categories_profile ON task_categories(profile_id, deleted_at)',
  'CREATE INDEX IF NOT EXISTS idx_tasks_profile_status ON study_tasks(profile_id, status, deleted_at)',
  'CREATE INDEX IF NOT EXISTS idx_tasks_due_at ON study_tasks(profile_id, due_at)',
  `CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_legacy_code
    ON study_tasks(profile_id, legacy_code) WHERE legacy_code IS NOT NULL`,
  'CREATE INDEX IF NOT EXISTS idx_sessions_profile_started ON focus_sessions(profile_id, started_at)',
  'CREATE INDEX IF NOT EXISTS idx_rewards_profile_awarded ON reward_events(profile_id, awarded_at)'
]
