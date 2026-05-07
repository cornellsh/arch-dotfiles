# Caching and Storage

> Loaded when designing the data-storage hierarchy: L1 in-memory, L2 Redis, warm OLAP, cold archive; invalidation patterns; what goes where.

## The four storage tiers

A non-trivial product has four tiers of storage. The job is to put each piece of data in the right tier and keep the boundaries clean.

| Tier | Latency | Capacity | Persistence | Cost / GB / month |
|---|---|---|---|---|
| **L1 — in-process / in-memory** | sub-µs | small (MB-GB per process) | volatile | RAM cost |
| **L2 — distributed cache (Redis-class)** | sub-ms | medium (10s-100s GB) | volatile (persistence optional) | $-$$ |
| **Hot OLTP (Postgres-class)** | low-ms | large (100s GB-TB) | durable, transactional | $$$ |
| **Warm OLAP (ClickHouse-class)** | tens of ms | very large (TB-PB) | durable, columnar | $$ |
| **Cold archive (S3 + Parquet)** | seconds | unbounded | durable, immutable preferred | $ |

Numbers are illustrative; calibrate against your cloud and product. The relative ordering is universal.

## What goes where

### L1 — in-process

Cache items per request, per process, with very short lifetimes:

- **Token introspection results** (5-60s)
- **Settings cascade resolution** (60s)
- **Tenant routing decisions** (60s)
- **Schema metadata** (longer; invalidate on DDL)
- **Compiled query plans / prepared statements** (lifetime of process)

Memory budget per process: bounded; LRU eviction. Don't cache anything large in L1.

### L2 — Redis (distributed cache)

Items shared across processes/replicas with sub-second lifetimes that survive process restart:

- **Session state** (token deny-lists; idle-timer state)
- **Rate-limit buckets** (sliding-window counters)
- **Settings cascade** (after L1 miss, before DB)
- **User profile snippets** (avatar URL, display name; TTL minutes)
- **Pre-computed dashboard aggregates** (TTL minutes-hours)
- **Idempotency keys for state-changing endpoints** (24h)
- **Message-broker dedup state** (depending on broker — typically out-of-band)

Avoid Redis for:
- Anything that's the source of truth (use Postgres).
- Streaming / queueing — use a real broker.
- Aggregate analytics — use OLAP.
- Anything where loss is unacceptable AND you haven't enabled persistence.

### Hot OLTP — Postgres

Source of truth for transactional, mutable, indexed-by-key data:

- **Domain entities** (accounts, orders, positions, users, tenants)
- **Relationships** (account_links, settings cascade rows)
- **Audit events** (append-only; never UPDATE/DELETE)
- **Time-series** (via Timescale extension OR a dedicated TS store; see below)

Postgres is the default. Reach for alternatives when you have a specific reason.

### Warm OLAP — ClickHouse-class

For analytical queries spanning weeks/months/years over millions of rows:

- **Tick / event data** beyond the hot retention window
- **Pre-aggregated metrics** for fast counterparty dashboards
- **Reporting** — daily/weekly/monthly summaries
- **Cross-tenant analytics** (platform staff only)
- **Search-style queries** ("show me all events matching X")

Schema is denormalized; sort keys typically `(tenant_id, ts)` or similar; use materialized views for common aggregations.

### Cold archive — S3 + Parquet

For data beyond OLAP retention, regulatory-required retention, or low-frequency access:

- **Audit logs** beyond 90 days
- **Tick / event data** beyond OLAP retention
- **Backups** (point-in-time DB snapshots)
- **Tenant data exports** (delivered via signed URL)

Format: Parquet, partitioned by `tenant_id` and date. Encrypted at rest. Queryable via Athena/Trino/DuckDB on demand; not real-time.

## Layering decisions — what data flows where, and when

A common pipeline:

```
Application writes to Postgres (source of truth)
    │
    ├──> Outbox → Kafka → webhook fan-out + downstream consumers
    │
    ├──> Continuous aggregate (Timescale) → OLAP loader → ClickHouse
    │                                                       │
    │                                                       └──> Daily ETL → Parquet on S3
    │
    └──> Audit-events outbox → write-once tier (S3 with Object Lock or equivalent)
```

Each transition has an owner, a frequency, and a recovery story:

| From | To | Frequency | Owner | If broken |
|---|---|---|---|---|
| OLTP write → outbox | per-write | within transaction | application | atomicity preserved; audit lost only on DB loss |
| Outbox → Kafka | seconds | outbox-shipper worker | per-tenant | retry; deduped by event_id |
| Kafka → webhook | seconds-minutes | webhook-dispatcher | shared | retry with exponential backoff; DLQ after 24h |
| Postgres → ClickHouse | minutes-hourly | OLAP-loader worker | shared | replay from Postgres (still source of truth) |
| ClickHouse → S3 Parquet | daily | ETL worker | shared | replay from ClickHouse |

## Invalidation patterns

The hard problem with caches. Three patterns:

### TTL (time-to-live)

Item expires after N seconds; reads after expiry hit the source of truth. Simple; eventual consistency window equals TTL.

Use for: anything where staleness within N seconds is tolerable (settings, profiles, rate-limit buckets, token introspections).

Default TTL: 60s for most things; longer (15min-1h) for items that change rarely; shorter (1-5s) for items where staleness costs money.

### Explicit invalidation (write-through)

On write to source of truth, also invalidate (or update) the cache:

```
UPDATE settings SET value = X WHERE scope_kind = 'tenant' AND scope_id = Y AND key = Z;
DEL settings:tenant:<Y>:<Z>      -- Redis key
```

Pro: cache is immediately consistent.
Con: write path is more complex; failures partially break consistency.

Use for: items where a stale read is materially harmful (e.g., RBAC role changes — never tolerate stale).

### Pub/sub invalidation

Application publishes a "cache key changed" event; every cache subscriber receives it and evicts. Useful for fanning invalidation across many replicas.

Use for: large clusters where iterating Redis keys for a pattern is expensive.

### The cache stampede problem

When a hot cache key expires under load, every replica tries to refetch simultaneously, overwhelming the source. Patterns:

- **Probabilistic early refresh:** with TTL = 60s, start refreshing at 50s with probability proportional to remaining time. Smooths the load.
- **Single-flight:** one replica refetches; others wait. Implementable in Redis with a short-lived lock.
- **Stale-while-revalidate:** serve stale cached value while refetching in the background. Tolerable for non-critical reads.

For critical paths under high load, single-flight is the safest default.

## Sizing and capacity planning

Concrete starting points; tune on observation.

### L1 (in-process)

- **Settings cache:** 10k items × 1KB = ~10MB per process. Fine.
- **Token introspection cache:** 10k tokens × 256 bytes = ~2.5MB. Fine.
- **Schema metadata:** small.

Cap total L1 at ~64-128MB per process; LRU.

### L2 (Redis)

- **Per-tenant Redis (namespace+ tier):** 256MB-1GB; eviction allkeys-lru; persistence optional.
- **Shared Redis (shared_pod tier):** 4-16GB; per-tenant key prefix; eviction allkeys-lru.
- **Rate-limit Redis (cross-tenant):** 1-4GB; persistence on; backed up.

Sharded Redis cluster only when you exceed a single-node working set (hundreds of GB) — operationally heavier; avoid until needed.

### Hot OLTP (Postgres)

- **Per-tenant DB (cluster+ tier):** start at 4 vCPU / 16GB RAM / 100GB storage; auto-scale storage; alert on connection saturation.
- **Shared DB (shared_pod / namespace tier):** 8-16 vCPU / 64GB RAM / 500GB+; partition by tenant_id where appropriate; vacuum aggressively.

Connection pooling via PgBouncer in transaction mode; cap per-pod connections to <30 to avoid pool exhaustion.

### Warm OLAP (ClickHouse)

- 3-6 nodes; sharding by tenant_id; replication factor 2; storage on local NVMe + tiered to S3.
- 1-3 TB hot storage per node; cold tier in S3.

### Cold archive (S3)

- Lifecycle rules: hot tier → infrequent-access tier at 30 days → glacier-class at 90 days.
- Object Lock (write-once, retention enforced) for compliance-required data.

## Region and replication

| Tier | Replication | Cross-region story |
|---|---|---|
| L1 (in-process) | None | N/A — local to each replica |
| L2 (Redis) | Replica per primary; failover within region | Cross-region: not by default; replicate via dual-write or pub/sub if needed |
| OLTP (Postgres) | Synchronous replica + async replicas in same region | Cross-region: async replication; failover is a documented runbook |
| OLAP (ClickHouse) | Replication within region (RF=2) | Cross-region: optional; usually one region with backup |
| Cold (S3) | Within-region: 11 9's durability built in | Cross-region replication: optional bucket setting |

Cross-region active-active is a tier-specific decision (see `disaster-recovery.md`). Default for most products: single-region active + cross-region warm standby with documented failover.

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Cache as primary store | Loss = data loss | Cache reads only; writes through to OLTP first |
| L1 cache without bound | OOM under load | Bounded LRU |
| Redis without eviction policy | OOM under unexpected load | `maxmemory-policy allkeys-lru` |
| Reading from OLAP for transactional flows | Latency too high | OLTP for transactional reads; OLAP for analytics |
| Time-series in vanilla Postgres tables | Bloat; vacuum churn after months | Timescale hypertables OR dedicated TS store |
| No retention policies | Storage grows forever; backup cost grows; compliance issues | Tier-based retention; documented policies |
| Cache TTL = 0 (always read source) | Hot path congestion | Pick a TTL; profile; tune |
| Cache stampede unhandled | Outage on key expiration under load | Single-flight or stale-while-revalidate |
| Same Redis for cache + queue + session | One use case dominates capacity | Separate Redis instances per use case at scale |
| Writing to OLAP from application directly | Coupling; OLAP outages affect writes | OLTP write; OLAP loader async |
| Backups stored in same region as source | Region failure = backup loss | Cross-region copies of backups |
| Audit log in mutable storage | Compliance failure; tamper risk | Write-once tier (Object Lock) for audit |

## Worked example — storage layering for a B2B data platform

Setting: per-tenant data plane writes 10K-100K events/min depending on tenant size; counterparties query dashboards over the past week (warm) and run quarterly reports over the past year (cold).

Layering:

```
Application (per-tenant pod)
  ├─ L1: in-process settings cache, 60s TTL
  ├─ L2: per-tenant Redis 512MB; tokens, sessions, rate limits
  └─ writes ─> Postgres (per-tenant cluster+ tier; or shared with RLS for shared_pod)
                ├─ orders, accounts, settings, audit_events
                ├─ ticks: Timescale hypertable, 7d retention
                └─ outbox table (one row per emitted event)

Outbox shipper (per-tenant worker)
  └─ tail outbox ─> shared Kafka (1 topic per resource_kind)

Shared OLAP loader
  └─ Kafka consumer ─> ClickHouse (sharded by tenant_id, RF=2, 90d retention)

Shared ETL worker
  └─ daily snapshot ─> S3 Parquet (per-tenant prefix, partitioned by date)

Webhook dispatcher (shared)
  └─ Kafka consumer ─> POST to counterparty webhook URLs (idempotent retry)

Audit-events
  └─ append to Postgres (hash-chained, 7-year retention via S3 Object Lock for cold tier)
```

Concrete numbers:

- L1 cache hit rate target: >95%
- L2 cache hit rate target: >90%
- Postgres OLTP p99 read: <10ms
- ClickHouse warm query p99: <500ms
- S3 cold query p99: <30s

`OPEN:` markers:
- `OPEN: ClickHouse cluster sizing — start at 3 nodes, 1TB each; switch to 6 nodes if storage utilization > 70% OR query p99 > 5s for 7 consecutive days. Owner: data-platform lead.`
- `OPEN: separate Redis for rate limits vs cache — currently sharing; switch when cache evictions exceed rate-limit-bucket renewal rate by 10x. Owner: same.`

## Cross-references

- `data-plane.md` — for OLTP schema and tenancy isolation
- `messaging-and-events.md` — for the outbox → broker pattern
- `disaster-recovery.md` — for backup/restore tiers and cross-region replication
- `multi-tenancy.md` — for per-tenant vs shared sizing
- `compliance-and-ownership.md` — for audit retention and Object Lock
