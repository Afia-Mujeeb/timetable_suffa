import type { DatabaseClient, DatabaseRow } from "./db";
import type {
  MeetingRecord,
  PublishStatus,
  SectionRecord,
  TimetableVersionRecord,
  VersionMeetingSnapshot,
} from "./types";

type VersionRow = DatabaseRow & {
  id: string;
  source_file_name: string;
  generated_date: string;
  source_checksum: string;
  publish_status: PublishStatus;
  import_warnings_json: string;
  section_count: number;
  meeting_count: number;
  created_at: string;
  published_at: string | null;
};

type SectionRow = DatabaseRow & {
  id: number;
  code: string;
  normalized_code: string;
  display_name: string;
  active: number;
};

type MeetingRow = DatabaseRow & {
  id: number;
  version_id: string;
  section_code: string;
  section_display_name: string;
  course_name: string;
  instructor_name: string | null;
  room_label: string | null;
  day_label: string;
  day_key: MeetingRecord["dayKey"];
  slot_start: number;
  slot_end: number;
  start_time: string;
  end_time: string;
  meeting_type: MeetingRecord["meetingType"];
  online: number;
  source_page: number;
  confidence_class: MeetingRecord["confidenceClass"];
  confidence_score: number;
  warnings_json: string;
};

type VersionMeetingSnapshotRow = DatabaseRow & {
  section_code: string;
  section_display_name: string;
  course_name: string;
  instructor_name: string | null;
  room_label: string | null;
  day_label: string;
  day_key: MeetingRecord["dayKey"];
  slot_start: number;
  slot_end: number;
  start_time: string;
  end_time: string;
  meeting_type: MeetingRecord["meetingType"];
  online: number;
  source_page: number;
  confidence_class: MeetingRecord["confidenceClass"];
  warnings_json: string;
};

function parseJsonArray(value: string): string[] {
  const parsed = JSON.parse(value) as unknown;
  return Array.isArray(parsed)
    ? parsed.filter((item): item is string => typeof item === "string")
    : [];
}

function mapVersion(row: VersionRow): TimetableVersionRecord {
  return {
    id: row.id,
    sourceFileName: row.source_file_name,
    generatedDate: row.generated_date,
    sourceChecksum: row.source_checksum,
    publishStatus: row.publish_status,
    importWarnings: parseJsonArray(row.import_warnings_json),
    sectionCount: row.section_count,
    meetingCount: row.meeting_count,
    createdAt: row.created_at,
    publishedAt: row.published_at,
  };
}

function mapSection(row: SectionRow): SectionRecord {
  return {
    id: row.id,
    code: row.code,
    normalizedCode: row.normalized_code,
    displayName: row.display_name,
    active: row.active === 1,
  };
}

function mapMeeting(row: MeetingRow): MeetingRecord {
  return {
    id: row.id,
    versionId: row.version_id,
    sectionCode: row.section_code,
    sectionDisplayName: row.section_display_name,
    courseName: row.course_name,
    instructorName: row.instructor_name,
    roomLabel: row.room_label,
    dayLabel: row.day_label,
    dayKey: row.day_key,
    slotStart: row.slot_start,
    slotEnd: row.slot_end,
    startTime: row.start_time,
    endTime: row.end_time,
    meetingType: row.meeting_type,
    online: row.online === 1,
    sourcePage: row.source_page,
    confidenceClass: row.confidence_class,
    confidenceScore: row.confidence_score,
    warnings: parseJsonArray(row.warnings_json),
  };
}

function mapVersionMeetingSnapshot(
  row: VersionMeetingSnapshotRow,
): VersionMeetingSnapshot {
  return {
    sectionCode: row.section_code,
    sectionDisplayName: row.section_display_name,
    courseName: row.course_name,
    instructorName: row.instructor_name,
    roomLabel: row.room_label,
    dayLabel: row.day_label,
    dayKey: row.day_key,
    slotStart: row.slot_start,
    slotEnd: row.slot_end,
    startTime: row.start_time,
    endTime: row.end_time,
    meetingType: row.meeting_type,
    online: row.online === 1,
    sourcePage: row.source_page,
    confidenceClass: row.confidence_class,
    warnings: parseJsonArray(row.warnings_json),
  };
}

export class TimetableVersionRepository {
  constructor(private readonly database: DatabaseClient) {}

  async create(record: {
    id: string;
    sourceFileName: string;
    generatedDate: string;
    sourceChecksum: string;
    importWarnings: string[];
    sectionCount: number;
    meetingCount: number;
    createdAt: string;
  }): Promise<void> {
    await this.database.run(
      `INSERT INTO timetable_versions (
        id,
        source_file_name,
        generated_date,
        source_checksum,
        publish_status,
        import_warnings_json,
        section_count,
        meeting_count,
        created_at
      ) VALUES (?, ?, ?, ?, 'draft', ?, ?, ?, ?)`,
      [
        record.id,
        record.sourceFileName,
        record.generatedDate,
        record.sourceChecksum,
        JSON.stringify(record.importWarnings),
        record.sectionCount,
        record.meetingCount,
        record.createdAt,
      ],
    );
  }

  async getById(id: string): Promise<TimetableVersionRecord | null> {
    const row = await this.database.queryFirst<VersionRow>(
      `SELECT
        id,
        source_file_name,
        generated_date,
        source_checksum,
        publish_status,
        import_warnings_json,
        section_count,
        meeting_count,
        created_at,
        published_at
      FROM timetable_versions
      WHERE id = ?`,
      [id],
    );

    return row ? mapVersion(row) : null;
  }

  async getByChecksum(
    checksum: string,
  ): Promise<TimetableVersionRecord | null> {
    const row = await this.database.queryFirst<VersionRow>(
      `SELECT
        id,
        source_file_name,
        generated_date,
        source_checksum,
        publish_status,
        import_warnings_json,
        section_count,
        meeting_count,
        created_at,
        published_at
      FROM timetable_versions
      WHERE source_checksum = ?`,
      [checksum],
    );

    return row ? mapVersion(row) : null;
  }

  async listAll(): Promise<TimetableVersionRecord[]> {
    const rows = await this.database.queryAll<VersionRow>(
      `SELECT
        id,
        source_file_name,
        generated_date,
        source_checksum,
        publish_status,
        import_warnings_json,
        section_count,
        meeting_count,
        created_at,
        published_at
      FROM timetable_versions
      ORDER BY
        CASE publish_status
          WHEN 'published' THEN 0
          WHEN 'draft' THEN 1
          ELSE 2
        END,
        COALESCE(published_at, created_at) DESC,
        id DESC`,
    );

    return rows.map(mapVersion);
  }

  async getCurrent(): Promise<TimetableVersionRecord | null> {
    const row = await this.database.queryFirst<VersionRow>(
      `SELECT
        id,
        source_file_name,
        generated_date,
        source_checksum,
        publish_status,
        import_warnings_json,
        section_count,
        meeting_count,
        created_at,
        published_at
      FROM timetable_versions
      WHERE publish_status = 'published'
      ORDER BY published_at DESC, created_at DESC
      LIMIT 1`,
    );

    return row ? mapVersion(row) : null;
  }

  async archivePublishedVersions(): Promise<void> {
    await this.database.run(
      `UPDATE timetable_versions
      SET publish_status = 'archived'
      WHERE publish_status = 'published'`,
    );
  }

  async markPublished(id: string, publishedAt: string): Promise<void> {
    await this.database.run(
      `UPDATE timetable_versions
      SET publish_status = 'published', published_at = ?
      WHERE id = ?`,
      [publishedAt, id],
    );
  }
}

export class SectionRepository {
  constructor(private readonly database: DatabaseClient) {}

  async upsert(record: {
    code: string;
    normalizedCode: string;
    displayName: string;
    createdAt: string;
  }): Promise<number> {
    await this.database.run(
      `INSERT INTO sections (code, normalized_code, display_name, active, created_at)
      VALUES (?, ?, ?, 0, ?)
      ON CONFLICT(normalized_code) DO UPDATE SET
        code = excluded.code,
        display_name = excluded.display_name`,
      [
        record.code,
        record.normalizedCode,
        record.displayName,
        record.createdAt,
      ],
    );

    const row = await this.database.queryFirst<{ id: number } & DatabaseRow>(
      `SELECT id FROM sections WHERE normalized_code = ?`,
      [record.normalizedCode],
    );

    if (!row) {
      throw new Error(
        `failed to fetch section id for ${record.normalizedCode}`,
      );
    }

    return row.id;
  }

  async refreshActiveFlags(versionId: string): Promise<void> {
    await this.database.run(
      `UPDATE sections
      SET active = CASE
        WHEN id IN (
          SELECT DISTINCT section_id
          FROM class_meetings
          WHERE version_id = ?
        ) THEN 1
        ELSE 0
      END`,
      [versionId],
    );
  }

  async listActiveWithMeetingCounts(
    versionId: string,
  ): Promise<Array<SectionRecord & { meetingCount: number }>> {
    const rows = await this.database.queryAll<
      SectionRow &
        DatabaseRow & {
          meeting_count: number;
        }
    >(
      `SELECT
        sections.id,
        sections.code,
        sections.normalized_code,
        sections.display_name,
        sections.active,
        COUNT(class_meetings.id) AS meeting_count
      FROM sections
      INNER JOIN class_meetings
        ON class_meetings.section_id = sections.id
      WHERE class_meetings.version_id = ?
      GROUP BY sections.id, sections.code, sections.normalized_code, sections.display_name, sections.active
      ORDER BY sections.code ASC`,
      [versionId],
    );

    return rows.map((row) => ({
      ...mapSection(row),
      meetingCount: Number(row.meeting_count),
    }));
  }

  async getActiveByNormalizedCode(
    versionId: string,
    normalizedCode: string,
  ): Promise<(SectionRecord & { meetingCount: number }) | null> {
    const row = await this.database.queryFirst<
      SectionRow &
        DatabaseRow & {
          meeting_count: number;
        }
    >(
      `SELECT
        sections.id,
        sections.code,
        sections.normalized_code,
        sections.display_name,
        sections.active,
        COUNT(class_meetings.id) AS meeting_count
      FROM sections
      INNER JOIN class_meetings
        ON class_meetings.section_id = sections.id
      WHERE class_meetings.version_id = ?
        AND sections.normalized_code = ?
      GROUP BY sections.id, sections.code, sections.normalized_code, sections.display_name, sections.active`,
      [versionId, normalizedCode],
    );

    return row
      ? {
          ...mapSection(row),
          meetingCount: Number(row.meeting_count),
        }
      : null;
  }
}

export class CourseRepository {
  constructor(private readonly database: DatabaseClient) {}

  async upsert(record: {
    name: string;
    slug: string;
    courseType: string | null;
    createdAt: string;
  }): Promise<number> {
    await this.database.run(
      `INSERT INTO courses (name, slug, course_type, created_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(name) DO UPDATE SET
        slug = excluded.slug,
        course_type = excluded.course_type`,
      [record.name, record.slug, record.courseType, record.createdAt],
    );

    const row = await this.database.queryFirst<{ id: number } & DatabaseRow>(
      `SELECT id FROM courses WHERE name = ?`,
      [record.name],
    );

    if (!row) {
      throw new Error(`failed to fetch course id for ${record.name}`);
    }

    return row.id;
  }
}

export class InstructorRepository {
  constructor(private readonly database: DatabaseClient) {}

  async upsert(record: {
    name: string;
    slug: string;
    createdAt: string;
  }): Promise<number> {
    await this.database.run(
      `INSERT INTO instructors (name, slug, created_at)
      VALUES (?, ?, ?)
      ON CONFLICT(name) DO UPDATE SET
        slug = excluded.slug`,
      [record.name, record.slug, record.createdAt],
    );

    const row = await this.database.queryFirst<{ id: number } & DatabaseRow>(
      `SELECT id FROM instructors WHERE name = ?`,
      [record.name],
    );

    if (!row) {
      throw new Error(`failed to fetch instructor id for ${record.name}`);
    }

    return row.id;
  }
}

export class RoomRepository {
  constructor(private readonly database: DatabaseClient) {}

  async upsert(record: {
    label: string;
    slug: string;
    isOnline: boolean;
    createdAt: string;
  }): Promise<number> {
    await this.database.run(
      `INSERT INTO rooms (label, slug, is_online, created_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(label) DO UPDATE SET
        slug = excluded.slug,
        is_online = excluded.is_online`,
      [record.label, record.slug, record.isOnline ? 1 : 0, record.createdAt],
    );

    const row = await this.database.queryFirst<{ id: number } & DatabaseRow>(
      `SELECT id FROM rooms WHERE label = ?`,
      [record.label],
    );

    if (!row) {
      throw new Error(`failed to fetch room id for ${record.label}`);
    }

    return row.id;
  }
}

export class ClassMeetingRepository {
  constructor(private readonly database: DatabaseClient) {}

  async create(record: {
    versionId: string;
    sectionId: number;
    courseId: number;
    instructorId: number | null;
    roomId: number | null;
    dayKey: MeetingRecord["dayKey"];
    dayLabel: string;
    daySort: number;
    slotStart: number;
    slotEnd: number;
    startTime: string;
    endTime: string;
    meetingType: MeetingRecord["meetingType"];
    online: boolean;
    sourcePage: number;
    confidenceClass: MeetingRecord["confidenceClass"];
    confidenceScore: number;
    warnings: string[];
    createdAt: string;
  }): Promise<void> {
    await this.database.run(
      `INSERT INTO class_meetings (
        version_id,
        section_id,
        course_id,
        instructor_id,
        room_id,
        day_key,
        day_label,
        day_sort,
        slot_start,
        slot_end,
        start_time,
        end_time,
        meeting_type,
        online,
        source_page,
        confidence_class,
        confidence_score,
        warnings_json,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        record.versionId,
        record.sectionId,
        record.courseId,
        record.instructorId,
        record.roomId,
        record.dayKey,
        record.dayLabel,
        record.daySort,
        record.slotStart,
        record.slotEnd,
        record.startTime,
        record.endTime,
        record.meetingType,
        record.online ? 1 : 0,
        record.sourcePage,
        record.confidenceClass,
        record.confidenceScore,
        JSON.stringify(record.warnings),
        record.createdAt,
      ],
    );
  }

  async listBySection(
    versionId: string,
    sectionId: number,
  ): Promise<MeetingRecord[]> {
    const rows = await this.database.queryAll<MeetingRow>(
      `SELECT
        class_meetings.id,
        class_meetings.version_id,
        sections.code AS section_code,
        sections.display_name AS section_display_name,
        courses.name AS course_name,
        instructors.name AS instructor_name,
        rooms.label AS room_label,
        class_meetings.day_label,
        class_meetings.day_key,
        class_meetings.slot_start,
        class_meetings.slot_end,
        class_meetings.start_time,
        class_meetings.end_time,
        class_meetings.meeting_type,
        class_meetings.online,
        class_meetings.source_page,
        class_meetings.confidence_class,
        class_meetings.confidence_score,
        class_meetings.warnings_json
      FROM class_meetings
      INNER JOIN sections
        ON sections.id = class_meetings.section_id
      INNER JOIN courses
        ON courses.id = class_meetings.course_id
      LEFT JOIN instructors
        ON instructors.id = class_meetings.instructor_id
      LEFT JOIN rooms
        ON rooms.id = class_meetings.room_id
      WHERE class_meetings.version_id = ?
        AND class_meetings.section_id = ?
      ORDER BY class_meetings.day_sort ASC, class_meetings.slot_start ASC, class_meetings.start_time ASC, courses.name ASC`,
      [versionId, sectionId],
    );

    return rows.map(mapMeeting);
  }

  async listVersionSnapshot(
    versionId: string,
  ): Promise<VersionMeetingSnapshot[]> {
    const rows = await this.database.queryAll<VersionMeetingSnapshotRow>(
      `SELECT
        sections.code AS section_code,
        sections.display_name AS section_display_name,
        courses.name AS course_name,
        instructors.name AS instructor_name,
        rooms.label AS room_label,
        class_meetings.day_label,
        class_meetings.day_key,
        class_meetings.slot_start,
        class_meetings.slot_end,
        class_meetings.start_time,
        class_meetings.end_time,
        class_meetings.meeting_type,
        class_meetings.online,
        class_meetings.source_page,
        class_meetings.confidence_class,
        class_meetings.warnings_json
      FROM class_meetings
      INNER JOIN sections
        ON sections.id = class_meetings.section_id
      INNER JOIN courses
        ON courses.id = class_meetings.course_id
      LEFT JOIN instructors
        ON instructors.id = class_meetings.instructor_id
      LEFT JOIN rooms
        ON rooms.id = class_meetings.room_id
      WHERE class_meetings.version_id = ?
      ORDER BY sections.code ASC, class_meetings.day_sort ASC, class_meetings.slot_start ASC, class_meetings.start_time ASC, courses.name ASC`,
      [versionId],
    );

    return rows.map(mapVersionMeetingSnapshot);
  }
}
