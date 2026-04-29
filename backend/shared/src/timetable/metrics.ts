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

export type DomainMetricEvent = {
  name: string;
  value?: number;
};

type LatencySummary = {
  max: number;
  p50: number;
  p95: number;
  p99: number;
};

export type WorkerMetricsSnapshot = {
  budget: {
    projectedRequestsPerDay: number;
    requestsPerMinuteAverage: number;
    utilizationPercent: number;
    workersDailyRequestLimit: number;
    workersFreeTierState: "ok" | "watch" | "critical";
  };
  domainEvents: {
    byName: Record<string, number>;
    total: number;
  };
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
    byRoute: Record<string, number>;
    byStatus: Record<string, number>;
    latencyMs: LatencySummary;
    total: number;
  };
  startedAt: string;
  uptimeSeconds: number;
};

const MAX_DURATION_SAMPLES = 4_096;
const WORKERS_FREE_DAILY_REQUEST_LIMIT = 100_000;

function incrementCounter(
  counters: Map<string, number>,
  key: string | number,
  value = 1,
): void {
  const normalizedKey = String(key);
  counters.set(normalizedKey, (counters.get(normalizedKey) ?? 0) + value);
}

function toObject(counters: Map<string, number>): Record<string, number> {
  return Object.fromEntries(
    [...counters.entries()].sort(([left], [right]) =>
      left.localeCompare(right),
    ),
  );
}

function summarizeLatencies(samples: number[]): LatencySummary {
  if (samples.length === 0) {
    return {
      max: 0,
      p50: 0,
      p95: 0,
      p99: 0,
    };
  }

  const sorted = [...samples].sort((left, right) => left - right);
  const percentile = (value: number): number => {
    const index = Math.min(
      sorted.length - 1,
      Math.max(0, Math.ceil((value / 100) * sorted.length) - 1),
    );
    return sorted[index] ?? 0;
  };

  return {
    max: sorted[sorted.length - 1] ?? 0,
    p50: percentile(50),
    p95: percentile(95),
    p99: percentile(99),
  };
}

export function createWorkerMetrics() {
  const startedAt = new Date().toISOString();
  const requestCountsByStatus = new Map<string, number>();
  const requestCountsByRoute = new Map<string, number>();
  const errorCountsByCode = new Map<string, number>();
  const errorCountsByType = new Map<string, number>();
  const rateLimitCountsByRule = new Map<string, number>();
  const domainEventCountsByName = new Map<string, number>();
  const requestDurationsMs: number[] = [];

  let totalRequests = 0;
  let totalErrors = 0;
  let totalRateLimits = 0;
  let totalDomainEvents = 0;

  return {
    recordRequest(event: RequestMetricEvent): void {
      totalRequests += 1;
      incrementCounter(requestCountsByStatus, event.status);
      incrementCounter(
        requestCountsByRoute,
        `${event.method.toUpperCase()} ${event.path}`,
      );
      requestDurationsMs.push(event.durationMs);
      if (requestDurationsMs.length > MAX_DURATION_SAMPLES) {
        requestDurationsMs.shift();
      }
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

    recordDomainEvent(event: DomainMetricEvent): void {
      const value = Math.max(0, Math.trunc(event.value ?? 1));
      if (value === 0) {
        return;
      }

      totalDomainEvents += value;
      incrementCounter(domainEventCountsByName, event.name, value);
    },

    snapshot(): WorkerMetricsSnapshot {
      const startedAtMs = Date.parse(startedAt);
      const uptimeMs = Math.max(1_000, Date.now() - startedAtMs);
      const uptimeMinutes = uptimeMs / 60_000;
      const projectedRequestsPerDay = Math.round(
        totalRequests * (86_400_000 / uptimeMs),
      );
      const utilizationPercent = Number(
        (
          (projectedRequestsPerDay / WORKERS_FREE_DAILY_REQUEST_LIMIT) *
          100
        ).toFixed(1),
      );

      return {
        budget: {
          projectedRequestsPerDay,
          requestsPerMinuteAverage: Number(
            (totalRequests / uptimeMinutes).toFixed(2),
          ),
          utilizationPercent,
          workersDailyRequestLimit: WORKERS_FREE_DAILY_REQUEST_LIMIT,
          workersFreeTierState:
            utilizationPercent >= 80
              ? "critical"
              : utilizationPercent >= 70
                ? "watch"
                : "ok",
        },
        domainEvents: {
          byName: toObject(domainEventCountsByName),
          total: totalDomainEvents,
        },
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
          byRoute: toObject(requestCountsByRoute),
          byStatus: toObject(requestCountsByStatus),
          latencyMs: summarizeLatencies(requestDurationsMs),
          total: totalRequests,
        },
        startedAt,
        uptimeSeconds: Math.floor(uptimeMs / 1_000),
      };
    },
  };
}
