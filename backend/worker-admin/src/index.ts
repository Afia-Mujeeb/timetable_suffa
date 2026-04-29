import { Hono } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";

import {
  D1DatabaseClient,
  type D1DatabaseLike,
} from "../../shared/src/timetable/db";
import { AppError, isAppError } from "../../shared/src/timetable/errors";
import {
  TimetableAdminQueryService,
  TimetableImportService,
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

type ImportBody = {
  artifact: unknown;
  sourceId: string | null;
  parserVersion: string | null;
  triggeredBy: string | null;
  note: string | null;
};

type VersionActionBody = {
  triggeredBy: string | null;
  note: string | null;
  ignoreWarnings: boolean;
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

async function readOptionalJsonBody(request: Request): Promise<unknown> {
  const contentLength = request.headers.get("content-length");
  if (contentLength === "0") {
    return null;
  }

  const contentType = request.headers.get("content-type");
  if (!contentType?.toLowerCase().includes("application/json")) {
    return null;
  }

  return readJsonBody(request);
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

function normalizeOptionalString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function resolveTriggeredBy(
  context: { req: { header(name: string): string | undefined } },
  bodyTriggeredBy: string | null,
): string {
  return (
    bodyTriggeredBy ??
    normalizeOptionalString(context.req.header("x-operator-id")) ??
    "unknown"
  );
}

function parseImportBody(
  body: unknown,
  context: { req: { header(name: string): string | undefined } },
): ImportBody {
  if (typeof body !== "object" || body === null) {
    return {
      artifact: body,
      sourceId: null,
      parserVersion: null,
      triggeredBy: resolveTriggeredBy(context, null),
      note: null,
    };
  }

  const candidate = body as {
    artifact?: unknown;
    sourceId?: unknown;
    parserVersion?: unknown;
    triggeredBy?: unknown;
    note?: unknown;
  };

  const bodyTriggeredBy = normalizeOptionalString(candidate.triggeredBy);

  return {
    artifact:
      Object.prototype.hasOwnProperty.call(candidate, "artifact")
        ? candidate.artifact
        : body,
    sourceId: normalizeOptionalString(candidate.sourceId),
    parserVersion: normalizeOptionalString(candidate.parserVersion),
    triggeredBy: resolveTriggeredBy(context, bodyTriggeredBy),
    note: normalizeOptionalString(candidate.note),
  };
}

function parseVersionActionBody(
  body: unknown,
  context: { req: { header(name: string): string | undefined } },
): VersionActionBody {
  if (body === null) {
    return {
      triggeredBy: resolveTriggeredBy(context, null),
      note: null,
      ignoreWarnings: false,
    };
  }

  if (typeof body !== "object") {
    throw new AppError("validation_error", "Request body must be a JSON object.");
  }

  const candidate = body as {
    triggeredBy?: unknown;
    note?: unknown;
    ignoreWarnings?: unknown;
  };
  const bodyTriggeredBy = normalizeOptionalString(candidate.triggeredBy);

  return {
    triggeredBy: resolveTriggeredBy(context, bodyTriggeredBy),
    note: normalizeOptionalString(candidate.note),
    ignoreWarnings: candidate.ignoreWarnings === true,
  };
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

  app.use("/v1/*", async (context, next) => {
    assertSharedSecret(context);
    await next();
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
    const service = new TimetableImportService(getDatabase(context));
    const result = await service.importArtifact(
      parseImportBody(await readJsonBody(context.req.raw), context),
    );

    logEvent({
      event: "import.completed",
      requestId: getRequestId(context),
      importRunId: result.importRun.importRunId,
      versionId: result.timetableVersion.versionId,
      importedSections: result.importedSections,
      importedMeetings: result.importedMeetings,
      warningCount: result.warningCount,
      triggeredBy: result.importRun.triggeredBy,
    });

    return context.json(
      {
        requestId: getRequestId(context),
        import: {
          sectionsImported: result.importedSections,
          meetingsImported: result.importedMeetings,
          warningsCount: result.warningCount,
        },
        importRun: result.importRun,
        version: result.timetableVersion,
      },
      201,
    );
  });

  app.get("/v1/versions", async (context) => {
    const service = new TimetableAdminQueryService(getDatabase(context));
    return context.json({
      requestId: getRequestId(context),
      ...(await service.listVersions()),
    });
  });

  app.get("/v1/versions/:versionId/preview", async (context) => {
    const service = new TimetableAdminQueryService(getDatabase(context));
    return context.json({
      requestId: getRequestId(context),
      ...(await service.getVersionPreview(context.req.param("versionId"))),
    });
  });

  app.post("/v1/versions/:versionId/publish", async (context) => {
    const service = new TimetableImportService(getDatabase(context));
    const payload = parseVersionActionBody(
      await readOptionalJsonBody(context.req.raw),
      context,
    );
    const result = await service.publishVersion({
      versionId: context.req.param("versionId"),
      triggeredBy: payload.triggeredBy,
      note: payload.note,
      ignoreWarnings: payload.ignoreWarnings,
    });

    logEvent({
      event: "publish.completed",
      requestId: getRequestId(context),
      versionId: result.timetableVersion.versionId,
      publishedAt: result.timetableVersion.publishedAt,
      previousVersionId: result.previousVersion?.versionId ?? null,
      changedSectionCount: result.changes.summary.sectionsChanged,
      totalChangeCount: result.changes.summary.totalChanges,
      wouldNotify: result.pushPreview.wouldNotify,
      pushSections: result.pushPreview.sections.length,
      auditEventId: result.auditEvent.auditEventId,
      triggeredBy: result.auditEvent.triggeredBy,
    });

    return context.json({
      requestId: getRequestId(context),
      version: result.timetableVersion,
      previousVersion: result.previousVersion,
      changes: result.changes,
      pushPreview: result.pushPreview,
      auditEvent: result.auditEvent,
    });
  });

  app.post("/v1/versions/:versionId/rollback", async (context) => {
    const service = new TimetableImportService(getDatabase(context));
    const payload = parseVersionActionBody(
      await readOptionalJsonBody(context.req.raw),
      context,
    );
    const result = await service.rollbackVersion({
      versionId: context.req.param("versionId"),
      triggeredBy: payload.triggeredBy,
      note: payload.note,
      ignoreWarnings: payload.ignoreWarnings,
    });

    logEvent({
      event: "rollback.completed",
      requestId: getRequestId(context),
      versionId: result.timetableVersion.versionId,
      previousVersionId: result.previousVersion?.versionId ?? null,
      publishedAt: result.timetableVersion.publishedAt,
      changedSectionCount: result.changes.summary.sectionsChanged,
      totalChangeCount: result.changes.summary.totalChanges,
      wouldNotify: result.pushPreview.wouldNotify,
      pushSections: result.pushPreview.sections.length,
      auditEventId: result.auditEvent.auditEventId,
      triggeredBy: result.auditEvent.triggeredBy,
    });

    return context.json({
      requestId: getRequestId(context),
      version: result.timetableVersion,
      previousVersion: result.previousVersion,
      changes: result.changes,
      pushPreview: result.pushPreview,
      auditEvent: result.auditEvent,
    });
  });

  app.get("/v1/import-runs", async (context) => {
    const service = new TimetableAdminQueryService(getDatabase(context));
    return context.json({
      requestId: getRequestId(context),
      ...(await service.listImportRuns()),
    });
  });

  app.get("/v1/audit-events", async (context) => {
    const service = new TimetableAdminQueryService(getDatabase(context));
    return context.json({
      requestId: getRequestId(context),
      ...(await service.listAuditEvents()),
    });
  });

  app.get("/imports/status", async (context) => {
    const service = new TimetableAdminQueryService(getDatabase(context));
    const versions = await service.listVersions();
    const drafts = versions.versions.filter(
      (version) => version.publishStatus === "draft",
    );
    const currentVersion =
      versions.versions.find((version) => version.publishStatus === "published") ??
      null;
    const env = getBindings(context);

    return context.json({
      requestId: getRequestId(context),
      service: env.APP_NAME ?? "timetable-worker-admin",
      status: versions.versions.length === 0 ? "idle" : "ready",
      environment: env.ADMIN_ENV ?? "local",
      currentVersionId: currentVersion?.versionId ?? null,
      lastImportedVersionId: versions.versions[0]?.versionId ?? null,
      totalVersions: versions.versions.length,
      draftVersions: drafts.length,
    });
  });

  return app;
}

export const app = createApp();

export default {
  fetch: app.fetch,
};
