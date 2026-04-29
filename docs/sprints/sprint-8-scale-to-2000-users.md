# Sprint 8: Scale to 2,000 Users

## Objective

Tune the system so a read-heavy student timetable product can serve roughly 2,000 users while staying within free-tier constraints for as long as practical.

## Why This Sprint Exists

The target is not abstract scale. It is cost-constrained scale. The stack choice only works if request patterns, cache behavior, and notification design are kept disciplined.

## Primary Outcomes

- usage model for 2,000 users
- tuned API request patterns
- cache and query improvements
- operational thresholds for when free tier is no longer enough

## Scope

### In Scope

- traffic modeling
- query optimization
- cache strategy
- monitoring and dashboards
- free-tier breach thresholds

### Out of Scope

- arbitrary high-scale redesign
- migration to paid infra before needed

## Dependencies

- beta-ready system from Sprint 7
- enough real usage assumptions or beta data to model demand credibly

## Known Current Free-Tier Constraints

As verified during planning:

- Cloudflare Workers Free: `100,000 requests/day`
- Cloudflare Workers Free CPU per HTTP request: `10 ms`
- Cloudflare D1 Free: `50` queries per Worker invocation
- Cloudflare D1 Free storage: `500 MB` per database
- Firebase Cloud Messaging is no-cost
- GitHub Actions hosted runners are free for public repositories

These numbers are good enough for a timetable app only if the app stays read-light and avoids unnecessary server involvement.

## Scale Model to Build

Estimate at least:

- daily active users
- average opens per user per day
- API calls per open
- refresh frequency
- change-notification volume

Example thought process:

- if 2,000 users each make 10 API calls daily, that is 20,000 requests/day
- if poor app design causes 60 API calls daily, that jumps to 120,000 requests/day and breaks Workers Free

This sprint is about designing toward the first number and away from the second.

## Deliverables

- request budget model
- cache policy
- optimized section timetable endpoint
- dashboard or metrics summary
- scale decision thresholds

## Detailed Work Breakdown

### 1. Request Budgeting

For each mobile flow, calculate:

- first install request count
- cold open request count
- warm open request count
- manual refresh request count

Goal:

- compress common user flows to a very small number of requests

### 2. Endpoint Optimization

Ensure:

- section timetable endpoint is one primary fetch
- no N+1 data fetching
- version metadata can ride with schedule payload where useful

### 3. Client Caching

Implement or tighten:

- conditional refresh behavior
- cached section list
- cached current version metadata
- stale-while-revalidate user experience where appropriate

### 4. Query Tuning

Audit:

- timetable by section query
- section list query
- current version query

Index and simplify until the common paths are predictably cheap.

### 5. Metrics and Dashboards

Track:

- requests per day
- error rate
- p95 and p99 latency if feasible
- rate-limited events
- import success rate
- notification trigger counts

### 6. Free-Tier Exit Thresholds

Define ahead of time what triggers a paid upgrade or architecture change, such as:

- sustained request volume above 70 to 80 percent of daily limit
- unacceptable latency caused by D1 contention
- need for more scheduled jobs or admin workflows than free limits allow

### 7. Documentation for Operations

Create a short scale runbook:

- where to check usage
- what to do if daily request budget is threatened
- how to reduce traffic quickly if needed

## Acceptance Criteria

- the team has a quantified request budget model
- common app flows fit within that budget
- backend hot paths are query-efficient
- cache strategy is implemented or documented clearly enough to enforce
- paid-upgrade thresholds are explicit

## Testing Plan

Required:

- request-count review per common flow
- backend query review on hot paths
- manual stress simulation where feasible

Useful optional checks:

- simple load simulation against section timetable endpoint
- cache-hit ratio approximation from logs

## Risks

### Risk: 2,000 users are possible on paper but not with current app behavior

Mitigation:

- measure request count per user journey
- cut chatty refresh behavior
- ship caching before growth

### Risk: D1 becomes the bottleneck during peak timetable checks

Mitigation:

- keep reads indexed
- minimize per-request query count
- consider precomputed response shapes if necessary

### Risk: free tier becomes a hard product constraint that blocks useful features

Mitigation:

- define upgrade thresholds explicitly
- separate must-have features from cost-heavy nice-to-haves

## Exit Criteria

- the team knows whether the current design can realistically support the target user count for free
- any gap has a concrete mitigation or upgrade trigger

## Definition of Done

- traffic budget documented
- hot path optimizations committed
- monitoring approach documented
- scale runbook committed
