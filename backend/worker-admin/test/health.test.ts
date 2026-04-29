import { describe, expect, it } from "vitest";

import { app } from "../src/index";

describe("worker-admin", () => {
  it("returns the import status placeholder", async () => {
    const response = await app.request("http://localhost/imports/status");

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      service: "timetable-worker-admin",
      status: "idle",
      environment: "local",
    });
  });
});
