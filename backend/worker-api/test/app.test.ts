import { describe, expect, it } from "vitest";

import { createRateLimitGuard } from "../../shared/src/timetable/rate-limit";
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

  it("rate limits burst traffic on public read endpoints", async () => {
    const { d1 } = await createSeededTestDatabase();
    const app = createApp({
      rateLimitGuard: createRateLimitGuard([
        {
          blockMs: 60_000,
          limit: 2,
          name: "api-burst",
          phase: "before",
          when: (request) => request.path.startsWith("/v1/"),
          windowMs: 60_000,
        },
        {
          blockMs: 60_000,
          limit: 10,
          name: "api-invalid-request",
          phase: "after",
          matchStatus: (status) => status === 400 || status === 404,
          when: (request) => request.path.startsWith("/v1/"),
          windowMs: 60_000,
        },
      ]),
    });

    expect(
      (
        await app.request(
          "http://localhost/v1/sections",
          undefined,
          createEnv(d1),
        )
      ).status,
    ).toBe(200);
    expect(
      (
        await app.request(
          "http://localhost/v1/sections",
          undefined,
          createEnv(d1),
        )
      ).status,
    ).toBe(200);

    const response = await app.request(
      "http://localhost/v1/sections",
      undefined,
      createEnv(d1),
    );

    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBeTruthy();
    await expect(response.json()).resolves.toMatchObject({
      error: {
        code: "rate_limited",
        details: {
          ruleName: "api-burst",
        },
      },
    });
  });

  it("rate limits repeated invalid requests and exposes backend metrics", async () => {
    const { d1 } = await createSeededTestDatabase();
    const app = createApp({
      rateLimitGuard: createRateLimitGuard([
        {
          blockMs: 60_000,
          limit: 20,
          name: "api-burst",
          phase: "before",
          when: (request) => request.path.startsWith("/v1/"),
          windowMs: 60_000,
        },
        {
          blockMs: 60_000,
          limit: 2,
          name: "api-invalid-request",
          phase: "after",
          matchStatus: (status) => status === 400 || status === 404,
          when: (request) => request.path.startsWith("/v1/"),
          windowMs: 60_000,
        },
      ]),
    });

    expect(
      (
        await app.request(
          "http://localhost/v1/sections/%24/timetable",
          undefined,
          createEnv(d1),
        )
      ).status,
    ).toBe(400);
    expect(
      (
        await app.request(
          "http://localhost/v1/sections/BS-CS-99Z/timetable",
          undefined,
          createEnv(d1),
        )
      ).status,
    ).toBe(404);

    const limitedResponse = await app.request(
      "http://localhost/v1/sections/%24/timetable",
      undefined,
      createEnv(d1),
    );

    expect(limitedResponse.status).toBe(429);
    await expect(limitedResponse.json()).resolves.toMatchObject({
      error: {
        code: "rate_limited",
        details: {
          ruleName: "api-invalid-request",
        },
      },
    });

    const metricsResponse = await app.request(
      "http://localhost/metrics",
      undefined,
      createEnv(d1),
    );
    expect(metricsResponse.status).toBe(200);
    await expect(metricsResponse.json()).resolves.toMatchObject({
      environment: "test",
      service: "timetable-worker-api",
      errors: {
        total: 4,
        byCode: {
          not_found: 1,
          rate_limited: 1,
          validation_error: 2,
        },
      },
      rateLimits: {
        total: 1,
        byRule: {
          "api-invalid-request": 1,
        },
      },
      requests: {
        total: 3,
        byStatus: {
          "400": 1,
          "404": 1,
          "429": 1,
        },
      },
    });
  });
});
