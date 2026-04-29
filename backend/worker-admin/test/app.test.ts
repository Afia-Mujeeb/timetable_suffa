import { describe, expect, it } from "vitest";

import {
  createTestDatabase,
  applySharedMigrations,
} from "../../shared/src/timetable/testing";
import {
  createD1Bridge,
  loadGoldenArtifact,
} from "../../shared/src/timetable/test-helpers";
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

    const importResponse = await app.request(
      "http://localhost/v1/imports",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-import-secret": "test-secret",
          "x-correlation-id": "corr-import-1",
        },
        body: JSON.stringify(artifact),
      },
      env,
    );

    expect(importResponse.status).toBe(201);
    await expect(importResponse.json()).resolves.toMatchObject({
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

    const publishResponse = await app.request(
      "http://localhost/v1/versions/spring-2026-2026-04-26/publish",
      {
        method: "POST",
        headers: {
          "x-import-secret": "test-secret",
        },
      },
      env,
    );

    expect(publishResponse.status).toBe(200);
    await expect(publishResponse.json()).resolves.toMatchObject({
      version: {
        versionId: "spring-2026-2026-04-26",
        publishStatus: "published",
      },
    });
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
