import type {
  DayKey,
  MeetingChangeKind,
  SectionMeetingChange,
  SectionVersionDiff,
  TimetableMeetingResponse,
  VersionChangeSummary,
  VersionComparisonResult,
  VersionMeetingSnapshot,
} from "./types";

type IndexedMeeting = {
  index: number;
  meeting: VersionMeetingSnapshot;
};

type MatchedPair = {
  previous: IndexedMeeting;
  next: IndexedMeeting;
};

type PairingResult = {
  pairs: MatchedPair[];
  remainingPrevious: IndexedMeeting[];
  remainingNext: IndexedMeeting[];
};

const DAY_SORT: Record<DayKey, number> = {
  monday: 1,
  tuesday: 2,
  wednesday: 3,
  thursday: 4,
  friday: 5,
  saturday: 6,
};

function normalizeText(value: string): string {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

function normalizeNullableText(value: string | null): string {
  return value === null ? "" : normalizeText(value);
}

function createExactMatchKey(meeting: VersionMeetingSnapshot): string {
  return [
    normalizeText(meeting.sectionCode),
    normalizeText(meeting.courseName),
    meeting.dayKey,
    meeting.startTime,
    meeting.endTime,
  ].join("|");
}

function createDayScopedMatchKey(meeting: VersionMeetingSnapshot): string {
  return [
    normalizeText(meeting.sectionCode),
    normalizeText(meeting.courseName),
    meeting.dayKey,
  ].join("|");
}

function createCourseScopedMatchKey(meeting: VersionMeetingSnapshot): string {
  return [
    normalizeText(meeting.sectionCode),
    normalizeText(meeting.courseName),
  ].join("|");
}

function createMeetingKey(meeting: VersionMeetingSnapshot): string {
  return [
    normalizeText(meeting.sectionCode),
    normalizeText(meeting.courseName),
    meeting.dayKey,
    meeting.startTime,
    meeting.endTime,
    normalizeNullableText(meeting.roomLabel),
  ].join("|");
}

function compareIndexedMeetings(
  left: IndexedMeeting,
  right: IndexedMeeting,
): number {
  const dayComparison =
    DAY_SORT[left.meeting.dayKey] - DAY_SORT[right.meeting.dayKey];
  if (dayComparison !== 0) {
    return dayComparison;
  }

  const slotComparison = left.meeting.slotStart - right.meeting.slotStart;
  if (slotComparison !== 0) {
    return slotComparison;
  }

  const endSlotComparison = left.meeting.slotEnd - right.meeting.slotEnd;
  if (endSlotComparison !== 0) {
    return endSlotComparison;
  }

  const courseComparison = left.meeting.courseName.localeCompare(
    right.meeting.courseName,
  );
  if (courseComparison !== 0) {
    return courseComparison;
  }

  return left.index - right.index;
}

function indexMeetings(
  meetings: readonly VersionMeetingSnapshot[],
): IndexedMeeting[] {
  return meetings.map((meeting, index) => ({ index, meeting }));
}

function groupIndexedMeetings(
  meetings: readonly IndexedMeeting[],
  keySelector: (meeting: VersionMeetingSnapshot) => string,
): Map<string, IndexedMeeting[]> {
  const grouped = new Map<string, IndexedMeeting[]>();

  for (const meeting of meetings) {
    const key = keySelector(meeting.meeting);
    const values = grouped.get(key) ?? [];
    values.push(meeting);
    grouped.set(key, values);
  }

  for (const values of grouped.values()) {
    values.sort(compareIndexedMeetings);
  }

  return grouped;
}

function pairByExactKey(
  previousMeetings: readonly IndexedMeeting[],
  nextMeetings: readonly IndexedMeeting[],
): PairingResult {
  const nextByKey = groupIndexedMeetings(nextMeetings, createExactMatchKey);
  const pairs: MatchedPair[] = [];
  const remainingPrevious: IndexedMeeting[] = [];

  for (const previous of [...previousMeetings].sort(compareIndexedMeetings)) {
    const key = createExactMatchKey(previous.meeting);
    const candidates = nextByKey.get(key);
    if (!candidates || candidates.length === 0) {
      remainingPrevious.push(previous);
      continue;
    }

    const next = candidates.shift();
    if (!next) {
      remainingPrevious.push(previous);
      continue;
    }

    pairs.push({ previous, next });
  }

  const remainingNext = [...nextByKey.values()]
    .flatMap((candidates) => candidates)
    .sort(compareIndexedMeetings);

  return {
    pairs,
    remainingPrevious,
    remainingNext,
  };
}

function pairByGroupedScore(
  previousMeetings: readonly IndexedMeeting[],
  nextMeetings: readonly IndexedMeeting[],
  keySelector: (meeting: VersionMeetingSnapshot) => string,
  scoreSelector: (
    previous: VersionMeetingSnapshot,
    next: VersionMeetingSnapshot,
  ) => number,
): PairingResult {
  const previousByKey = groupIndexedMeetings(previousMeetings, keySelector);
  const nextByKey = groupIndexedMeetings(nextMeetings, keySelector);
  const keys = [
    ...new Set([...previousByKey.keys(), ...nextByKey.keys()]),
  ].sort();
  const pairs: MatchedPair[] = [];
  const remainingPrevious: IndexedMeeting[] = [];
  const remainingNext: IndexedMeeting[] = [];

  for (const key of keys) {
    const previousCandidates = previousByKey.get(key) ?? [];
    const nextCandidates = nextByKey.get(key) ?? [];
    const usedNextIndexes = new Set<number>();

    for (const previous of previousCandidates) {
      let bestMatchIndex = -1;
      let bestScore = Number.POSITIVE_INFINITY;

      for (let index = 0; index < nextCandidates.length; index += 1) {
        if (usedNextIndexes.has(index)) {
          continue;
        }

        const next = nextCandidates[index];
        if (!next) {
          continue;
        }

        const score = scoreSelector(previous.meeting, next.meeting);
        if (score < bestScore) {
          bestScore = score;
          bestMatchIndex = index;
        }
      }

      if (bestMatchIndex === -1) {
        remainingPrevious.push(previous);
        continue;
      }

      usedNextIndexes.add(bestMatchIndex);
      const next = nextCandidates[bestMatchIndex];
      if (!next) {
        remainingPrevious.push(previous);
        continue;
      }

      pairs.push({
        previous,
        next,
      });
    }

    for (let index = 0; index < nextCandidates.length; index += 1) {
      if (!usedNextIndexes.has(index)) {
        const next = nextCandidates[index];
        if (next) {
          remainingNext.push(next);
        }
      }
    }
  }

  return {
    pairs,
    remainingPrevious: remainingPrevious.sort(compareIndexedMeetings),
    remainingNext: remainingNext.sort(compareIndexedMeetings),
  };
}

function timeDifference(
  previous: VersionMeetingSnapshot,
  next: VersionMeetingSnapshot,
): number {
  return (
    Math.abs(previous.slotStart - next.slotStart) * 10 +
    Math.abs(previous.slotEnd - next.slotEnd)
  );
}

function dayAndTimeDifference(
  previous: VersionMeetingSnapshot,
  next: VersionMeetingSnapshot,
): number {
  return (
    Math.abs(DAY_SORT[previous.dayKey] - DAY_SORT[next.dayKey]) * 1000 +
    timeDifference(previous, next)
  );
}

function toMeetingResponse(
  meeting: VersionMeetingSnapshot,
): TimetableMeetingResponse {
  return {
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
  };
}

function describeLocation(meeting: VersionMeetingSnapshot): string {
  if (meeting.online) {
    return "online";
  }

  if (meeting.roomLabel?.trim()) {
    return meeting.roomLabel.trim();
  }

  return "TBA";
}

function dayLabelFor(dayKey: DayKey): string {
  return dayKey.charAt(0).toUpperCase() + dayKey.slice(1);
}

function describeSchedule(meeting: VersionMeetingSnapshot): string {
  return `${dayLabelFor(meeting.dayKey)} ${meeting.startTime}-${meeting.endTime}`;
}

function buildChangeKinds(
  previous: VersionMeetingSnapshot,
  next: VersionMeetingSnapshot,
): MeetingChangeKind[] {
  const changeKinds: MeetingChangeKind[] = [];

  if (previous.dayKey !== next.dayKey) {
    changeKinds.push("day_changed");
  }

  if (
    previous.startTime !== next.startTime ||
    previous.endTime !== next.endTime ||
    previous.slotStart !== next.slotStart ||
    previous.slotEnd !== next.slotEnd
  ) {
    changeKinds.push("time_changed");
  }

  if (previous.meetingType !== next.meetingType) {
    changeKinds.push("meeting_type_changed");
  }

  if (previous.online !== next.online) {
    changeKinds.push("online_changed");
  }

  if (
    normalizeNullableText(previous.roomLabel) !==
    normalizeNullableText(next.roomLabel)
  ) {
    changeKinds.push("room_changed");
  }

  if (
    normalizeNullableText(previous.instructorName) !==
    normalizeNullableText(next.instructorName)
  ) {
    changeKinds.push("instructor_changed");
  }

  return changeKinds;
}

function buildUpdatedMessage(
  courseName: string,
  previous: VersionMeetingSnapshot,
  next: VersionMeetingSnapshot,
  changeKinds: readonly MeetingChangeKind[],
): string {
  const parts: string[] = [];
  const moved =
    changeKinds.includes("day_changed") || changeKinds.includes("time_changed");

  if (moved) {
    parts.push(
      `moved from ${describeSchedule(previous)} to ${describeSchedule(next)}`,
    );
  }

  if (changeKinds.includes("meeting_type_changed")) {
    parts.push(
      `type changed from ${previous.meetingType} to ${next.meetingType}`,
    );
  }

  if (changeKinds.includes("room_changed")) {
    parts.push(
      `location changed from ${describeLocation(previous)} to ${describeLocation(next)}`,
    );
  }

  if (
    changeKinds.includes("online_changed") &&
    !changeKinds.includes("room_changed")
  ) {
    parts.push(
      `delivery changed from ${previous.online ? "online" : "on campus"} to ${
        next.online ? "online" : "on campus"
      }`,
    );
  }

  if (changeKinds.includes("instructor_changed")) {
    parts.push(
      `instructor changed from ${previous.instructorName ?? "TBA"} to ${
        next.instructorName ?? "TBA"
      }`,
    );
  }

  return `${courseName}: ${parts.join("; ")}.`;
}

function buildAddedChange(
  meeting: VersionMeetingSnapshot,
): SectionMeetingChange {
  return {
    meetingKey: createMeetingKey(meeting),
    courseName: meeting.courseName,
    changeKinds: ["added"],
    material: true,
    message: `${meeting.courseName}: added on ${describeSchedule(meeting)} in ${describeLocation(meeting)}.`,
    previousMeeting: null,
    nextMeeting: toMeetingResponse(meeting),
  };
}

function buildRemovedChange(
  meeting: VersionMeetingSnapshot,
): SectionMeetingChange {
  return {
    meetingKey: createMeetingKey(meeting),
    courseName: meeting.courseName,
    changeKinds: ["removed"],
    material: true,
    message: `${meeting.courseName}: removed from ${describeSchedule(meeting)} in ${describeLocation(meeting)}.`,
    previousMeeting: toMeetingResponse(meeting),
    nextMeeting: null,
  };
}

function buildUpdatedChange(
  previous: VersionMeetingSnapshot,
  next: VersionMeetingSnapshot,
): SectionMeetingChange | null {
  const changeKinds = buildChangeKinds(previous, next);
  if (changeKinds.length === 0) {
    return null;
  }

  return {
    meetingKey: createMeetingKey(next),
    courseName: next.courseName,
    changeKinds,
    material: true,
    message: buildUpdatedMessage(next.courseName, previous, next, changeKinds),
    previousMeeting: toMeetingResponse(previous),
    nextMeeting: toMeetingResponse(next),
  };
}

function buildSectionDiff(input: {
  sectionCode: string;
  displayName: string;
  previousMeetings: readonly VersionMeetingSnapshot[];
  nextMeetings: readonly VersionMeetingSnapshot[];
}): SectionVersionDiff | null {
  const previousIndexed = indexMeetings(input.previousMeetings);
  const nextIndexed = indexMeetings(input.nextMeetings);

  const exact = pairByExactKey(previousIndexed, nextIndexed);
  const dayScoped = pairByGroupedScore(
    exact.remainingPrevious,
    exact.remainingNext,
    createDayScopedMatchKey,
    timeDifference,
  );
  const courseScoped = pairByGroupedScore(
    dayScoped.remainingPrevious,
    dayScoped.remainingNext,
    createCourseScopedMatchKey,
    dayAndTimeDifference,
  );

  const changes: SectionMeetingChange[] = [];

  for (const pair of [
    ...exact.pairs,
    ...dayScoped.pairs,
    ...courseScoped.pairs,
  ]) {
    const updatedChange = buildUpdatedChange(
      pair.previous.meeting,
      pair.next.meeting,
    );
    if (updatedChange) {
      changes.push(updatedChange);
    }
  }

  for (const meeting of courseScoped.remainingPrevious) {
    changes.push(buildRemovedChange(meeting.meeting));
  }

  for (const meeting of courseScoped.remainingNext) {
    changes.push(buildAddedChange(meeting.meeting));
  }

  if (changes.length === 0) {
    return null;
  }

  changes.sort((left, right) => left.message.localeCompare(right.message));

  const addedCount = changes.filter((change) =>
    change.changeKinds.includes("added"),
  ).length;
  const removedCount = changes.filter((change) =>
    change.changeKinds.includes("removed"),
  ).length;
  const modifiedCount = changes.length - addedCount - removedCount;
  const materialChangeCount = changes.filter(
    (change) => change.material,
  ).length;

  return {
    sectionCode: input.sectionCode,
    displayName: input.displayName,
    changeCount: changes.length,
    addedCount,
    removedCount,
    modifiedCount,
    materialChangeCount,
    changes,
  };
}

function buildSummary(
  sectionsCompared: number,
  sections: readonly SectionVersionDiff[],
): VersionChangeSummary {
  const sectionsChanged = sections.length;
  const materialSections = sections.filter(
    (section) => section.materialChangeCount > 0,
  ).length;
  const totalChanges = sections.reduce(
    (count, section) => count + section.changeCount,
    0,
  );
  const addedCount = sections.reduce(
    (count, section) => count + section.addedCount,
    0,
  );
  const removedCount = sections.reduce(
    (count, section) => count + section.removedCount,
    0,
  );
  const modifiedCount = sections.reduce(
    (count, section) => count + section.modifiedCount,
    0,
  );
  const materialChangeCount = sections.reduce(
    (count, section) => count + section.materialChangeCount,
    0,
  );

  return {
    sectionsCompared,
    sectionsChanged,
    materialSections,
    totalChanges,
    addedCount,
    removedCount,
    modifiedCount,
    materialChangeCount,
  };
}

export function createEmptyVersionComparison(input: {
  fromVersionId: string | null;
  toVersionId: string;
}): VersionComparisonResult {
  return {
    fromVersionId: input.fromVersionId,
    toVersionId: input.toVersionId,
    summary: {
      sectionsCompared: 0,
      sectionsChanged: 0,
      materialSections: 0,
      totalChanges: 0,
      addedCount: 0,
      removedCount: 0,
      modifiedCount: 0,
      materialChangeCount: 0,
    },
    sections: [],
  };
}

export function summarizeVersionChanges(input: {
  previousVersionId: string | null;
  nextVersionId: string;
  previousMeetings: readonly VersionMeetingSnapshot[];
  nextMeetings: readonly VersionMeetingSnapshot[];
}): VersionComparisonResult {
  const previousBySection = new Map<string, VersionMeetingSnapshot[]>();
  const nextBySection = new Map<string, VersionMeetingSnapshot[]>();

  for (const meeting of input.previousMeetings) {
    const values = previousBySection.get(meeting.sectionCode) ?? [];
    values.push(meeting);
    previousBySection.set(meeting.sectionCode, values);
  }

  for (const meeting of input.nextMeetings) {
    const values = nextBySection.get(meeting.sectionCode) ?? [];
    values.push(meeting);
    nextBySection.set(meeting.sectionCode, values);
  }

  const sectionCodes = [
    ...new Set([...previousBySection.keys(), ...nextBySection.keys()]),
  ].sort((left, right) => left.localeCompare(right));
  const sections: SectionVersionDiff[] = [];

  for (const sectionCode of sectionCodes) {
    const previousMeetings = previousBySection.get(sectionCode) ?? [];
    const nextMeetings = nextBySection.get(sectionCode) ?? [];
    const displayName =
      nextMeetings[0]?.sectionDisplayName ??
      previousMeetings[0]?.sectionDisplayName ??
      sectionCode;
    const sectionDiff = buildSectionDiff({
      sectionCode,
      displayName,
      previousMeetings,
      nextMeetings,
    });

    if (sectionDiff) {
      sections.push(sectionDiff);
    }
  }

  return {
    fromVersionId: input.previousVersionId,
    toVersionId: input.nextVersionId,
    summary: buildSummary(sectionCodes.length, sections),
    sections,
  };
}
