import { createEmptyVersionComparison, summarizeVersionChanges } from "./diff";
import { AppError } from "./errors";
import type { DatabaseClient } from "./db";
import {
  AuditEventRepository,
  ClassMeetingRepository,
  CourseRepository,
  ImportRunRepository,
  InstructorRepository,
  RoomRepository,
  SectionRepository,
  TimetableVersionRepository,
} from "./repositories";
import type {
  AuditEventsResponse,
  ImportResult,
  ImportRunsResponse,
  ParserArtifact,
  PublishResult,
  PushPreviewResponse,
  RollbackResult,
  SectionDetailResponse,
  SectionTimetableResponse,
  SectionsResponse,
  TimetableVersionResponse,
  VersionComparisonResult,
  VersionPreviewResponse,
  VersionsResponse,
} from "./types";
import {
  assertParserArtifactShape,
  createChecksum,
  isValidSectionCode,
  normalizeSectionCode,
  nowIso,
  slugify,
  toAuditEventResponse,
  toDaySort,
  toImportRunResponse,
  toVersionResponse,
} from "./utils";

type ImportArtifactInput = {
  artifact: unknown;
  sourceId: string | null;
  parserVersion: string | null;
  triggeredBy: string | null;
  note: string | null;
};

type VersionActionInput = {
  versionId: string;
  triggeredBy: string | null;
  note: string | null;
  ignoreWarnings: boolean;
};

function normalizeOptionalText(value: string | null | undefined): string | null {
  const normalized = value?.trim();
  return normalized ? normalized : null;
}

function extractArtifactDetails(input: unknown): {
  versionId: string | null;
  sourceFileName: string | null;
} {
  if (typeof input !== "object" || input === null) {
    return {
      versionId: null,
      sourceFileName: null,
    };
  }

  const source = (input as { source?: unknown }).source;
  if (typeof source !== "object" || source === null) {
    return {
      versionId: null,
      sourceFileName: null,
    };
  }

  const candidate = source as {
    version_id?: unknown;
    source_file_name?: unknown;
  };

  return {
    versionId:
      typeof candidate.version_id === "string" ? candidate.version_id : null,
    sourceFileName:
      typeof candidate.source_file_name === "string"
        ? candidate.source_file_name
        : null,
  };
}

async function runInTransaction<T>(
  database: DatabaseClient,
  operation: () => Promise<T>,
): Promise<T> {
  await database.exec("BEGIN");

  try {
    const result = await operation();
    await database.exec("COMMIT");
    return result;
  } catch (error) {
    await database.exec("ROLLBACK");
    throw error;
  }
}

function buildPushPreview(
  changes: VersionComparisonResult,
): PushPreviewResponse {
  if (changes.fromVersionId === changes.toVersionId) {
    return {
      wouldNotify: false,
      reason: "current_version",
      sections: [],
    };
  }

  if (changes.fromVersionId === null) {
    return {
      wouldNotify: false,
      reason: "first_publish",
      sections: [],
    };
  }

  const sections = changes.sections
    .filter((section) => section.materialChangeCount > 0)
    .map((section) => ({
      sectionCode: section.sectionCode,
      displayName: section.displayName,
      messageCount: section.materialChangeCount,
      messages: section.changes
        .filter((change) => change.material)
        .slice(0, 2)
        .map((change) => change.message),
    }));

  if (sections.length === 0) {
    return {
      wouldNotify: false,
      reason: "no_material_changes",
      sections: [],
    };
  }

  return {
    wouldNotify: true,
    reason: "sections_changed",
    sections,
  };
}

export class TimetableImportService {
  private readonly versions: TimetableVersionRepository;
  private readonly sections: SectionRepository;
  private readonly courses: CourseRepository;
  private readonly instructors: InstructorRepository;
  private readonly rooms: RoomRepository;
  private readonly meetings: ClassMeetingRepository;
  private readonly importRuns: ImportRunRepository;
  private readonly auditEvents: AuditEventRepository;

  constructor(private readonly database: DatabaseClient) {
    this.versions = new TimetableVersionRepository(database);
    this.sections = new SectionRepository(database);
    this.courses = new CourseRepository(database);
    this.instructors = new InstructorRepository(database);
    this.rooms = new RoomRepository(database);
    this.meetings = new ClassMeetingRepository(database);
    this.importRuns = new ImportRunRepository(database);
    this.auditEvents = new AuditEventRepository(database);
  }

  async importArtifact(input: ImportArtifactInput): Promise<ImportResult> {
    const startedAt = nowIso();
    const importRunId = crypto.randomUUID();
    const artifactDetails = extractArtifactDetails(input.artifact);

    await this.importRuns.create({
      id: importRunId,
      versionId: null,
      sourceFileName: artifactDetails.sourceFileName,
      sourceId: normalizeOptionalText(input.sourceId),
      parserVersion: normalizeOptionalText(input.parserVersion),
      triggeredBy: normalizeOptionalText(input.triggeredBy),
      startedAt,
    });

    let artifact: ParserArtifact | null = null;

    try {
      try {
        assertParserArtifactShape(input.artifact);
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "parser artifact is invalid";
        throw new AppError(
          "validation_error",
          `Import payload is invalid: ${message}`,
        );
      }

      artifact = input.artifact as ParserArtifact;

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

      const validatedArtifact = artifact;
      const createdAt = nowIso();
      await runInTransaction(this.database, async () => {
        await this.versions.create({
          id: validatedArtifact.source.version_id,
          sourceFileName: validatedArtifact.source.source_file_name,
          generatedDate: validatedArtifact.source.generated_date,
          sourceChecksum: checksum,
          importWarnings: validatedArtifact.validation.warnings,
          sectionCount: validatedArtifact.normalized_domain.sections.length,
          meetingCount: validatedArtifact.normalized_domain.meetings.length,
          createdAt,
        });

        for (const meeting of validatedArtifact.normalized_domain.meetings) {
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
            versionId: validatedArtifact.source.version_id,
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
      });

      const version = await this.versions.getById(
        validatedArtifact.source.version_id,
      );
      if (!version) {
        throw new AppError(
          "internal_error",
          "Imported version could not be reloaded.",
        );
      }

      const completedAt = nowIso();
      await this.importRuns.markSucceeded({
        id: importRunId,
        versionId: validatedArtifact.source.version_id,
        sourceFileName: validatedArtifact.source.source_file_name,
        warnings: validatedArtifact.validation.warnings,
        completedAt,
      });
      await this.auditEvents.create({
        id: crypto.randomUUID(),
        eventKind: "import_succeeded",
        versionId: validatedArtifact.source.version_id,
        previousVersionId: null,
        triggeredBy: normalizeOptionalText(input.triggeredBy),
        note: normalizeOptionalText(input.note),
        warningsIgnored: false,
        changeSummary: null,
        createdAt: completedAt,
      });

      const importRun = await this.importRuns.getLatestByVersionId(
        validatedArtifact.source.version_id,
      );
      if (!importRun) {
        throw new AppError(
          "internal_error",
          "Completed import run could not be reloaded.",
        );
      }

      return {
        timetableVersion: toVersionResponse(version),
        importedSections: validatedArtifact.normalized_domain.sections.length,
        importedMeetings: validatedArtifact.normalized_domain.meetings.length,
        warningCount: validatedArtifact.validation.warnings.length,
        importRun: toImportRunResponse(importRun),
      };
    } catch (error) {
      const completedAt = nowIso();
      const appError =
        error instanceof AppError
          ? error
          : new AppError(
              "internal_error",
              error instanceof Error ? error.message : "Import failed.",
            );

      const finalSourceFileName =
        artifact?.source.source_file_name ?? artifactDetails.sourceFileName;
      const warnings = artifact?.validation.warnings ?? [];
      const failureNote = normalizeOptionalText(input.note);

      await this.importRuns.markFailed({
        id: importRunId,
        versionId: null,
        sourceFileName: finalSourceFileName,
        warnings,
        errorMessage: appError.message,
        completedAt,
      });
      await this.auditEvents.create({
        id: crypto.randomUUID(),
        eventKind: "import_failed",
        versionId: null,
        previousVersionId: null,
        triggeredBy: normalizeOptionalText(input.triggeredBy),
        note:
          failureNote === null
            ? appError.message
            : `${failureNote} | ${appError.message}`,
        warningsIgnored: false,
        changeSummary: null,
        createdAt: completedAt,
      });

      throw appError;
    }
  }

  async publishVersion(input: VersionActionInput): Promise<PublishResult> {
    const version = await this.versions.getById(input.versionId);
    if (!version) {
      throw new AppError("not_found", `Version ${input.versionId} does not exist.`);
    }

    const importRun = await this.importRuns.getLatestByVersionId(input.versionId);
    if (!importRun || importRun.status !== "succeeded") {
      throw new AppError(
        "validation_error",
        `Version ${input.versionId} does not have a completed successful import run.`,
      );
    }

    if (version.publishStatus !== "draft") {
      throw new AppError(
        "validation_error",
        `Version ${input.versionId} is not a draft and cannot be published.`,
      );
    }

    if (version.importWarnings.length > 0 && !input.ignoreWarnings) {
      throw new AppError(
        "validation_error",
        `Version ${input.versionId} has import warnings. Review the preview and resend with ignoreWarnings=true to publish anyway.`,
      );
    }

    const previousVersion = await this.versions.getCurrent();
    const changes = await this.compareVersions(
      previousVersion?.id ?? null,
      input.versionId,
    );
    const pushPreview = buildPushPreview(changes);
    const publishedAt = nowIso();
    const auditEventId = crypto.randomUUID();

    await runInTransaction(this.database, async () => {
      await this.versions.archivePublishedVersions();
      await this.versions.markPublished(input.versionId, publishedAt);
      await this.sections.refreshActiveFlags(input.versionId);
      await this.auditEvents.create({
        id: auditEventId,
        eventKind: "published",
        versionId: input.versionId,
        previousVersionId: previousVersion?.id ?? null,
        triggeredBy: normalizeOptionalText(input.triggeredBy),
        note: normalizeOptionalText(input.note),
        warningsIgnored: version.importWarnings.length > 0 && input.ignoreWarnings,
        changeSummary: changes.summary,
        createdAt: publishedAt,
      });
    });

    const publishedVersion = await this.versions.getById(input.versionId);
    if (!publishedVersion) {
      throw new AppError(
        "internal_error",
        "Published version could not be reloaded.",
      );
    }

    return {
      timetableVersion: toVersionResponse(publishedVersion),
      previousVersion: previousVersion ? toVersionResponse(previousVersion) : null,
      changes,
      pushPreview,
      auditEvent: toAuditEventResponse({
        id: auditEventId,
        eventKind: "published",
        versionId: input.versionId,
        previousVersionId: previousVersion?.id ?? null,
        triggeredBy: normalizeOptionalText(input.triggeredBy),
        note: normalizeOptionalText(input.note),
        warningsIgnored: version.importWarnings.length > 0 && input.ignoreWarnings,
        changeSummary: changes.summary,
        createdAt: publishedAt,
      }),
    };
  }

  async rollbackVersion(input: VersionActionInput): Promise<RollbackResult> {
    const version = await this.versions.getById(input.versionId);
    if (!version) {
      throw new AppError("not_found", `Version ${input.versionId} does not exist.`);
    }

    if (version.publishStatus !== "archived") {
      throw new AppError(
        "validation_error",
        `Version ${input.versionId} is not an archived version and cannot be rolled back to.`,
      );
    }

    const importRun = await this.importRuns.getLatestByVersionId(input.versionId);
    if (!importRun || importRun.status !== "succeeded") {
      throw new AppError(
        "validation_error",
        `Version ${input.versionId} does not have a completed successful import run.`,
      );
    }

    if (version.importWarnings.length > 0 && !input.ignoreWarnings) {
      throw new AppError(
        "validation_error",
        `Version ${input.versionId} has import warnings. Review the preview and resend with ignoreWarnings=true to roll back anyway.`,
      );
    }

    const currentVersion = await this.versions.getCurrent();
    if (!currentVersion) {
      throw new AppError(
        "dependency_unavailable",
        "No current version exists to roll back from.",
      );
    }

    if (currentVersion.id === input.versionId) {
      throw new AppError(
        "validation_error",
        `Version ${input.versionId} is already the current published version.`,
      );
    }

    const changes = await this.compareVersions(currentVersion.id, input.versionId);
    const pushPreview = buildPushPreview(changes);
    const rolledBackAt = nowIso();
    const auditEventId = crypto.randomUUID();

    await runInTransaction(this.database, async () => {
      await this.versions.archivePublishedVersions();
      await this.versions.markPublished(input.versionId, rolledBackAt);
      await this.sections.refreshActiveFlags(input.versionId);
      await this.auditEvents.create({
        id: auditEventId,
        eventKind: "rolled_back",
        versionId: input.versionId,
        previousVersionId: currentVersion.id,
        triggeredBy: normalizeOptionalText(input.triggeredBy),
        note: normalizeOptionalText(input.note),
        warningsIgnored: version.importWarnings.length > 0 && input.ignoreWarnings,
        changeSummary: changes.summary,
        createdAt: rolledBackAt,
      });
    });

    const rolledBackVersion = await this.versions.getById(input.versionId);
    if (!rolledBackVersion) {
      throw new AppError(
        "internal_error",
        "Rolled-back version could not be reloaded.",
      );
    }

    return {
      timetableVersion: toVersionResponse(rolledBackVersion),
      previousVersion: toVersionResponse(currentVersion),
      changes,
      pushPreview,
      auditEvent: toAuditEventResponse({
        id: auditEventId,
        eventKind: "rolled_back",
        versionId: input.versionId,
        previousVersionId: currentVersion.id,
        triggeredBy: normalizeOptionalText(input.triggeredBy),
        note: normalizeOptionalText(input.note),
        warningsIgnored: version.importWarnings.length > 0 && input.ignoreWarnings,
        changeSummary: changes.summary,
        createdAt: rolledBackAt,
      }),
    };
  }

  private async compareVersions(
    previousVersionId: string | null,
    nextVersionId: string,
  ): Promise<VersionComparisonResult> {
    if (previousVersionId === nextVersionId) {
      return createEmptyVersionComparison({
        fromVersionId: previousVersionId,
        toVersionId: nextVersionId,
      });
    }

    const nextSnapshotPromise = this.meetings.listVersionSnapshot(nextVersionId);
    const previousSnapshotPromise =
      previousVersionId === null
        ? Promise.resolve([])
        : this.meetings.listVersionSnapshot(previousVersionId);
    const [previousMeetings, nextMeetings] = await Promise.all([
      previousSnapshotPromise,
      nextSnapshotPromise,
    ]);

    return summarizeVersionChanges({
      previousVersionId,
      nextVersionId,
      previousMeetings,
      nextMeetings,
    });
  }
}

export class TimetableAdminQueryService {
  private readonly versions: TimetableVersionRepository;
  private readonly sections: SectionRepository;
  private readonly meetings: ClassMeetingRepository;
  private readonly importRuns: ImportRunRepository;
  private readonly auditEvents: AuditEventRepository;

  constructor(database: DatabaseClient) {
    this.versions = new TimetableVersionRepository(database);
    this.sections = new SectionRepository(database);
    this.meetings = new ClassMeetingRepository(database);
    this.importRuns = new ImportRunRepository(database);
    this.auditEvents = new AuditEventRepository(database);
  }

  async listVersions(): Promise<VersionsResponse> {
    const versions = await this.versions.listAll();
    return {
      versions: versions.map(toVersionResponse),
    };
  }

  async getVersionPreview(versionId: string): Promise<VersionPreviewResponse> {
    const version = await this.versions.getById(versionId);
    if (!version) {
      throw new AppError("not_found", `Version ${versionId} does not exist.`);
    }

    const currentVersion = await this.versions.getCurrent();
    const importRun = await this.importRuns.getLatestByVersionId(versionId);
    const sections = await this.sections.listByVersionWithMeetingCounts(versionId);
    const changes =
      currentVersion?.id === versionId
        ? createEmptyVersionComparison({
            fromVersionId: versionId,
            toVersionId: versionId,
          })
        : await this.compareVersions(currentVersion?.id ?? null, versionId);

    return {
      version: toVersionResponse(version),
      currentVersion: currentVersion ? toVersionResponse(currentVersion) : null,
      importRun: importRun ? toImportRunResponse(importRun) : null,
      warnings: version.importWarnings,
      sections: sections.map((section) => ({
        sectionCode: section.code,
        displayName: section.displayName,
        meetingCount: section.meetingCount,
      })),
      changes,
      pushPreview: buildPushPreview(changes),
      publishable:
        version.publishStatus === "draft" && importRun?.status === "succeeded",
    };
  }

  async listImportRuns(): Promise<ImportRunsResponse> {
    const importRuns = await this.importRuns.listAll();
    return {
      importRuns: importRuns.map(toImportRunResponse),
    };
  }

  async listAuditEvents(): Promise<AuditEventsResponse> {
    const auditEvents = await this.auditEvents.listAll();
    return {
      auditEvents: auditEvents.map(toAuditEventResponse),
    };
  }

  private async compareVersions(
    previousVersionId: string | null,
    nextVersionId: string,
  ): Promise<VersionComparisonResult> {
    const nextMeetingsPromise = this.meetings.listVersionSnapshot(nextVersionId);
    const previousMeetingsPromise =
      previousVersionId === null
        ? Promise.resolve([])
        : this.meetings.listVersionSnapshot(previousVersionId);
    const [previousMeetings, nextMeetings] = await Promise.all([
      previousMeetingsPromise,
      nextMeetingsPromise,
    ]);

    return summarizeVersionChanges({
      previousVersionId,
      nextVersionId,
      previousMeetings,
      nextMeetings,
    });
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

    const sections = await this.sections.listActiveWithMeetingCounts(version.id);
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
