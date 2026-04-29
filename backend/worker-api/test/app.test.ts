import { describe, expect, it } from "vitest";

import { createSeededTestDatabase } from "../../shared/src/timetable/test-helpers";
import { createApp } from "../src/index";

function createEnv(
  database: Awaited<ReturnType<typeof createSeededTestDatabase>>["d1"],
) {
  return {
    APP_NAME: "timetable-worker-api",
    API_ENV: "test",
    TIMETABLE_DB: database,
  };
}

describe("worker-api", () => {
  it("returns a health payload", async () => {
    const app = createApp();
    const response = await app.request("http://localhost/health");

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      service: "timetable-worker-api",
      status: "ok",
      environment: "local",
    });
  });

  it("returns readiness when the database binding is available", async () => {
    const { d1 } = await createSeededTestDatabase();
    const app = createApp();
    const response = await app.request(
      "http://localhost/ready",
      undefined,
      createEnv(d1),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      service: "timetable-worker-api",
      status: "ready",
      environment: "test",
    });
  });

  it("lists active sections for the current published version", async () => {
    const { d1 } = await createSeededTestDatabase();
    const app = createApp();
    const response = await app.request(
      "http://localhost/v1/sections",
      undefined,
      createEnv(d1),
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe(
      "public, max-age=60, s-maxage=300",
    );

    const body = (await response.json()) as {
      timetableVersion: {
        versionId: string;
        publishStatus: string;
      };
      sections: Array<{
        sectionCode: string;
        active: boolean;
      }>;
    };

    expect(body.timetableVersion).toMatchObject({
      versionId: "spring-2026-2026-04-26",
      publishStatus: "published",
    });
    expect(
      body.sections.some(
        (section) => section.sectionCode === "BS-CS-2A" && section.active,
      ),
    ).toBe(true);
  });

  it("returns a section timetable with meetings ordered by day and slot", async () => {
    const { d1 } = await createSeededTestDatabase();
    const app = createApp();
    const response = await app.request(
      "http://localhost/v1/sections/BS-CS-2A/timetable",
      undefined,
      createEnv(d1),
    );

    expect(response.status).toBe(200);

    const bodyJson = (await response.json()) as unknown;
    const body = bodyJson as {
      meetings: Array<{
        dayKey: string;
        startTime: string;
        courseName: string;
      }>;
      section: { sectionCode: string };
    };

    expect(body.section.sectionCode).toBe("BS-CS-2A");
    expect(body.meetings[0]).toMatchObject({
      dayKey: "monday",
      startTime: "08:30",
      courseName: "Object Oriented Programming",
    });
  });

  it("returns a structured 404 for unknown sections", async () => {
    const { d1 } = await createSeededTestDatabase();
    const app = createApp();
    const response = await app.request(
      "http://localhost/v1/sections/BS-CS-99Z/timetable",
      undefined,
      createEnv(d1),
    );

    expect(response.status).toBe(404);
    await expect(response.json()).resolves.toMatchObject({
      error: {
        code: "not_found",
      },
    });
  });

  it("returns a structured validation error for malformed section codes", async () => {
    const { d1 } = await createSeededTestDatabase();
    const app = createApp();
    const response = await app.request(
      "http://localhost/v1/sections/%24/timetable",
      undefined,
      createEnv(d1),
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({
      error: {
        code: "validation_error",
      },
    });
  });
});
