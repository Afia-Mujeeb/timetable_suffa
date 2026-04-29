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

function createAuthorizedHeaders(extra: Record<string, string> = {}) {
  return {
    "x-import-secret": "test-secret",
    ...extra,
  };
}

async function requestImport(
  app: ReturnType<typeof createApp>,
  env: AdminEnv,
  artifact: ParserArtifact,
  overrides: {
    triggeredBy?: string;
    parserVersion?: string;
    sourceId?: string;
    note?: string | null;
    correlationId?: string;
  } = {},
) {
  return app.request(
    "http://localhost/v1/imports",
    {
      method: "POST",
      headers: createAuthorizedHeaders({
        "content-type": "application/json",
        "x-correlation-id":
          overrides.correlationId ?? `corr-import-${artifact.source.version_id}`,
      }),
      body: JSON.stringify({
        artifact,
        sourceId: overrides.sourceId ?? `artifact:${artifact.source.version_id}`,
        parserVersion: overrides.parserVersion ?? "parser-test-1",
        triggeredBy: overrides.triggeredBy ?? "test-operator",
        note: overrides.note ?? null,
      }),
    },
    env,
  );
}

async function requestPublish(
  app: ReturnType<typeof createApp>,
  env: AdminEnv,
  versionId: string,
  body: Record<string, unknown> | null = null,
) {
  return app.request(
    `http://localhost/v1/versions/${versionId}/publish`,
    {
      method: "POST",
      headers: createAuthorizedHeaders(
        body === null ? {} : { "content-type": "application/json" },
      ),
      body: body === null ? null : JSON.stringify(body),
    },
    env,
  );
}

async function requestRollback(
  app: ReturnType<typeof createApp>,
  env: AdminEnv,
  versionId: string,
  body: Record<string, unknown> | null = null,
) {
  return app.request(
    `http://localhost/v1/versions/${versionId}/rollback`,
    {
      method: "POST",
      headers: createAuthorizedHeaders(
        body === null ? {} : { "content-type": "application/json" },
      ),
      body: body === null ? null : JSON.stringify(body),
    },
    env,
  );
}

async function requestPreview(
  app: ReturnType<typeof createApp>,
  env: AdminEnv,
  versionId: string,
) {
  return app.request(
    `http://localhost/v1/versions/${versionId}/preview`,
    {
      headers: createAuthorizedHeaders(),
    },
    env,
  );
}

async function requestVersions(app: ReturnType<typeof createApp>, env: AdminEnv) {
  return app.request(
    "http://localhost/v1/versions",
    {
      headers: createAuthorizedHeaders(),
    },
    env,
  );
}

async function requestImportRuns(
  app: ReturnType<typeof createApp>,
  env: AdminEnv,
) {
  return app.request(
    "http://localhost/v1/import-runs",
    {
      headers: createAuthorizedHeaders(),
    },
    env,
  );
}

async function requestAuditEvents(
  app: ReturnType<typeof createApp>,
  env: AdminEnv,
) {
  return app.request(
    "http://localhost/v1/audit-events",
    {
      headers: createAuthorizedHeaders(),
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

  it("imports, previews, publishes with warning acknowledgement, and exposes audit history", async () => {
    const app = createApp();
    const env = await createAdminEnv();
    const artifact = loadGoldenArtifact();

    const importResponse = await requestImport(app, env, artifact, {
      note: "daily import",
      correlationId: "corr-import-1",
    });

    expect(importResponse.status).toBe(201);
    expect(await importResponse.json()).toMatchObject({
      requestId: "corr-import-1",
      import: {
        sectionsImported: 25,
        meetingsImported: 162,
        warningsCount: 1,
      },
      importRun: {
        versionId: "spring-2026-2026-04-26",
        status: "succeeded",
        parserVersion: "parser-test-1",
        triggeredBy: "test-operator",
        warningCount: 1,
      },
      version: {
        versionId: "spring-2026-2026-04-26",
        publishStatus: "draft",
      },
    });

    const previewResponse = await requestPreview(
      app,
      env,
      "spring-2026-2026-04-26",
    );

    expect(previewResponse.status).toBe(200);
    await expect(previewResponse.json()).resolves.toMatchObject({
      version: {
        versionId: "spring-2026-2026-04-26",
        publishStatus: "draft",
        warningCount: 1,
      },
      currentVersion: null,
      importRun: {
        status: "succeeded",
      },
      publishable: true,
      warnings: [
        "normalized_domain/meetings/160: missing room on non-online meeting",
      ],
      changes: {
        fromVersionId: null,
        toVersionId: "spring-2026-2026-04-26",
        summary: {
          sectionsCompared: 25,
          sectionsChanged: 25,
          totalChanges: 162,
        },
      },
      pushPreview: {
        wouldNotify: false,
        reason: "first_publish",
      },
    });

    const rejectedPublishResponse = await requestPublish(
      app,
      env,
      "spring-2026-2026-04-26",
    );

    expect(rejectedPublishResponse.status).toBe(400);
    await expect(rejectedPublishResponse.json()).resolves.toMatchObject({
      error: {
        code: "validation_error",
      },
    });

    const publishResponse = await requestPublish(
      app,
      env,
      "spring-2026-2026-04-26",
      {
        triggeredBy: "release-bot",
        note: "ship the weekly timetable",
        ignoreWarnings: true,
      },
    );

    expect(publishResponse.status).toBe(200);
    await expect(publishResponse.json()).resolves.toMatchObject({
      version: {
        versionId: "spring-2026-2026-04-26",
        publishStatus: "published",
      },
      previousVersion: null,
      pushPreview: {
        wouldNotify: false,
        reason: "first_publish",
      },
      auditEvent: {
        eventKind: "published",
        versionId: "spring-2026-2026-04-26",
        previousVersionId: null,
        triggeredBy: "release-bot",
        warningsIgnored: true,
      },
    });

    const versionsResponse = await requestVersions(app, env);
    expect(versionsResponse.status).toBe(200);
    await expect(versionsResponse.json()).resolves.toMatchObject({
      versions: [
        expect.objectContaining({
          versionId: "spring-2026-2026-04-26",
          publishStatus: "published",
        }),
      ],
    });

    const importRunsResponse = await requestImportRuns(app, env);
    expect(importRunsResponse.status).toBe(200);
    await expect(importRunsResponse.json()).resolves.toMatchObject({
      importRuns: [
        expect.objectContaining({
          versionId: "spring-2026-2026-04-26",
          status: "succeeded",
        }),
      ],
    });

    const auditEventsResponse = await requestAuditEvents(app, env);
    expect(auditEventsResponse.status).toBe(200);
    await expect(auditEventsResponse.json()).resolves.toMatchObject({
      auditEvents: [
        expect.objectContaining({
          eventKind: "published",
          versionId: "spring-2026-2026-04-26",
        }),
        expect.objectContaining({
          eventKind: "import_succeeded",
          versionId: "spring-2026-2026-04-26",
        }),
      ],
    });
  });

  it("summarizes meaningful meeting changes in preview and publish responses", async () => {
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
      (
        await requestPublish(app, env, initialArtifact.source.version_id, {
          triggeredBy: "test-operator",
          ignoreWarnings: false,
        })
      ).status,
    ).toBe(200);
    expect((await requestImport(app, env, nextArtifact)).status).toBe(201);

    const previewResponse = await requestPreview(
      app,
      env,
      nextArtifact.source.version_id,
    );

    expect(previewResponse.status).toBe(200);
    const previewBody = (await previewResponse.json()) as {
      pushPreview: {
        wouldNotify: boolean;
        reason: string;
        sections: Array<{
          sectionCode: string;
          messages: string[];
        }>;
      };
      changes: {
        summary: {
          sectionsCompared: number;
          sectionsChanged: number;
          totalChanges: number;
          addedCount: number;
          removedCount: number;
          modifiedCount: number;
        };
      };
    };

    expect(previewBody.changes.summary).toMatchObject({
      sectionsCompared: 3,
      sectionsChanged: 3,
      totalChanges: 3,
      addedCount: 1,
      removedCount: 1,
      modifiedCount: 1,
    });
    expect(previewBody.pushPreview).toMatchObject({
      wouldNotify: true,
      reason: "sections_changed",
    });
    expect(previewBody.pushPreview.sections).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          sectionCode: "SEC-B",
        }),
        expect.objectContaining({
          sectionCode: "SEC-C",
        }),
      ]),
    );

    const publishResponse = await requestPublish(
      app,
      env,
      nextArtifact.source.version_id,
      {
        triggeredBy: "release-bot",
        note: "publish revision 2",
      },
    );

    expect(publishResponse.status).toBe(200);
    const publishBody = (await publishResponse.json()) as {
      previousVersion: {
        versionId: string;
      } | null;
      changes: {
        sections: Array<{
          sectionCode: string;
          changes: Array<{
            changeKinds: string[];
            message: string;
          }>;
        }>;
      };
      pushPreview: {
        wouldNotify: boolean;
        sections: Array<{
          sectionCode: string;
        }>;
      };
    };

    expect(publishBody.previousVersion).toMatchObject({
      versionId: "spring-2026-v1",
    });
    expect(publishBody.pushPreview).toMatchObject({
      wouldNotify: true,
    });
    expect(publishBody.pushPreview.sections).toHaveLength(3);

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

  it("rolls back to an archived version and records the rollback audit event", async () => {
    const app = createApp();
    const env = await createAdminEnv();
    const v1 = createArtifact("spring-2026-v1", [
      createTestMeeting({
        section: "SEC-A",
        course_name: "Algorithms",
      }),
    ]);
    const v2 = createArtifact("spring-2026-v2", [
      createTestMeeting({
        section: "SEC-A",
        course_name: "Algorithms",
        day: "Tuesday",
        day_key: "tuesday",
      }),
    ]);

    expect((await requestImport(app, env, v1)).status).toBe(201);
    expect(
      (
        await requestPublish(app, env, v1.source.version_id, {
          triggeredBy: "release-bot",
        })
      ).status,
    ).toBe(200);
    expect((await requestImport(app, env, v2)).status).toBe(201);
    expect(
      (
        await requestPublish(app, env, v2.source.version_id, {
          triggeredBy: "release-bot",
        })
      ).status,
    ).toBe(200);

    const rollbackResponse = await requestRollback(app, env, v1.source.version_id, {
      triggeredBy: "release-bot",
      note: "rollback bad publish",
    });

    expect(rollbackResponse.status).toBe(200);
    await expect(rollbackResponse.json()).resolves.toMatchObject({
      version: {
        versionId: "spring-2026-v1",
        publishStatus: "published",
      },
      previousVersion: {
        versionId: "spring-2026-v2",
      },
      auditEvent: {
        eventKind: "rolled_back",
        versionId: "spring-2026-v1",
        previousVersionId: "spring-2026-v2",
        triggeredBy: "release-bot",
      },
      pushPreview: {
        wouldNotify: true,
        reason: "sections_changed",
      },
    });

    const previewResponse = await requestPreview(app, env, v1.source.version_id);
    expect(previewResponse.status).toBe(200);
    await expect(previewResponse.json()).resolves.toMatchObject({
      version: {
        versionId: "spring-2026-v1",
        publishStatus: "published",
      },
      currentVersion: {
        versionId: "spring-2026-v1",
      },
    });

    const auditEventsResponse = await requestAuditEvents(app, env);
    expect(auditEventsResponse.status).toBe(200);
    const auditEventsBody = (await auditEventsResponse.json()) as {
      auditEvents: Array<{
        eventKind: string;
        versionId: string | null;
      }>;
    };
    expect(auditEventsBody.auditEvents).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          eventKind: "rolled_back",
          versionId: "spring-2026-v1",
        }),
      ]),
    );
  });

  it("records failed imports in import runs and audit events", async () => {
    const app = createApp();
    const env = await createAdminEnv();
    const response = await app.request(
      "http://localhost/v1/imports",
      {
        method: "POST",
        headers: createAuthorizedHeaders({
          "content-type": "application/json",
        }),
        body: JSON.stringify({
          artifact: {},
          sourceId: "artifact:broken",
          parserVersion: "parser-test-1",
          triggeredBy: "test-operator",
        }),
      },
      env,
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({
      error: {
        code: "validation_error",
      },
    });

    const importRunsResponse = await requestImportRuns(app, env);
    expect(importRunsResponse.status).toBe(200);
    await expect(importRunsResponse.json()).resolves.toMatchObject({
      importRuns: [
        expect.objectContaining({
          versionId: null,
          sourceId: "artifact:broken",
          status: "failed",
        }),
      ],
    });

    const auditEventsResponse = await requestAuditEvents(app, env);
    expect(auditEventsResponse.status).toBe(200);
    const auditBody = (await auditEventsResponse.json()) as {
      auditEvents: Array<{
        eventKind: string;
        note: string | null;
      }>;
    };
    expect(auditBody.auditEvents[0]).toMatchObject({
      eventKind: "import_failed",
    });
    expect(auditBody.auditEvents[0]?.note).toContain("Import payload is invalid");
  });

  it("rejects admin reads and writes when the import secret is wrong", async () => {
    const app = createApp();
    const env = await createAdminEnv();

    const writeResponse = await app.request(
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
    expect(writeResponse.status).toBe(400);

    const readResponse = await app.request(
      "http://localhost/v1/versions",
      {
        headers: {
          "x-import-secret": "wrong-secret",
        },
      },
      env,
    );
    expect(readResponse.status).toBe(400);
  });
});
