import { Hono } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";

import {
  D1DatabaseClient,
  type D1DatabaseLike,
} from "../../shared/src/timetable/db";
import { AppError, isAppError } from "../../shared/src/timetable/errors";
import {
  TimetableImportService,
  TimetableQueryService,
} from "../../shared/src/timetable/services";

type Bindings = {
  APP_NAME?: string;
  ADMIN_ENV?: string;
  IMPORT_SHARED_SECRET?: string;
  TIMETABLE_DB?: D1DatabaseLike;
};

type Variables = {
  requestId: string;
};

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

function getRequestId(context: { get(key: "requestId"): string }): string {
  return context.get("requestId");
}

function logEvent(payload: Record<string, unknown>): void {
  console.log(JSON.stringify(payload));
}

function getPath(request: Request): string {
  return new URL(request.url).pathname;
}

async function readJsonBody(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    throw new AppError("validation_error", "Request body must be valid JSON.");
  }
}

function assertSharedSecret(context: {
  env?: Bindings;
  req: { header(name: string): string | undefined };
}): void {
  const requiredSecret = getBindings(context).IMPORT_SHARED_SECRET?.trim();
  if (!requiredSecret) {
    return;
  }

  const providedSecret = context.req.header("x-import-secret")?.trim();
  if (providedSecret !== requiredSecret) {
    throw new AppError(
      "validation_error",
      "x-import-secret header is missing or invalid.",
    );
  }
}

export function createApp(): Hono<{
  Bindings: Bindings;
  Variables: Variables;
}> {
  const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

  app.use("*", async (context, next) => {
    const requestId =
      context.req.header("x-correlation-id") ??
      context.req.header("x-request-id") ??
      crypto.randomUUID();
    const startedAt = Date.now();

    context.set("requestId", requestId);
    context.header("x-request-id", requestId);
    context.header("x-correlation-id", requestId);

    await next();

    const env = getBindings(context);

    logEvent({
      event: "request.completed",
      requestId,
      method: context.req.method,
      path: getPath(context.req.raw),
      status: context.res.status,
      durationMs: Date.now() - startedAt,
      environment: env.ADMIN_ENV ?? "local",
      worker: env.APP_NAME ?? "timetable-worker-admin",
    });
  });

  app.onError((error, context) => {
    const requestId = getRequestId(context);
    const appError = isAppError(error)
      ? error
      : new AppError("internal_error", "Internal server error.");

    logEvent({
      event: "request.failed",
      requestId,
      method: context.req.method,
      path: getPath(context.req.raw),
      status: appError.status,
      code: appError.code,
      message: appError.message,
    });

    return context.json(
      {
        error: {
          code: appError.code,
          message: appError.message,
          requestId,
        },
      },
      appError.status as ContentfulStatusCode,
    );
  });

  app.notFound((context) =>
    context.json(
      {
        error: {
          code: "not_found",
          message: "Route not found.",
          requestId: getRequestId(context),
        },
      },
      404,
    ),
  );

  app.get("/health", (context) =>
    context.json(
      (() => {
        const env = getBindings(context);
        return {
          requestId: getRequestId(context),
          service: env.APP_NAME ?? "timetable-worker-admin",
          status: "ok",
          environment: env.ADMIN_ENV ?? "local",
        };
      })(),
    ),
  );

  app.get("/ready", async (context) => {
    const database = getDatabase(context);
    await database.queryFirst<{ ready: number }>("SELECT 1 AS ready");
    const env = getBindings(context);

    return context.json({
      requestId: getRequestId(context),
      service: env.APP_NAME ?? "timetable-worker-admin",
      status: "ready",
      environment: env.ADMIN_ENV ?? "local",
    });
  });

  app.post("/v1/imports", async (context) => {
    assertSharedSecret(context);

    const service = new TimetableImportService(getDatabase(context));
    const result = await service.importArtifact(
      await readJsonBody(context.req.raw),
    );

    logEvent({
      event: "import.completed",
      requestId: getRequestId(context),
      versionId: result.timetableVersion.versionId,
      importedSections: result.importedSections,
      importedMeetings: result.importedMeetings,
      warningCount: result.warningCount,
    });

    return context.json(
      {
        requestId: getRequestId(context),
        import: {
          sectionsImported: result.importedSections,
          meetingsImported: result.importedMeetings,
          warningsCount: result.warningCount,
        },
        version: result.timetableVersion,
      },
      201,
    );
  });

  app.post("/v1/versions/:versionId/publish", async (context) => {
    assertSharedSecret(context);

    const versionId = context.req.param("versionId");
    const service = new TimetableImportService(getDatabase(context));
    const result = await service.publishVersion(versionId);

    logEvent({
      event: "publish.completed",
      requestId: getRequestId(context),
      versionId: result.timetableVersion.versionId,
      publishedAt: result.timetableVersion.publishedAt,
    });

    return context.json({
      requestId: getRequestId(context),
      version: result.timetableVersion,
    });
  });

  app.get("/imports/status", async (context) => {
    const database = getDatabase(context);
    const queryService = new TimetableQueryService(database);
    const versions = await queryService.listVersions();
    const currentVersion = await queryService
      .getCurrentVersion()
      .then((value) => value)
      .catch(() => null);
    const env = getBindings(context);

    return context.json({
      requestId: getRequestId(context),
      service: env.APP_NAME ?? "timetable-worker-admin",
      status: versions.versions.length === 0 ? "idle" : "ready",
      environment: env.ADMIN_ENV ?? "local",
      currentVersionId: currentVersion?.versionId ?? null,
      lastImportedVersionId: versions.versions[0]?.versionId ?? null,
      totalVersions: versions.versions.length,
      draftVersions: versions.versions.filter(
        (version) => version.publishStatus === "draft",
      ).length,
    });
  });

  return app;
}

export const app = createApp();

export default {
  fetch: app.fetch,
};
