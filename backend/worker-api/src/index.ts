import { Hono } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";

import {
  D1DatabaseClient,
  type D1DatabaseLike,
} from "../../shared/src/timetable/db";
import {
  AppError,
  isAppError,
  type ErrorResponse,
} from "../../shared/src/timetable/errors";
import { TimetableQueryService } from "../../shared/src/timetable/services";

type Bindings = {
  APP_NAME?: string;
  API_ENV?: string;
  TIMETABLE_DB?: D1DatabaseLike;
};

type Variables = {
  requestId: string;
};

const READ_CACHE_CONTROL = "public, max-age=60, s-maxage=300";

function createStructuredErrorResponse(
  requestId: string,
  error: AppError,
): ErrorResponse {
  return {
    error: {
      code: error.code,
      message: error.message,
      requestId,
    },
  };
}

function getDatabase(context: { env?: Bindings }): D1DatabaseClient {
  const database = getBindings(context).TIMETABLE_DB;
  if (!database) {
    throw new AppError(
      "dependency_unavailable",
      "TIMETABLE_DB binding is not configured.",
    );
  }

  return new D1DatabaseClient(database);
}

function getBindings(context: { env?: Bindings }): Bindings {
  return context.env ?? {};
}

function setReadCacheHeaders(context: {
  header(name: string, value: string): void;
}): void {
  context.header("Cache-Control", READ_CACHE_CONTROL);
}

function logEvent(payload: Record<string, unknown>): void {
  console.log(JSON.stringify(payload));
}

export function createApp(): Hono<{
  Bindings: Bindings;
  Variables: Variables;
}> {
  const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

  app.use("*", async (context, next) => {
    const requestId = context.req.header("x-request-id") ?? crypto.randomUUID();
    const startedAt = Date.now();

    context.set("requestId", requestId);
    context.header("x-request-id", requestId);

    await next();

    const env = getBindings(context);

    logEvent({
      event: "request.completed",
      requestId,
      method: context.req.method,
      path: context.req.path,
      status: context.res.status,
      durationMs: Date.now() - startedAt,
      environment: env.API_ENV ?? "local",
      worker: env.APP_NAME ?? "timetable-worker-api",
    });
  });

  app.onError((error, context) => {
    const requestId = context.get("requestId");
    const appError = isAppError(error)
      ? error
      : new AppError("internal_error", "Internal server error.");

    logEvent({
      event: "request.failed",
      requestId,
      method: context.req.method,
      path: context.req.path,
      status: appError.status,
      code: appError.code,
      message: appError.message,
    });

    return context.json(
      createStructuredErrorResponse(requestId, appError),
      appError.status as ContentfulStatusCode,
    );
  });

  app.notFound((context) => {
    const requestId = context.get("requestId");
    return context.json(
      createStructuredErrorResponse(
        requestId,
        new AppError("not_found", "Route not found."),
      ),
      404,
    );
  });

  app.get("/", (context) =>
    context.json(
      (() => {
        const env = getBindings(context);
        return {
          service: env.APP_NAME ?? "timetable-worker-api",
          status: "ok",
          environment: env.API_ENV ?? "local",
        };
      })(),
    ),
  );

  app.get("/health", (context) =>
    context.json(
      (() => {
        const env = getBindings(context);
        return {
          service: env.APP_NAME ?? "timetable-worker-api",
          status: "ok",
          environment: env.API_ENV ?? "local",
        };
      })(),
    ),
  );

  app.get("/ready", async (context) => {
    const database = getDatabase(context);
    await database.queryFirst<{ ready: number }>("SELECT 1 AS ready");
    const env = getBindings(context);

    return context.json({
      service: env.APP_NAME ?? "timetable-worker-api",
      status: "ready",
      environment: env.API_ENV ?? "local",
    });
  });

  app.get("/v1/versions/current", async (context) => {
    const service = new TimetableQueryService(getDatabase(context));
    setReadCacheHeaders(context);
    return context.json(await service.getCurrentVersion());
  });

  app.get("/v1/versions", async (context) => {
    const service = new TimetableQueryService(getDatabase(context));
    setReadCacheHeaders(context);
    return context.json(await service.listVersions());
  });

  app.get("/v1/sections", async (context) => {
    const service = new TimetableQueryService(getDatabase(context));
    setReadCacheHeaders(context);
    return context.json(await service.listSections());
  });

  app.get("/v1/sections/:sectionCode", async (context) => {
    const service = new TimetableQueryService(getDatabase(context));
    setReadCacheHeaders(context);
    return context.json(
      await service.getSection(context.req.param("sectionCode")),
    );
  });

  app.get("/v1/sections/:sectionCode/timetable", async (context) => {
    const service = new TimetableQueryService(getDatabase(context));
    setReadCacheHeaders(context);
    return context.json(
      await service.getSectionTimetable(context.req.param("sectionCode")),
    );
  });

  return app;
}

export const app = createApp();

export default {
  fetch: app.fetch,
};
