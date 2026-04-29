import { createHash } from "node:crypto";

import type {
  DayKey,
  ParserArtifact,
  TimetableVersionRecord,
  TimetableVersionResponse,
} from "./types";

const SECTION_CODE_PATTERN = /^[A-Z0-9][A-Z0-9 -]{1,31}$/;
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const TIME_PATTERN = /^\d{2}:\d{2}$/;

export function normalizeSectionCode(value: string): string {
  return value.trim().replace(/\s+/g, " ").toUpperCase();
}

export function isValidSectionCode(value: string): boolean {
  return SECTION_CODE_PATTERN.test(normalizeSectionCode(value));
}

export function slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-{2,}/g, "-");
}

export function createChecksum(payload: ParserArtifact): string {
  return createHash("sha256").update(JSON.stringify(payload)).digest("hex");
}

export function toDaySort(dayKey: DayKey): number {
  return {
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5,
    saturday: 6,
  }[dayKey];
}

export function nowIso(): string {
  return new Date().toISOString();
}

export function toVersionResponse(
  record: TimetableVersionRecord,
): TimetableVersionResponse {
  return {
    versionId: record.id,
    sourceFileName: record.sourceFileName,
    generatedDate: record.generatedDate,
    publishStatus: record.publishStatus,
    sectionCount: record.sectionCount,
    meetingCount: record.meetingCount,
    warningCount: record.importWarnings.length,
    createdAt: record.createdAt,
    publishedAt: record.publishedAt,
  };
}

export function assertParserArtifactShape(
  payload: unknown,
): asserts payload is ParserArtifact {
  if (typeof payload !== "object" || payload === null) {
    throw new Error("payload must be an object");
  }

  const artifact = payload as Partial<ParserArtifact>;
  const source = artifact.source;
  const normalizedDomain = artifact.normalized_domain;
  const validation = artifact.validation;

  if (!source || typeof source !== "object") {
    throw new Error("source is required");
  }

  if (
    typeof source.version_id !== "string" ||
    typeof source.source_file_name !== "string" ||
    typeof source.generated_date !== "string" ||
    !ISO_DATE_PATTERN.test(source.generated_date) ||
    !Array.isArray(source.sections)
  ) {
    throw new Error("source fields are invalid");
  }

  if (!normalizedDomain || typeof normalizedDomain !== "object") {
    throw new Error("normalized_domain is required");
  }

  if (
    !Array.isArray(normalizedDomain.sections) ||
    !Array.isArray(normalizedDomain.meetings)
  ) {
    throw new Error("normalized_domain fields are invalid");
  }

  if (!validation || typeof validation !== "object") {
    throw new Error("validation is required");
  }

  if (
    (validation.status !== "passed" && validation.status !== "failed") ||
    !Array.isArray(validation.errors) ||
    !Array.isArray(validation.warnings)
  ) {
    throw new Error("validation fields are invalid");
  }

  for (const meeting of normalizedDomain.meetings) {
    if (typeof meeting !== "object" || meeting === null) {
      throw new Error("meeting entries must be objects");
    }

    const candidate = meeting as Record<string, unknown>;
    if (
      typeof candidate.section !== "string" ||
      typeof candidate.course_name !== "string" ||
      typeof candidate.day !== "string" ||
      typeof candidate.day_key !== "string" ||
      typeof candidate.start_time !== "string" ||
      typeof candidate.end_time !== "string" ||
      !TIME_PATTERN.test(candidate.start_time) ||
      !TIME_PATTERN.test(candidate.end_time) ||
      typeof candidate.source_version !== "string" ||
      !Array.isArray(candidate.warnings)
    ) {
      throw new Error("meeting fields are invalid");
    }
  }
}
