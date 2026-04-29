import { describe, expect, it } from "vitest";

import { app } from "../src/index";

describe("worker-api", () => {
  it("returns a health payload", async () => {
    const response = await app.request("http://localhost/health");

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      service: "timetable-worker-api",
      status: "ok",
      environment: "local",
    });
  });
});
