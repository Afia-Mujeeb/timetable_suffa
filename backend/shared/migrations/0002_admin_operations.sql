PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS import_runs (
  id TEXT PRIMARY KEY,
  version_id TEXT REFERENCES timetable_versions(id) ON DELETE SET NULL,
  source_file_name TEXT,
  source_id TEXT,
  parser_version TEXT,
  triggered_by TEXT,
  status TEXT NOT NULL CHECK (status IN ('running', 'succeeded', 'failed')),
  warning_count INTEGER NOT NULL DEFAULT 0,
  warnings_json TEXT NOT NULL DEFAULT '[]',
  error_message TEXT,
  started_at TEXT NOT NULL,
  completed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_import_runs_started_at
  ON import_runs (started_at DESC);

CREATE INDEX IF NOT EXISTS idx_import_runs_version_id
  ON import_runs (version_id, started_at DESC);

CREATE TABLE IF NOT EXISTS audit_events (
  id TEXT PRIMARY KEY,
  event_kind TEXT NOT NULL CHECK (
    event_kind IN ('import_succeeded', 'import_failed', 'published', 'rolled_back')
  ),
  version_id TEXT REFERENCES timetable_versions(id) ON DELETE SET NULL,
  previous_version_id TEXT REFERENCES timetable_versions(id) ON DELETE SET NULL,
  triggered_by TEXT,
  note TEXT,
  warnings_ignored INTEGER NOT NULL DEFAULT 0 CHECK (warnings_ignored IN (0, 1)),
  change_summary_json TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_events_created_at
  ON audit_events (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_events_version_id
  ON audit_events (version_id, created_at DESC);

INSERT INTO import_runs (
  id,
  version_id,
  source_file_name,
  source_id,
  parser_version,
  triggered_by,
  status,
  warning_count,
  warnings_json,
  error_message,
  started_at,
  completed_at
)
SELECT
  'backfill-import-' || timetable_versions.id,
  timetable_versions.id,
  timetable_versions.source_file_name,
  NULL,
  NULL,
  'system-backfill',
  'succeeded',
  0,
  timetable_versions.import_warnings_json,
  NULL,
  timetable_versions.created_at,
  timetable_versions.created_at
FROM timetable_versions
WHERE NOT EXISTS (
  SELECT 1
  FROM import_runs
  WHERE import_runs.version_id = timetable_versions.id
);

INSERT INTO audit_events (
  id,
  event_kind,
  version_id,
  previous_version_id,
  triggered_by,
  note,
  warnings_ignored,
  change_summary_json,
  created_at
)
SELECT
  'backfill-publish-' || timetable_versions.id,
  'published',
  timetable_versions.id,
  NULL,
  'system-backfill',
  'Backfilled from pre-Sprint-6 published version state.',
  0,
  NULL,
  COALESCE(timetable_versions.published_at, timetable_versions.created_at)
FROM timetable_versions
WHERE timetable_versions.published_at IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM audit_events
    WHERE audit_events.version_id = timetable_versions.id
      AND audit_events.event_kind = 'published'
  );
