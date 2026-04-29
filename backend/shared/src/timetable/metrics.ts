export type RequestMetricEvent = {
  durationMs: number;
  method: string;
  path: string;
  status: number;
};

export type ErrorMetricEvent = {
  code: string;
  method: string;
  path: string;
  status: number;
  type: string;
};

export type RateLimitMetricEvent = {
  method: string;
  path: string;
  ruleName: string;
};

export type WorkerMetricsSnapshot = {
  errors: {
    byCode: Record<string, number>;
    byType: Record<string, number>;
    total: number;
  };
  rateLimits: {
    byRule: Record<string, number>;
    total: number;
  };
  requests: {
    byStatus: Record<string, number>;
    total: number;
  };
  startedAt: string;
};

function incrementCounter(
  counters: Map<string, number>,
  key: string | number,
): void {
  const normalizedKey = String(key);
  counters.set(normalizedKey, (counters.get(normalizedKey) ?? 0) + 1);
}

function toObject(counters: Map<string, number>): Record<string, number> {
  return Object.fromEntries(
    [...counters.entries()].sort(([left], [right]) =>
      left.localeCompare(right),
    ),
  );
}

export function createWorkerMetrics() {
  const startedAt = new Date().toISOString();
  const requestCountsByStatus = new Map<string, number>();
  const errorCountsByCode = new Map<string, number>();
  const errorCountsByType = new Map<string, number>();
  const rateLimitCountsByRule = new Map<string, number>();

  let totalRequests = 0;
  let totalErrors = 0;
  let totalRateLimits = 0;

  return {
    recordRequest(event: RequestMetricEvent): void {
      totalRequests += 1;
      incrementCounter(requestCountsByStatus, event.status);
    },

    recordError(event: ErrorMetricEvent): void {
      totalErrors += 1;
      incrementCounter(errorCountsByCode, event.code);
      incrementCounter(errorCountsByType, event.type);
    },

    recordRateLimit(event: RateLimitMetricEvent): void {
      totalRateLimits += 1;
      incrementCounter(rateLimitCountsByRule, event.ruleName);
    },

    snapshot(): WorkerMetricsSnapshot {
      return {
        errors: {
          byCode: toObject(errorCountsByCode),
          byType: toObject(errorCountsByType),
          total: totalErrors,
        },
        rateLimits: {
          byRule: toObject(rateLimitCountsByRule),
          total: totalRateLimits,
        },
        requests: {
          byStatus: toObject(requestCountsByStatus),
          total: totalRequests,
        },
        startedAt,
      };
    },
  };
}
