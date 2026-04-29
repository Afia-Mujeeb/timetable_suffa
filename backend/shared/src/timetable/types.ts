export const DAY_ORDER = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
] as const;

export type DayKey = (typeof DAY_ORDER)[number];

export type ConfidenceClass = "high" | "medium" | "low";
export type MeetingType = "lecture" | "lab";
export type PublishStatus = "draft" | "published" | "archived";
export type ImportRunStatus = "running" | "succeeded" | "failed";
export type AuditEventKind =
  | "import_succeeded"
  | "import_failed"
  | "published"
  | "rolled_back";

export type ParserValidation = {
  status: "passed" | "failed";
  errors: string[];
  warnings: string[];
};

export type ParserMeeting = {
  section: string;
  course_name: string;
  instructor: string | null;
  room: string | null;
  day: string;
  day_key: DayKey;
  online: boolean;
  meeting_type: MeetingType;
  slot_start: number;
  slot_end: number;
  start_time: string;
  end_time: string;
  source_page: number;
  source_version: string;
  confidence_class: ConfidenceClass;
  confidence_score: number;
  warnings: string[];
};

export type ParserArtifact = {
  source: {
    version_id: string;
    source_file_name: string;
    generated_date: string;
    page_count: number;
    sections: string[];
  };
  normalized_domain: {
    sections: string[];
    meetings: ParserMeeting[];
  };
  validation: ParserValidation;
};

export type TimetableVersionRecord = {
  id: string;
  sourceFileName: string;
  generatedDate: string;
  sourceChecksum: string;
  publishStatus: PublishStatus;
  importWarnings: string[];
  sectionCount: number;
  meetingCount: number;
  createdAt: string;
  publishedAt: string | null;
};

export type ImportRunRecord = {
  id: string;
  versionId: string | null;
  sourceFileName: string | null;
  sourceId: string | null;
  parserVersion: string | null;
  triggeredBy: string | null;
  status: ImportRunStatus;
  warningCount: number;
  warnings: string[];
  errorMessage: string | null;
  startedAt: string;
  completedAt: string | null;
};

export type AuditEventRecord = {
  id: string;
  eventKind: AuditEventKind;
  versionId: string | null;
  previousVersionId: string | null;
  triggeredBy: string | null;
  note: string | null;
  warningsIgnored: boolean;
  changeSummary: VersionChangeSummary | null;
  createdAt: string;
};

export type SectionRecord = {
  id: number;
  code: string;
  normalizedCode: string;
  displayName: string;
  active: boolean;
};

export type MeetingRecord = {
  id: number;
  versionId: string;
  sectionCode: string;
  sectionDisplayName: string;
  courseName: string;
  instructorName: string | null;
  roomLabel: string | null;
  dayLabel: string;
  dayKey: DayKey;
  slotStart: number;
  slotEnd: number;
  startTime: string;
  endTime: string;
  meetingType: MeetingType;
  online: boolean;
  sourcePage: number;
  confidenceClass: ConfidenceClass;
  confidenceScore: number;
  warnings: string[];
};

export type VersionMeetingSnapshot = {
  sectionCode: string;
  sectionDisplayName: string;
  courseName: string;
  instructorName: string | null;
  roomLabel: string | null;
  dayLabel: string;
  dayKey: DayKey;
  slotStart: number;
  slotEnd: number;
  startTime: string;
  endTime: string;
  meetingType: MeetingType;
  online: boolean;
  sourcePage: number;
  confidenceClass: ConfidenceClass;
  warnings: string[];
};

export type MeetingChangeKind =
  | "added"
  | "removed"
  | "day_changed"
  | "time_changed"
  | "room_changed"
  | "online_changed"
  | "instructor_changed"
  | "meeting_type_changed";

export type SectionMeetingChange = {
  meetingKey: string;
  courseName: string;
  changeKinds: MeetingChangeKind[];
  material: boolean;
  message: string;
  previousMeeting: TimetableMeetingResponse | null;
  nextMeeting: TimetableMeetingResponse | null;
};

export type SectionVersionDiff = {
  sectionCode: string;
  displayName: string;
  changeCount: number;
  addedCount: number;
  removedCount: number;
  modifiedCount: number;
  materialChangeCount: number;
  changes: SectionMeetingChange[];
};

export type VersionChangeSummary = {
  sectionsCompared: number;
  sectionsChanged: number;
  materialSections: number;
  totalChanges: number;
  addedCount: number;
  removedCount: number;
  modifiedCount: number;
  materialChangeCount: number;
};

export type VersionComparisonResult = {
  fromVersionId: string | null;
  toVersionId: string;
  summary: VersionChangeSummary;
  sections: SectionVersionDiff[];
};

export type TimetableMeetingResponse = {
  courseName: string;
  instructor: string | null;
  room: string | null;
  day: string;
  dayKey: DayKey;
  startTime: string;
  endTime: string;
  meetingType: MeetingType;
  online: boolean;
  sourcePage: number;
  confidenceClass: ConfidenceClass;
  warnings: string[];
};

export type TimetableVersionResponse = {
  versionId: string;
  sourceFileName: string;
  generatedDate: string;
  publishStatus: PublishStatus;
  sectionCount: number;
  meetingCount: number;
  warningCount: number;
  createdAt: string;
  publishedAt: string | null;
};

export type SectionSummaryResponse = {
  sectionCode: string;
  displayName: string;
  active: boolean;
  meetingCount: number;
};

export type SectionDetailResponse = SectionSummaryResponse & {
  timetableVersion: TimetableVersionResponse;
};

export type SectionTimetableResponse = {
  section: SectionDetailResponse;
  timetableVersion: TimetableVersionResponse;
  meetings: TimetableMeetingResponse[];
};

export type SectionsResponse = {
  timetableVersion: TimetableVersionResponse;
  sections: SectionSummaryResponse[];
};

export type VersionsResponse = {
  versions: TimetableVersionResponse[];
};

export type VersionSectionSummaryResponse = {
  sectionCode: string;
  displayName: string;
  meetingCount: number;
};

export type ImportRunResponse = {
  importRunId: string;
  versionId: string | null;
  sourceFileName: string | null;
  sourceId: string | null;
  parserVersion: string | null;
  triggeredBy: string | null;
  status: ImportRunStatus;
  warningCount: number;
  warnings: string[];
  errorMessage: string | null;
  startedAt: string;
  completedAt: string | null;
};

export type AuditEventResponse = {
  auditEventId: string;
  eventKind: AuditEventKind;
  versionId: string | null;
  previousVersionId: string | null;
  triggeredBy: string | null;
  note: string | null;
  warningsIgnored: boolean;
  changeSummary: VersionChangeSummary | null;
  createdAt: string;
};

export type ImportRunsResponse = {
  importRuns: ImportRunResponse[];
};

export type AuditEventsResponse = {
  auditEvents: AuditEventResponse[];
};

export type PushSectionPreview = {
  sectionCode: string;
  displayName: string;
  messageCount: number;
  messages: string[];
};

export type PushPreviewResponse = {
  wouldNotify: boolean;
  reason:
    | "first_publish"
    | "no_material_changes"
    | "sections_changed"
    | "current_version";
  sections: PushSectionPreview[];
};

export type VersionPreviewResponse = {
  version: TimetableVersionResponse;
  currentVersion: TimetableVersionResponse | null;
  importRun: ImportRunResponse | null;
  warnings: string[];
  sections: VersionSectionSummaryResponse[];
  changes: VersionComparisonResult;
  pushPreview: PushPreviewResponse;
  publishable: boolean;
};

export type ImportResult = {
  timetableVersion: TimetableVersionResponse;
  importedSections: number;
  importedMeetings: number;
  warningCount: number;
  importRun: ImportRunResponse;
};

export type PublishResult = {
  timetableVersion: TimetableVersionResponse;
  previousVersion: TimetableVersionResponse | null;
  changes: VersionComparisonResult;
  pushPreview: PushPreviewResponse;
  auditEvent: AuditEventResponse;
};

export type RollbackResult = {
  timetableVersion: TimetableVersionResponse;
  previousVersion: TimetableVersionResponse | null;
  changes: VersionComparisonResult;
  pushPreview: PushPreviewResponse;
  auditEvent: AuditEventResponse;
};
