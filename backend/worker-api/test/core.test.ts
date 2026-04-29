import { describe, expect, it } from "vitest";

import { D1DatabaseClient } from "../../shared/src/timetable/db";
import {
  ClassMeetingRepository,
  SectionRepository,
  TimetableVersionRepository,
} from "../../shared/src/timetable/repositories";
import {
  TimetableImportService,
  TimetableQueryService,
} from "../../shared/src/timetable/services";
import {
  createSeededTestDatabase,
  loadGoldenArtifact,
} from "../../shared/src/timetable/test-helpers";
import {
  applySharedMigrations,
  createTestDatabase,
} from "../../shared/src/timetable/testing";

describe("shared timetable core", () => {
  it("applies the initial migration and creates core tables", async () => {
    const { client } = await createTestDatabase();

    await applySharedMigrations(client);

    const tables = await client.queryAll<{ name: string }>(
      `SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      ORDER BY name ASC`,
    );

    expect(tables.map((table) => table.name)).toEqual(
      expect.arrayContaining([
        "class_meetings",
        "courses",
        "instructors",
        "rooms",
        "sections",
        "timetable_versions",
      ]),
    );
  });

  it("imports the parser fixture into the normalized schema", async () => {
    const { client } = await createTestDatabase();
    await applySharedMigrations(client);
    const service = new TimetableImportService(client);

    const result = await service.importArtifact(loadGoldenArtifact());

    expect(result).toMatchObject({
      importedSections: 25,
      importedMeetings: 162,
      warningCount: 1,
      timetableVersion: {
        versionId: "spring-2026-2026-04-26",
        publishStatus: "draft",
      },
    });

    const versions = new TimetableVersionRepository(client);
    const version = await versions.getById("spring-2026-2026-04-26");
    expect(version).not.toBeNull();
    expect(version?.meetingCount).toBe(162);
  });

  it("returns meetings for a section from the repository hot path query", async () => {
    const { client } = await createTestDatabase();
    await applySharedMigrations(client);
    const importService = new TimetableImportService(client);
    const artifact = loadGoldenArtifact();
    await importService.importArtifact(artifact);
    await importService.publishVersion(artifact.source.version_id);

    const sections = new SectionRepository(client);
    const section = await sections.getActiveByNormalizedCode(
      artifact.source.version_id,
      "BS-CS-2A",
    );
    expect(section).not.toBeNull();

    if (!section) {
      throw new Error("Expected BS-CS-2A section to exist after publish.");
    }

    const meetings = await new ClassMeetingRepository(client).listBySection(
      artifact.source.version_id,
      section.id,
    );

    expect(meetings).toHaveLength(8);
    expect(meetings[0]).toMatchObject({
      sectionCode: "BS-CS-2A",
      dayKey: "monday",
      startTime: "08:30",
      meetingType: "lecture",
    });
  });

  it("assembles the section timetable response from the service layer", async () => {
    const { d1 } = await createSeededTestDatabase();

    const queryService = new TimetableQueryService(new D1DatabaseClient(d1));

    const timetable = await queryService.getSectionTimetable("BS-CS-2A");

    expect(timetable.section).toMatchObject({
      sectionCode: "BS-CS-2A",
      active: true,
      meetingCount: 8,
    });
    expect(timetable.timetableVersion).toMatchObject({
      versionId: "spring-2026-2026-04-26",
      publishStatus: "published",
    });
    expect(timetable.meetings[0]).toMatchObject({
      courseName: "Object Oriented Programming",
      dayKey: "monday",
      startTime: "08:30",
    });
  });
});
