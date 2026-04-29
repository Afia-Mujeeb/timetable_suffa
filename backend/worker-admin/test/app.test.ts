import { describe, expect, it } from "vitest";

import {
  createTestDatabase,
  applySharedMigrations,
} from "../../shared/src/timetable/testing";
import {
  createD1Bridge,
  loadGoldenArtifact,
} from "../../shared/src/timetable/test-helpers";
import type {
  ParserArtifact,
  ParserMeeting,
} from "../../shared/src/timetable/types";
import { createApp } from "../src/index";

async function createAdminEnv() {
  const { client, database } = await createTestDatabase();
  await applySharedMigrations(client);

  return {
    APP_NAME: "timetable-worker-admin",
    ADMIN_ENV: "test",
    IMPORT_SHARED_SECRET: "test-secret",
    TIMETABLE_DB: createD1Bridge(database),
  };
}

type AdminEnv = Awaited<ReturnType<typeof createAdminEnv>>;

async function requestImport(
  app: ReturnType<typeof createApp>,
  env: AdminEnv,
  artifact: ParserArtifact,
  correlationId = `corr-import-${artifact.source.version_id}`,
) {
  return app.request(
    "http://localhost/v1/imports",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-import-secret": "test-secret",
        "x-correlation-id": correlationId,
      },
      body: JSON.stringify(artifact),
    },
    env,
  );
}

async function requestPublish(
  app: ReturnType<typeof createApp>,
  env: AdminEnv,
  versionId: string,
) {
  return app.request(
    `http://localhost/v1/versions/${versionId}/publish`,
    {
      method: "POST",
      headers: {
        "x-import-secret": "test-secret",
      },
    },
    env,
  );
}

function createTestMeeting(
  overrides: Partial<ParserMeeting> &
    Pick<ParserMeeting, "section" | "course_name">,
): ParserMeeting {
  return {
    section: overrides.section,
    course_name: overrides.course_name,
    instructor: overrides.instructor ?? "Prof. Ada",
    room: overrides.room ?? "Room 101",
    day: overrides.day ?? "Monday",
    day_key: overrides.day_key ?? "monday",
    online: overrides.online ?? false,
    meeting_type: overrides.meeting_type ?? "lecture",
    slot_start: overrides.slot_start ?? 1,
    slot_end: overrides.slot_end ?? 2,
    start_time: overrides.start_time ?? "08:30",
    end_time: overrides.end_time ?? "09:20",
    source_page: overrides.source_page ?? 1,
    source_version: overrides.source_version ?? "test-version",
    confidence_class: overrides.confidence_class ?? "high",
    confidence_score: overrides.confidence_score ?? 0.99,
    warnings: overrides.warnings ?? [],
  };
}

function createArtifact(
  versionId: string,
  meetings: ParserMeeting[],
): ParserArtifact {
  const normalizedMeetings = meetings.map((meeting) => ({
    ...meeting,
    source_version: versionId,
  }));
  const sections = [
    ...new Set(normalizedMeetings.map((meeting) => meeting.section)),
  ].sort((left, right) => left.localeCompare(right));

  return {
    source: {
      version_id: versionId,
      source_file_name: `${versionId}.json`,
      generated_date: "2026-04-29",
      page_count: 1,
      sections,
    },
    normalized_domain: {
      sections,
      meetings: normalizedMeetings,
    },
    validation: {
      status: "passed",
      errors: [],
      warnings: [],
    },
  };
}

describe("worker-admin", () => {
  it("returns a health payload", async () => {
    const app = createApp();
    const response = await app.request("http://localhost/health");

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      service: "timetable-worker-admin",
      status: "ok",
      environment: "local",
    });
  });

  it("imports a parser artifact and publishes it", async () => {
    const app = createApp();
    const env = await createAdminEnv();
    const artifact = loadGoldenArtifact();

    const importResponse = await requestImport(
      app,
      env,
      artifact,
      "corr-import-1",
    );

    expect(importResponse.status).toBe(201);
    expect(await importResponse.json()).toMatchObject({
      requestId: "corr-import-1",
      import: {
        sectionsImported: 25,
        meetingsImported: 162,
        warningsCount: 1,
      },
      version: {
        versionId: "spring-2026-2026-04-26",
        publishStatus: "draft",
      },
    });

    const publishResponse = await requestPublish(
      app,
      env,
      "spring-2026-2026-04-26",
    );

    expect(publishResponse.status).toBe(200);
    const publishBody = (await publishResponse.json()) as {
      previousVersion: unknown;
      changes: {
        fromVersionId: string | null;
        summary: {
          sectionsCompared: number;
          sectionsChanged: number;
          materialSections: number;
          totalChanges: number;
          addedCount: number;
          removedCount: number;
          modifiedCount: number;
          materialChangeCount: number;
        };
        sections: Array<{
          sectionCode: string;
          changeCount: number;
          addedCount: number;
          removedCount: number;
          modifiedCount: number;
        }>;
      };
    };

    expect(publishBody).toMatchObject({
      version: {
        versionId: "spring-2026-2026-04-26",
        publishStatus: "published",
      },
      previousVersion: null,
      changes: {
        fromVersionId: null,
        toVersionId: "spring-2026-2026-04-26",
        summary: {
          sectionsCompared: 25,
          sectionsChanged: 25,
          materialSections: 25,
          totalChanges: 162,
          addedCount: 162,
          removedCount: 0,
          modifiedCount: 0,
          materialChangeCount: 162,
        },
      },
    });
    expect(publishBody.changes.sections).toHaveLength(25);
    expect(publishBody.changes.sections).toContainEqual(
      expect.objectContaining({
        sectionCode: "BS-CS-2A",
        changeCount: 8,
        addedCount: 8,
        removedCount: 0,
        modifiedCount: 0,
      }),
    );
  });

  it("summarizes meaningful meeting changes across published versions", async () => {
    const app = createApp();
    const env = await createAdminEnv();
    const initialArtifact = createArtifact("spring-2026-v1", [
      createTestMeeting({
        section: "SEC-A",
        course_name: "Algorithms",
      }),
      createTestMeeting({
        section: "SEC-B",
        course_name: "Databases",
        day: "Tuesday",
        day_key: "tuesday",
        start_time: "09:30",
        end_time: "10:20",
        slot_start: 3,
        slot_end: 4,
        room: "Room 202",
      }),
    ]);
    const nextArtifact = createArtifact("spring-2026-v2", [
      createTestMeeting({
        section: "SEC-B",
        course_name: "Databases",
        day: "Tuesday",
        day_key: "tuesday",
        start_time: "10:30",
        end_time: "11:20",
        slot_start: 5,
        slot_end: 6,
        room: null,
        online: true,
        instructor: "Prof. Grace",
      }),
      createTestMeeting({
        section: "SEC-C",
        course_name: "Networks",
        day: "Wednesday",
        day_key: "wednesday",
        start_time: "11:30",
        end_time: "12:20",
        slot_start: 7,
        slot_end: 8,
        meeting_type: "lab",
        room: "Lab 1",
        instructor: "Prof. Grace",
      }),
    ]);

    expect((await requestImport(app, env, initialArtifact)).status).toBe(201);
    expect(
      (await requestPublish(app, env, initialArtifact.source.version_id))
        .status,
    ).toBe(200);
    expect((await requestImport(app, env, nextArtifact)).status).toBe(201);

    const publishResponse = await requestPublish(
      app,
      env,
      nextArtifact.source.version_id,
    );

    expect(publishResponse.status).toBe(200);
    const publishBody = (await publishResponse.json()) as {
      changes: {
        summary: {
          sectionsCompared: number;
          sectionsChanged: number;
          totalChanges: number;
          addedCount: number;
          removedCount: number;
          modifiedCount: number;
        };
        sections: Array<{
          sectionCode: string;
          addedCount: number;
          removedCount: number;
          modifiedCount: number;
          changes: Array<{
            changeKinds: string[];
            message: string;
          }>;
        }>;
      };
    };

    expect(publishBody).toMatchObject({
      version: {
        versionId: "spring-2026-v2",
        publishStatus: "published",
      },
      previousVersion: {
        versionId: "spring-2026-v1",
      },
      changes: {
        fromVersionId: "spring-2026-v1",
        toVersionId: "spring-2026-v2",
        summary: {
          sectionsCompared: 3,
          sectionsChanged: 3,
          materialSections: 3,
          totalChanges: 3,
          addedCount: 1,
          removedCount: 1,
          modifiedCount: 1,
          materialChangeCount: 3,
        },
        sections: [
          {
            sectionCode: "SEC-A",
            addedCount: 0,
            removedCount: 1,
            modifiedCount: 0,
          },
          {
            sectionCode: "SEC-B",
            addedCount: 0,
            removedCount: 0,
            modifiedCount: 1,
          },
          {
            sectionCode: "SEC-C",
            addedCount: 1,
            removedCount: 0,
            modifiedCount: 0,
          },
        ],
      },
    });

    const updatedSection = publishBody.changes.sections.find(
      (section) => section.sectionCode === "SEC-B",
    );
    expect(updatedSection?.changes).toHaveLength(1);
    expect(updatedSection?.changes[0]?.changeKinds).toEqual([
      "time_changed",
      "online_changed",
      "room_changed",
      "instructor_changed",
    ]);
    expect(updatedSection?.changes[0]?.message).toContain("moved");
  });

  it("rejects admin writes when the import secret is wrong", async () => {
    const app = createApp();
    const env = await createAdminEnv();
    const response = await app.request(
      "http://localhost/v1/imports",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-import-secret": "wrong-secret",
        },
        body: JSON.stringify({}),
      },
      env,
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({
      error: {
        code: "validation_error",
      },
    });
  });
});
