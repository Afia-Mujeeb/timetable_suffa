type RateLimitEntry = {
  count: number;
  resetAt: number;
};

type GuardWindowEntry = {
  blockedUntil: number;
  timestamps: number[];
};

export type RateLimitRequest = {
  clientId: string;
  method: string;
  path: string;
};

export type RateLimitRule = {
  name: string;
  phase: "before" | "after";
  limit: number;
  windowMs: number;
  blockMs: number;
  scope?: "client" | "client-path";
  when?: (request: RateLimitRequest) => boolean;
  matchStatus?: (status: number) => boolean;
};

export type RateLimitDecision = {
  allowed?: boolean;
  limit: number;
  limited?: boolean;
  remaining: number;
  resetAt: string;
  retryAfterSeconds: number;
  ruleName?: string;
  windowMs?: number;
};

export class FixedWindowRateLimiter {
  private readonly entries = new Map<string, RateLimitEntry>();

  constructor(private readonly maxEntries = 2_048) {}

  check(input: {
    key: string;
    limit: number;
    windowMs: number;
    now?: number;
  }): RateLimitDecision {
    const now = input.now ?? Date.now();
    const existing = this.entries.get(input.key);

    if (!existing || existing.resetAt <= now) {
      this.setEntry(input.key, {
        count: 1,
        resetAt: now + input.windowMs,
      });
      return this.toDecision({
        allowed: true,
        count: 1,
        limit: input.limit,
        resetAt: now + input.windowMs,
        now,
      });
    }

    existing.count += 1;
    this.entries.set(input.key, existing);

    return this.toDecision({
      allowed: existing.count <= input.limit,
      count: existing.count,
      limit: input.limit,
      resetAt: existing.resetAt,
      now,
    });
  }

  bump(input: {
    key: string;
    windowMs: number;
    now?: number;
  }): number {
    const now = input.now ?? Date.now();
    const existing = this.entries.get(input.key);

    if (!existing || existing.resetAt <= now) {
      this.setEntry(input.key, {
        count: 1,
        resetAt: now + input.windowMs,
      });
      return 1;
    }

    existing.count += 1;
    this.entries.set(input.key, existing);
    return existing.count;
  }

  peek(input: {
    key: string;
    limit: number;
    windowMs: number;
    now?: number;
  }): RateLimitDecision {
    const now = input.now ?? Date.now();
    const existing = this.entries.get(input.key);
    if (!existing || existing.resetAt <= now) {
      return this.toDecision({
        allowed: true,
        count: 0,
        limit: input.limit,
        resetAt: now + input.windowMs,
        now,
      });
    }

    return this.toDecision({
      allowed: existing.count < input.limit,
      count: existing.count,
      limit: input.limit,
      resetAt: existing.resetAt,
      now,
    });
  }

  private setEntry(key: string, entry: RateLimitEntry): void {
    this.evictExpired(entry.resetAt);
    if (this.entries.size >= this.maxEntries) {
      const oldestKey = this.entries.keys().next().value;
      if (oldestKey !== undefined) {
        this.entries.delete(oldestKey);
      }
    }
    this.entries.set(key, entry);
  }

  private evictExpired(now: number): void {
    for (const [key, entry] of this.entries.entries()) {
      if (entry.resetAt <= now) {
        this.entries.delete(key);
      }
    }
  }

  private toDecision(input: {
    allowed: boolean;
    count: number;
    limit: number;
    resetAt: number;
    now: number;
  }): RateLimitDecision {
    return {
      allowed: input.allowed,
      limit: input.limit,
      remaining: Math.max(0, input.limit - input.count),
      retryAfterSeconds: Math.max(
        1,
        Math.ceil((input.resetAt - input.now) / 1_000),
      ),
      resetAt: new Date(input.resetAt).toISOString(),
    };
  }
}

export function getClientAddress(request: Request): string {
  const forwardedFor = request.headers.get("cf-connecting-ip");
  if (forwardedFor && forwardedFor.trim().length > 0) {
    return forwardedFor.trim();
  }

  const proxyHeader = request.headers.get("x-forwarded-for");
  if (proxyHeader && proxyHeader.trim().length > 0) {
    const [first] = proxyHeader.split(",", 1);
    if (first && first.trim().length > 0) {
      return first.trim();
    }
  }

  return "unknown";
}

export function getClientIdentifier(request: {
  headers: Headers;
  method: string;
}): string {
  const forwardedFor = request.headers.get("cf-connecting-ip")
    ?? request.headers.get("x-real-ip")
    ?? request.headers.get("x-forwarded-for");

  if (forwardedFor && forwardedFor.trim().length > 0) {
    const [first] = forwardedFor.split(",", 1);
    if (first && first.trim().length > 0) {
      return first.trim();
    }
  }

  const userAgent = request.headers.get("user-agent");
  if (userAgent && userAgent.trim().length > 0) {
    return `ua:${userAgent.trim()}`;
  }

  return "anonymous";
}

function buildScopeKey(rule: RateLimitRule, request: RateLimitRequest): string {
  if (rule.scope === "client-path") {
    return `${request.clientId}:${request.method}:${request.path}`;
  }

  return request.clientId;
}

function isRuleMatch(
  rule: RateLimitRule,
  request: RateLimitRequest,
  status?: number,
): boolean {
  if (rule.when && !rule.when(request)) {
    return false;
  }

  if (rule.phase === "after") {
    if (status === undefined) {
      return false;
    }

    if (rule.matchStatus && !rule.matchStatus(status)) {
      return false;
    }
  }

  return true;
}

function pruneGuardWindow(
  entry: GuardWindowEntry,
  now: number,
  windowMs: number,
): GuardWindowEntry {
  const windowStart = now - windowMs;

  return {
    blockedUntil: entry.blockedUntil > now ? entry.blockedUntil : 0,
    timestamps: entry.timestamps.filter((timestamp) => timestamp > windowStart),
  };
}

function toGuardDecision(input: {
  blockedUntil: number;
  limit: number;
  now: number;
  ruleName: string;
  windowMs: number;
}): RateLimitDecision {
  return {
    limit: input.limit,
    limited: true,
    remaining: 0,
    retryAfterSeconds: Math.max(
      1,
      Math.ceil((input.blockedUntil - input.now) / 1_000),
    ),
    resetAt: new Date(input.blockedUntil).toISOString(),
    ruleName: input.ruleName,
    windowMs: input.windowMs,
  };
}

export function createRateLimitGuard(rules: RateLimitRule[]) {
  const windows = new Map<string, GuardWindowEntry>();

  const evaluateRule = (
    rule: RateLimitRule,
    request: RateLimitRequest,
    now: number,
  ): RateLimitDecision => {
    const key = `${rule.name}:${buildScopeKey(rule, request)}`;
    const entry = pruneGuardWindow(
      windows.get(key) ?? {
        blockedUntil: 0,
        timestamps: [],
      },
      now,
      rule.windowMs,
    );

    if (entry.blockedUntil > now) {
      windows.set(key, entry);
      return toGuardDecision({
        blockedUntil: entry.blockedUntil,
        limit: rule.limit,
        now,
        ruleName: rule.name,
        windowMs: rule.windowMs,
      });
    }

    entry.timestamps.push(now);
    if (entry.timestamps.length > rule.limit) {
      entry.blockedUntil = now + rule.blockMs;
      windows.set(key, entry);
      return toGuardDecision({
        blockedUntil: entry.blockedUntil,
        limit: rule.limit,
        now,
        ruleName: rule.name,
        windowMs: rule.windowMs,
      });
    }

    windows.set(key, entry);
    return {
      limit: rule.limit,
      limited: false,
      remaining: Math.max(0, rule.limit - entry.timestamps.length),
      retryAfterSeconds: Math.max(1, Math.ceil(rule.windowMs / 1_000)),
      resetAt: new Date(now + rule.windowMs).toISOString(),
      ruleName: rule.name,
      windowMs: rule.windowMs,
    };
  };

  return {
    checkBefore(
      request: RateLimitRequest,
      now: number = Date.now(),
    ): RateLimitDecision {
      for (const rule of rules) {
        if (rule.phase !== "before" || !isRuleMatch(rule, request)) {
          continue;
        }

        const decision = evaluateRule(rule, request, now);
        if (decision.limited) {
          return decision;
        }
      }

      return {
        limit: 0,
        limited: false,
        remaining: 0,
        retryAfterSeconds: 1,
        resetAt: new Date(now).toISOString(),
      };
    },

    checkAfter(
      request: RateLimitRequest,
      status: number,
      now: number = Date.now(),
    ): RateLimitDecision {
      for (const rule of rules) {
        if (rule.phase !== "after" || !isRuleMatch(rule, request, status)) {
          continue;
        }

        const decision = evaluateRule(rule, request, now);
        if (decision.limited) {
          return decision;
        }
      }

      return {
        limit: 0,
        limited: false,
        remaining: 0,
        retryAfterSeconds: 1,
        resetAt: new Date(now).toISOString(),
      };
    },
  };
}
