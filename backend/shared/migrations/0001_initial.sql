PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS timetable_versions (
  id TEXT PRIMARY KEY,
  source_file_name TEXT NOT NULL,
  generated_date TEXT NOT NULL,
  source_checksum TEXT NOT NULL UNIQUE,
  publish_status TEXT NOT NULL DEFAULT 'draft' CHECK (publish_status IN ('draft', 'published', 'archived')),
  import_warnings_json TEXT NOT NULL DEFAULT '[]',
  section_count INTEGER NOT NULL DEFAULT 0,
  meeting_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  published_at TEXT
);

CREATE TABLE IF NOT EXISTS sections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  normalized_code TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0, 1)),
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS courses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  course_type TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS instructors (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS rooms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  label TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  is_online INTEGER NOT NULL DEFAULT 0 CHECK (is_online IN (0, 1)),
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS class_meetings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  version_id TEXT NOT NULL REFERENCES timetable_versions(id) ON DELETE CASCADE,
  section_id INTEGER NOT NULL REFERENCES sections(id),
  course_id INTEGER NOT NULL REFERENCES courses(id),
  instructor_id INTEGER REFERENCES instructors(id),
  room_id INTEGER REFERENCES rooms(id),
  day_key TEXT NOT NULL CHECK (day_key IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday')),
  day_label TEXT NOT NULL,
  day_sort INTEGER NOT NULL CHECK (day_sort BETWEEN 1 AND 6),
  slot_start INTEGER NOT NULL,
  slot_end INTEGER NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  meeting_type TEXT NOT NULL CHECK (meeting_type IN ('lecture', 'lab')),
  online INTEGER NOT NULL CHECK (online IN (0, 1)),
  source_page INTEGER NOT NULL,
  confidence_class TEXT NOT NULL CHECK (confidence_class IN ('high', 'medium', 'low')),
  confidence_score REAL NOT NULL,
  warnings_json TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL,
  UNIQUE (
    version_id,
    section_id,
    day_key,
    slot_start,
    slot_end,
    course_id,
    instructor_id,
    room_id
  )
);

CREATE INDEX IF NOT EXISTS idx_timetable_versions_publish_status
  ON timetable_versions (publish_status, published_at DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sections_active_code
  ON sections (active, code);

CREATE INDEX IF NOT EXISTS idx_class_meetings_version_section_day
  ON class_meetings (version_id, section_id, day_sort, slot_start, start_time);
