import { Hono } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";

import {
  D1DatabaseClient,
  type D1DatabaseLike,
} from "../../shared/src/timetable/db";
import { AppError, isAppError } from "../../shared/src/timetable/errors";
import { createWorkerMetrics } from "../../shared/src/timetable/metrics";
import {
  createRateLimitGuard,
  getClientIdentifier,
} from "../../shared/src/timetable/rate-limit";
import { TimetableQueryService } from "../../shared/src/timetable/services";

type Bindings = {
  APP_NAME?: string;
  API_ENV?: string;
  TIMETABLE_DB?: D1DatabaseLike;
};

type Variables = {
  errorCode?: string;
  errorType?: string;
  requestId: string;
};

type StructuredErrorResponse = {
  error: {
    code: string;
    details?: {
      limit: number;
      retryAfterSeconds: number;
      ruleName: string;
    };
    message: string;
    requestId: string;
  };
};

type AppDependencies = {
  metrics?: ReturnType<typeof createWorkerMetrics>;
  now?: () => number;
  rateLimitGuard?: ReturnType<typeof createRateLimitGuard>;
};

const READ_CACHE_CONTROL = "public, max-age=60, s-maxage=300";

function createStructuredErrorResponse(
  requestId: string,
  error: {
    code: string;
    details?: StructuredErrorResponse["error"]["details"];
    message: string;
  },
): StructuredErrorResponse {
  return {
    error: {
      code: error.code,
      ...(error.details ? { details: error.details } : {}),
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

function setReadCacheHeaders(
  context: {
    header(name: string, value: string): void;
  },
  input?: {
    etag?: string;
    versionId?: string;
  },
): void {
  context.header("Cache-Control", READ_CACHE_CONTROL);
  context.header("Vary", "If-None-Match");
  if (input?.etag) {
    context.header("ETag", input.etag);
  }
  if (input?.versionId) {
    context.header("x-timetable-version", input.versionId);
  }
}

function createReadEtag(
  scope: string,
  versionId: string,
  suffix?: string,
): string {
  const normalizedSuffix = suffix?.trim();
  return normalizedSuffix
    ? `W/"${scope}:${versionId}:${normalizedSuffix}"`
    : `W/"${scope}:${versionId}"`;
}

function requestMatchesEtag(
  context: { req: { header(name: string): string | undefined } },
  etag: string,
): boolean {
  const headerValue = context.req.header("if-none-match");
  if (!headerValue) {
    return false;
  }

  return headerValue
    .split(",")
    .map((value) => value.trim())
    .some((candidate) => candidate === "*" || candidate === etag);
}

function logEvent(payload: Record<string, unknown>): void {
  console.log(JSON.stringify(payload));
}

function createDefaultRateLimitGuard() {
  return createRateLimitGuard([
    {
      blockMs: 60_000,
      limit: 60,
      name: "api-burst",
      phase: "before",
      when: (request) => request.path.startsWith("/v1/"),
      windowMs: 60_000,
    },
    {
      blockMs: 15 * 60_000,
      limit: 12,
      name: "api-invalid-request",
      phase: "after",
      matchStatus: (status) => status === 400 || status === 404,
      when: (request) => request.path.startsWith("/v1/"),
      windowMs: 5 * 60_000,
    },
  ]);
}

function createRateLimitResponse(
  requestId: string,
  decision: Exclude<
    ReturnType<ReturnType<typeof createRateLimitGuard>["checkBefore"]>,
    { limited: false }
  >,
) {
  return createStructuredErrorResponse(requestId, {
    code: "rate_limited",
    details: {
      limit: decision.limit,
      retryAfterSeconds: decision.retryAfterSeconds,
      ruleName: decision.ruleName ?? "unknown",
    },
    message: "Too many requests. Please retry later.",
  });
}

export function createApp(dependencies: AppDependencies = {}): Hono<{
  Bindings: Bindings;
  Variables: Variables;
}> {
  const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();
  const metrics = dependencies.metrics ?? createWorkerMetrics();
  const now = dependencies.now ?? (() => Date.now());
  const rateLimitGuard =
    dependencies.rateLimitGuard ?? createDefaultRateLimitGuard();

  app.use("*", async (context, next) => {
    const requestId = context.req.header("x-request-id") ?? crypto.randomUUID();
    const startedAt = now();
    const request = {
      clientId: getClientIdentifier({
        headers: context.req.raw.headers,
        method: context.req.method,
      }),
      method: context.req.method,
      path: context.req.path,
    };

    context.set("requestId", requestId);
    context.header("x-request-id", requestId);

    const preflightDecision = rateLimitGuard.checkBefore(request, startedAt);
    if (preflightDecision.limited) {
      const env = getBindings(context);
      const response = context.json(
        createRateLimitResponse(requestId, preflightDecision),
        429,
      );

      response.headers.set(
        "Retry-After",
        String(preflightDecision.retryAfterSeconds),
      );

      metrics.recordRateLimit({
        method: request.method,
        path: request.path,
        ruleName: preflightDecision.ruleName ?? "unknown",
      });
      metrics.recordError({
        code: "rate_limited",
        method: request.method,
        path: request.path,
        status: 429,
        type: "RateLimitError",
      });
      metrics.recordRequest({
        durationMs: now() - startedAt,
        method: request.method,
        path: request.path,
        status: 429,
      });

      logEvent({
        event: "request.rate_limited",
        requestId,
        method: request.method,
        path: request.path,
        status: 429,
        ruleName: preflightDecision.ruleName ?? "unknown",
        retryAfterSeconds: preflightDecision.retryAfterSeconds,
        environment: env.API_ENV ?? "local",
        worker: env.APP_NAME ?? "timetable-worker-api",
      });

      return response;
    }

    await next();

    const env = getBindings(context);
    const postResponseDecision = rateLimitGuard.checkAfter(
      request,
      context.res.status,
      now(),
    );
    if (postResponseDecision.limited) {
      const response = context.json(
        createRateLimitResponse(requestId, postResponseDecision),
        429,
      );

      response.headers.set(
        "Retry-After",
        String(postResponseDecision.retryAfterSeconds),
      );
      context.res = response;

      metrics.recordRateLimit({
        method: request.method,
        path: request.path,
        ruleName: postResponseDecision.ruleName ?? "unknown",
      });
      metrics.recordError({
        code: "rate_limited",
        method: request.method,
        path: request.path,
        status: 429,
        type: "RateLimitError",
      });

      logEvent({
        event: "request.rate_limited",
        requestId,
        method: request.method,
        path: request.path,
        status: 429,
        ruleName: postResponseDecision.ruleName ?? "unknown",
        retryAfterSeconds: postResponseDecision.retryAfterSeconds,
        environment: env.API_ENV ?? "local",
        worker: env.APP_NAME ?? "timetable-worker-api",
      });
    } else if (context.res.status >= 400 && !context.get("errorCode")) {
      metrics.recordError({
        code: context.get("errorCode") ?? `http_${String(context.res.status)}`,
        method: request.method,
        path: request.path,
        status: context.res.status,
        type: context.get("errorType") ?? "HttpError",
      });
    }

    metrics.recordRequest({
      durationMs: now() - startedAt,
      method: request.method,
      path: request.path,
      status: context.res.status,
    });

    logEvent({
      event: "request.completed",
      requestId,
      method: request.method,
      path: request.path,
      status: context.res.status,
      durationMs: now() - startedAt,
      environment: env.API_ENV ?? "local",
      worker: env.APP_NAME ?? "timetable-worker-api",
    });
  });

  app.onError((error, context) => {
    const requestId = context.get("requestId");
    const appError = isAppError(error)
      ? error
      : new AppError("internal_error", "Internal server error.");
    const path = context.req.path;
    const method = context.req.method;

    logEvent({
      event: "request.failed",
      requestId,
      method,
      path,
      status: appError.status,
      code: appError.code,
      message: appError.message,
    });
    context.set("errorCode", appError.code);
    context.set(
      "errorType",
      error instanceof Error ? error.name : "UnknownError",
    );
    metrics.recordError({
      code: appError.code,
      method,
      path,
      status: appError.status,
      type: error instanceof Error ? error.name : "UnknownError",
    });

    return context.json(
      createStructuredErrorResponse(requestId, appError),
      appError.status as ContentfulStatusCode,
    );
  });

  app.notFound((context) => {
    const requestId = context.get("requestId");
    context.set("errorCode", "not_found");
    context.set("errorType", "RouteNotFound");
    metrics.recordError({
      code: "not_found",
      method: context.req.method,
      path: context.req.path,
      status: 404,
      type: "RouteNotFound",
    });
    return context.json(
      createStructuredErrorResponse(
        requestId,
        new AppError("not_found", "Route not found."),
      ),
      404,
    );
  });

  app.get("/metrics", (context) =>
    context.json({
      environment: getBindings(context).API_ENV ?? "local",
      service: getBindings(context).APP_NAME ?? "timetable-worker-api",
      ...metrics.snapshot(),
    }),
  );

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
    const version = await service.getCurrentVersionRecord();
    const etag = createReadEtag("current-version", version.id);

    setReadCacheHeaders(context, {
      etag,
      versionId: version.id,
    });
    if (requestMatchesEtag(context, etag)) {
      metrics.recordDomainEvent({
        name: "cache.not_modified.current_version",
      });
      return context.body(null, 304);
    }

    return context.json(await service.getCurrentVersion());
  });

  app.get("/v1/versions", async (context) => {
    const service = new TimetableQueryService(getDatabase(context));
    setReadCacheHeaders(context);
    return context.json(await service.listVersions());
  });

  app.get("/v1/sections", async (context) => {
    const service = new TimetableQueryService(getDatabase(context));
    const version = await service.getCurrentVersionRecord();
    const etag = createReadEtag("sections", version.id);

    setReadCacheHeaders(context, {
      etag,
      versionId: version.id,
    });
    if (requestMatchesEtag(context, etag)) {
      metrics.recordDomainEvent({
        name: "cache.not_modified.sections",
      });
      return context.body(null, 304);
    }

    return context.json(await service.listSectionsForVersion(version));
  });

  app.get("/v1/sections/:sectionCode", async (context) => {
    const service = new TimetableQueryService(getDatabase(context));
    const sectionCode = context.req.param("sectionCode");
    const lookup = await service.getPublishedSectionLookup(sectionCode);
    const etag = createReadEtag(
      "section-detail",
      lookup.version.id,
      lookup.section.normalizedCode,
    );

    setReadCacheHeaders(context, {
      etag,
      versionId: lookup.version.id,
    });
    if (requestMatchesEtag(context, etag)) {
      metrics.recordDomainEvent({
        name: "cache.not_modified.section_detail",
      });
      return context.body(null, 304);
    }

    return context.json(service.getSectionFromLookup(lookup));
  });

  app.get("/v1/sections/:sectionCode/timetable", async (context) => {
    const service = new TimetableQueryService(getDatabase(context));
    const sectionCode = context.req.param("sectionCode");
    const lookup = await service.getPublishedSectionLookup(sectionCode);
    const etag = createReadEtag(
      "section-timetable",
      lookup.version.id,
      lookup.section.normalizedCode,
    );

    setReadCacheHeaders(context, {
      etag,
      versionId: lookup.version.id,
    });
    if (requestMatchesEtag(context, etag)) {
      metrics.recordDomainEvent({
        name: "cache.not_modified.section_timetable",
      });
      return context.body(null, 304);
    }

    return context.json(await service.getSectionTimetableFromLookup(lookup));
  });

  return app;
}

export const app = createApp();

export default {
  fetch: app.fetch,
};
