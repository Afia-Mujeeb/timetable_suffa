import { AppError } from "./errors";
import type { DatabaseClient } from "./db";
import {
  ClassMeetingRepository,
  CourseRepository,
  InstructorRepository,
  RoomRepository,
  SectionRepository,
  TimetableVersionRepository,
} from "./repositories";
import type {
  ImportResult,
  ParserArtifact,
  PublishResult,
  SectionDetailResponse,
  SectionTimetableResponse,
  SectionsResponse,
  TimetableVersionResponse,
  VersionsResponse,
} from "./types";
import {
  assertParserArtifactShape,
  createChecksum,
  isValidSectionCode,
  normalizeSectionCode,
  nowIso,
  slugify,
  toDaySort,
  toVersionResponse,
} from "./utils";

export class TimetableImportService {
  private readonly versions: TimetableVersionRepository;
  private readonly sections: SectionRepository;
  private readonly courses: CourseRepository;
  private readonly instructors: InstructorRepository;
  private readonly rooms: RoomRepository;
  private readonly meetings: ClassMeetingRepository;

  constructor(private readonly database: DatabaseClient) {
    this.versions = new TimetableVersionRepository(database);
    this.sections = new SectionRepository(database);
    this.courses = new CourseRepository(database);
    this.instructors = new InstructorRepository(database);
    this.rooms = new RoomRepository(database);
    this.meetings = new ClassMeetingRepository(database);
  }

  async importArtifact(input: unknown): Promise<ImportResult> {
    try {
      assertParserArtifactShape(input);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "parser artifact is invalid";
      throw new AppError(
        "validation_error",
        `Import payload is invalid: ${message}`,
      );
    }

    const artifact = input as ParserArtifact;

    if (artifact.validation.status !== "passed") {
      throw new AppError(
        "validation_error",
        "Parser artifact validation status must be passed before import.",
      );
    }

    if (artifact.validation.errors.length > 0) {
      throw new AppError(
        "validation_error",
        "Parser artifact contains validation errors and cannot be imported.",
      );
    }

    const checksum = createChecksum(artifact);
    const existingByVersion = await this.versions.getById(
      artifact.source.version_id,
    );
    if (existingByVersion) {
      throw new AppError(
        "import_conflict",
        `Version ${artifact.source.version_id} has already been imported.`,
      );
    }

    const existingByChecksum = await this.versions.getByChecksum(checksum);
    if (existingByChecksum) {
      throw new AppError(
        "import_conflict",
        `Artifact checksum already exists as version ${existingByChecksum.id}.`,
      );
    }

    const createdAt = nowIso();
    await this.versions.create({
      id: artifact.source.version_id,
      sourceFileName: artifact.source.source_file_name,
      generatedDate: artifact.source.generated_date,
      sourceChecksum: checksum,
      importWarnings: artifact.validation.warnings,
      sectionCount: artifact.normalized_domain.sections.length,
      meetingCount: artifact.normalized_domain.meetings.length,
      createdAt,
    });

    for (const meeting of artifact.normalized_domain.meetings) {
      const normalizedSectionCode = normalizeSectionCode(meeting.section);
      const sectionId = await this.sections.upsert({
        code: normalizedSectionCode,
        normalizedCode: normalizedSectionCode,
        displayName: normalizedSectionCode,
        createdAt,
      });

      const courseId = await this.courses.upsert({
        name: meeting.course_name.trim(),
        slug: slugify(meeting.course_name),
        courseType: null,
        createdAt,
      });

      const instructorId = meeting.instructor?.trim()
        ? await this.instructors.upsert({
            name: meeting.instructor.trim(),
            slug: slugify(meeting.instructor),
            createdAt,
          })
        : null;

      const roomId = meeting.room?.trim()
        ? await this.rooms.upsert({
            label: meeting.room.trim(),
            slug: slugify(meeting.room),
            isOnline: meeting.online,
            createdAt,
          })
        : null;

      await this.meetings.create({
        versionId: artifact.source.version_id,
        sectionId,
        courseId,
        instructorId,
        roomId,
        dayKey: meeting.day_key,
        dayLabel: meeting.day,
        daySort: toDaySort(meeting.day_key),
        slotStart: meeting.slot_start,
        slotEnd: meeting.slot_end,
        startTime: meeting.start_time,
        endTime: meeting.end_time,
        meetingType: meeting.meeting_type,
        online: meeting.online,
        sourcePage: meeting.source_page,
        confidenceClass: meeting.confidence_class,
        confidenceScore: meeting.confidence_score,
        warnings: meeting.warnings,
        createdAt,
      });
    }

    const version = await this.versions.getById(artifact.source.version_id);
    if (!version) {
      throw new AppError(
        "internal_error",
        "Imported version could not be reloaded.",
      );
    }

    return {
      timetableVersion: toVersionResponse(version),
      importedSections: artifact.normalized_domain.sections.length,
      importedMeetings: artifact.normalized_domain.meetings.length,
      warningCount: artifact.validation.warnings.length,
    };
  }

  async publishVersion(versionId: string): Promise<PublishResult> {
    const version = await this.versions.getById(versionId);
    if (!version) {
      throw new AppError("not_found", `Version ${versionId} does not exist.`);
    }

    await this.versions.archivePublishedVersions();
    const publishedAt = nowIso();
    await this.versions.markPublished(versionId, publishedAt);
    await this.sections.refreshActiveFlags(versionId);

    const publishedVersion = await this.versions.getById(versionId);
    if (!publishedVersion) {
      throw new AppError(
        "internal_error",
        "Published version could not be reloaded.",
      );
    }

    return {
      timetableVersion: toVersionResponse(publishedVersion),
    };
  }
}

export class TimetableQueryService {
  private readonly versions: TimetableVersionRepository;
  private readonly sections: SectionRepository;
  private readonly meetings: ClassMeetingRepository;

  constructor(database: DatabaseClient) {
    this.versions = new TimetableVersionRepository(database);
    this.sections = new SectionRepository(database);
    this.meetings = new ClassMeetingRepository(database);
  }

  async getCurrentVersion(): Promise<TimetableVersionResponse> {
    const version = await this.versions.getCurrent();
    if (!version) {
      throw new AppError(
        "dependency_unavailable",
        "No published timetable version is available.",
      );
    }

    return toVersionResponse(version);
  }

  async listVersions(): Promise<VersionsResponse> {
    const versions = await this.versions.listAll();
    return {
      versions: versions.map(toVersionResponse),
    };
  }

  async listSections(): Promise<SectionsResponse> {
    const version = await this.versions.getCurrent();
    if (!version) {
      throw new AppError(
        "dependency_unavailable",
        "No published timetable version is available.",
      );
    }

    const sections = await this.sections.listActiveWithMeetingCounts(
      version.id,
    );
    return {
      timetableVersion: toVersionResponse(version),
      sections: sections.map((section) => ({
        sectionCode: section.code,
        displayName: section.displayName,
        active: section.active,
        meetingCount: section.meetingCount,
      })),
    };
  }

  async getSection(sectionCode: string): Promise<SectionDetailResponse> {
    const normalizedSectionCode = normalizeSectionCode(sectionCode);
    if (!isValidSectionCode(normalizedSectionCode)) {
      throw new AppError(
        "validation_error",
        `Section code ${sectionCode} is invalid.`,
      );
    }

    const version = await this.versions.getCurrent();
    if (!version) {
      throw new AppError(
        "dependency_unavailable",
        "No published timetable version is available.",
      );
    }

    const section = await this.sections.getActiveByNormalizedCode(
      version.id,
      normalizedSectionCode,
    );
    if (!section) {
      throw new AppError(
        "not_found",
        `Section ${normalizedSectionCode} was not found.`,
      );
    }

    return {
      sectionCode: section.code,
      displayName: section.displayName,
      active: section.active,
      meetingCount: section.meetingCount,
      timetableVersion: toVersionResponse(version),
    };
  }

  async getSectionTimetable(
    sectionCode: string,
  ): Promise<SectionTimetableResponse> {
    const normalizedSectionCode = normalizeSectionCode(sectionCode);
    if (!isValidSectionCode(normalizedSectionCode)) {
      throw new AppError(
        "validation_error",
        `Section code ${sectionCode} is invalid.`,
      );
    }

    const version = await this.versions.getCurrent();
    if (!version) {
      throw new AppError(
        "dependency_unavailable",
        "No published timetable version is available.",
      );
    }

    const section = await this.sections.getActiveByNormalizedCode(
      version.id,
      normalizedSectionCode,
    );
    if (!section) {
      throw new AppError(
        "not_found",
        `Section ${normalizedSectionCode} was not found.`,
      );
    }

    const meetings = await this.meetings.listBySection(version.id, section.id);

    return {
      section: {
        sectionCode: section.code,
        displayName: section.displayName,
        active: section.active,
        meetingCount: section.meetingCount,
        timetableVersion: toVersionResponse(version),
      },
      timetableVersion: toVersionResponse(version),
      meetings: meetings.map((meeting) => ({
        courseName: meeting.courseName,
        instructor: meeting.instructorName,
        room: meeting.roomLabel,
        day: meeting.dayLabel,
        dayKey: meeting.dayKey,
        startTime: meeting.startTime,
        endTime: meeting.endTime,
        meetingType: meeting.meetingType,
        online: meeting.online,
        sourcePage: meeting.sourcePage,
        confidenceClass: meeting.confidenceClass,
        warnings: meeting.warnings,
      })),
    };
  }
}
