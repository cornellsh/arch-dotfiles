# Data Plane

> Loaded when designing the per-tenant data plane: which services live per-tenant vs shared, OLTP/OLAP/audit/cache layering, schema patterns, primary-key strategies, tenancy isolation in schema, time-series tables.

## What "data plane" means here

The data plane is everything that handles requests, processes events, and stores state for end users. It contrasts with the **control plane** (tenant lifecycle, billing, branding, observability, secret management) which is shared across all tenants.

A typical product has a per-tenant data plane composition:

```
Per-tenant pod (namespace+ tier):
├─ customer-api / customer-api    OAuth-protected; end users hit this
├─ manager-api                  OAuth-protected; tenant admins hit this
├─ webapi (REST)                OAuth client_credentials; counterparty CRM hits this
├─ engine                       The product's core logic
├─ workers                      Background: settlement, reports, swap, EOD batches
├─ Postgres + Timescale (or equivalent OLTP+TS)
├─ Redis cache
└─ NATS (or equivalent message broker)
```

For shared_pod tier: same composition, but one set of services serves multiple tenants, with `tenant_id` as a row-level partition.

Shared across all tenants:
```
├─ ClickHouse (or equivalent OLAP)   warm tick + analytics
├─ Redpanda / Kafka                  external event bus + webhook fan-out
├─ S3 + Parquet                      cold archive
├─ data-api                          tick fan-out service
└─ webhook-dispatcher                Kafka consumer that POSTs to counterparty CRMs
```

## Service responsibilities (one-line each)

A typical service inventory:

| Service | Layer | What it does |
|---|---|---|
| `customer-api` (or `user-api`) | per-tenant | gRPC/Connect-RPC; OAuth-protected; end-user actions; settings cascade resolver |
| `manager-api` | per-tenant | gRPC/Connect-RPC; tenant admin operations: groups, RBAC, market params |
| `webapi` | per-tenant | REST; counterparty backend (CRM): account create, deposit, transfer |
| `engine` | per-tenant | Core domain logic — matching, OMS, risk; the value-creating part |
| `workers` | per-tenant | Background jobs: outbox shipper, billing snapshots, reconcilers, EOD |
| `data-api` | shared | Real-time data fan-out — WebSockets to subscribers |
| `webhook-dispatcher` | shared | Consume external bus → POST to counterparty webhooks; idempotent retry |

For Mode 0 / Mode R both: name your services with one-line "what it does" entries before designing schemas. The names crystallize the architecture.

## Primary-key strategies

### ULIDs for application-visible identifiers

- 26-character base32; lexicographically sortable by creation time; URL-safe.
- Generate at the service (where you control the clock, not the client).
- Pair with a type prefix when serialized externally (`order_<ulid>`, `user_<ulid>`) — see `api-design.md`.

```sql
CREATE TABLE orders (
    id           CHAR(26) PRIMARY KEY,           -- ULID
    tenant_id    UUID NOT NULL,
    account_id   CHAR(26) NOT NULL,
    -- ...
);
```

### UUIDv7 as an alternative

- 128-bit; time-ordered like ULID; sortable by creation; native UUID type in many DBs.
- Use if your DB has a native UUID type and you want index efficiency without custom CHAR(26).

### Sequential integer IDs

- Avoid for application-visible identifiers (predictable, leaks ordering, hard to merge across regions).
- Fine for internal junction tables, indexed PKs that are never exposed.

### Composite keys

- Use sparingly; debugging is harder.
- One legitimate use: time-series (see Timescale section below) where `(tenant_id, ts)` is the natural partition key.

## Tenancy isolation in schema

Three approaches; pick one and document the reason:

### Approach A — Single DB, `tenant_id` column on every row, RLS

```sql
CREATE TABLE accounts (
    id          CHAR(26) PRIMARY KEY,
    tenant_id   UUID NOT NULL,
    -- ...
);
CREATE INDEX accounts_tenant_idx ON accounts (tenant_id);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON accounts
    USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

The application sets `app.current_tenant` per-request; RLS prevents cross-tenant queries even if app code is buggy.

Use when: shared_pod tier; controlling the application code; defense in depth needed; query patterns are tenant-scoped.

Don't use when: you have analytical queries that span tenants regularly (RLS becomes painful).

### Approach B — Per-tenant schema in shared DB

```sql
-- One Postgres database; one schema per tenant
CREATE SCHEMA tenant_acme;
CREATE TABLE tenant_acme.accounts (...);

CREATE SCHEMA tenant_globex;
CREATE TABLE tenant_globex.accounts (...);
```

Connection sets `search_path = tenant_<short_name>`; queries find the tenant's tables.

Use when: namespace tier; tenants are isolated enough that DDL per-tenant is feasible; backups can be per-schema.

Don't use when: you have hundreds of tenants (DDL migrations across schemas become a coordination problem).

### Approach C — Per-tenant DB cluster (cluster+ tier)

One Postgres cluster per tenant. Backups, failover, schema migrations all happen per-tenant.

Use when: cluster+ tier; data isolation is contractual; per-tenant ops cost is acceptable.

The default for most products: **A for shared_pod, C for cluster+, with B as a viable middle.** Document the choice and the threshold for migration.

## OLTP schema patterns

### The "settings cascade"

Many products have settings that cascade: platform default → counterparty default → group default → account override → individual override. Encode the cascade as a resolver pattern, not as duplicated rows.

```sql
CREATE TABLE settings (
    scope_kind   TEXT NOT NULL,    -- 'platform', 'tenant', 'group', 'account', 'user'
    scope_id     CHAR(26),         -- NULL when scope_kind = 'platform'
    key          TEXT NOT NULL,
    value        JSONB NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (scope_kind, scope_id, key)
);
```

Resolver:

```
Look up by (account, key); if not found, fall back to (group, key); if not found, fall back to (tenant, key); if not found, fall back to (platform, key); else error.
```

Cache the resolved value in Redis with TTL ~60s; invalidate on `UPDATE settings`.

### The "audit_events" pattern

Every state change emits an audit event:

```sql
CREATE TABLE audit_events (
    id           CHAR(26) PRIMARY KEY,            -- ULID, sortable
    tenant_id    UUID NOT NULL,
    actor_kind   TEXT NOT NULL,                    -- 'user', 'service', 'webhook', 'cron'
    actor_id     UUID,
    resource_kind TEXT NOT NULL,                   -- 'order', 'account', 'tenant', etc.
    resource_id  CHAR(26),
    action       TEXT NOT NULL,                    -- 'created', 'updated', 'deleted'
    before       JSONB,                            -- prior state (NULL for create)
    after        JSONB,                            -- new state (NULL for delete)
    metadata     JSONB,                            -- request_id, IP, user-agent, etc.
    occurred_at  TIMESTAMPTZ NOT NULL,
    INDEX (tenant_id, occurred_at),
    INDEX (tenant_id, resource_kind, resource_id, occurred_at)
);
```

Append-only; never UPDATE or DELETE rows. Retention per regulation (typically 7 years for financial; 1-3 for general).

For compliance, hash-chain the rows (each row contains the hash of the prior row + its own content) so tampering is detectable. See `disaster-recovery.md` for the write-once tier.

### Versioning patterns

- **Soft delete:** `deleted_at TIMESTAMPTZ` column; queries filter; periodic vacuum.
- **Versioned rows:** Some tables have `version` column; updates increment; queries pick max version. Useful for slowly-changing dimensions.
- **Event sourcing:** State derived by replaying events. Use only for the parts of the system where the audit trail IS the source of truth (e.g., financial ledgers).

Default: soft delete + audit_events for state transitions. Don't event-source the whole system unless you have a specific reason.

## Time-series for hot data

Many products generate high-frequency events: prices, telemetry, clicks, transactions. Two-tier storage:

### Tier 1 — Timescale hypertables (Postgres extension)

```sql
CREATE TABLE ticks (
    tenant_id    UUID NOT NULL,
    symbol       TEXT NOT NULL,
    ts           TIMESTAMPTZ NOT NULL,
    bid          DECIMAL,
    ask          DECIMAL,
    -- ...
);
SELECT create_hypertable('ticks', 'ts', chunk_time_interval => INTERVAL '1 day');
SELECT add_dimension('ticks', 'tenant_id', number_partitions => 4);
```

- Partitioned by time (and optionally by tenant_id for parallel scans).
- Retention policy: drop chunks older than N days.
- Continuous aggregates: pre-compute hourly/daily roll-ups.

Default: keep last 7 days hot in Timescale; promote older data to OLAP tier.

### Tier 2 — OLAP (ClickHouse-class)

For analytics queries spanning weeks/months and large result sets, an OLAP store outperforms Postgres dramatically.

- Push from Timescale via a worker (continuous aggregate dumps + bulk loads).
- Schema flatter than OLTP — denormalized, columnar; sort by `(tenant_id, ts)`.
- Retention 90+ days; archive to cold tier beyond.

### Tier 3 — Cold archive (S3 + Parquet)

- Daily ETL from OLAP to Parquet files in S3 with partitioning by `tenant_id` and date.
- Queryable via Athena/Trino/DuckDB on demand; not real-time.
- Retention years; encryption at rest.

See `caching-and-storage.md` for the layering rationale and invalidation patterns.

## Settings, configurations, feature flags

Three classes of "data that controls behavior":

| Class | Where | Lifetime | Update path |
|---|---|---|---|
| **Settings** (per-resource cascading) | OLTP `settings` table | Long | UI/API; audited |
| **Config** (per-environment) | Vault / env vars at deploy time | Per-deploy | Deploy pipeline |
| **Feature flags** (runtime toggles) | Dedicated flag store (LaunchDarkly-class or self-hosted) | Hours-days | Operator/admin UI |

Keep them separate. Feature flags conflated with settings produces a settings table polluted with ephemeral toggles.

## Data export and tenant data portability

Every tenant has a right to export their data. Build the export pipeline early:

```
1. Tenant admin (or ops on their behalf) requests export.
2. Export worker queries tenant's tables (for cluster+ tier: their DB; for shared: filtered by tenant_id).
3. Output: ZIP of CSV/JSON files per resource kind, with a manifest.
4. Stored in a temporary S3 bucket; signed URL given to tenant; URL expires in 24h.
5. Audit log entry; export request and delivery both logged.
```

For tenants on regulated regimes, the export must be complete (every table they own) and consistent (point-in-time snapshot, not a sliding read).

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| `tenant_id` column missing on a tenant-scoped table | Cross-tenant queries possible by accident | Schema-level enforcement; CI check; RLS or per-tenant schema/DB |
| Sequential integer IDs in public APIs | Predictable; reveals ordering | ULIDs or UUIDs |
| One Postgres for all tenants of all tiers | The first tenant who needs `cluster` tier blocks the design | Tier-aware data plane; mix shared and per-tenant clusters |
| Auditing as triggers on every table | Schema changes break triggers; performance hit | Audit via outbox at the application level |
| Storing money as float | Rounding errors | DECIMAL(18,8) or higher; never float |
| One Redis per cluster, all tenants share | Memory pressure isolation fails; one tenant evicts another's keys | Per-tenant Redis at namespace+ tier; or partition keyspace explicitly |
| OLAP store as primary for hot reads | Latency too high for transactional reads | OLTP first; promote to OLAP for analytics |
| Time-series in vanilla Postgres tables | Bloats; vacuum churn; query slowness after months | Timescale hypertables OR a TS-native store (InfluxDB, QuestDB) |
| Backups untested | First failed restore is at the worst moment | Quarterly restore drills; document RPO/RTO |
| Settings table with TTL columns mixed in flag-style values | Cascade resolver gets confused; tooling diverges | Separate settings vs feature-flags |
| `deleted_at` set without preserving prior state | Auditors and customers can't reconstruct history | Audit-events table records the delete; soft-delete column shows current |

## Worked example — multi-tier data plane for a B2B SaaS

Setting: same B2B data platform from `multi-tenancy.md`. Three concurrent tiers in production.

Per-tenant pod (namespace+ tier):
- Postgres 15 + Timescale extension; ULID PKs; RLS off (per-tenant DB at cluster tier; for namespace tier, schema-per-tenant)
- Redis 7; per-tenant; ~256MB allocation; eviction allkeys-lru
- NATS JetStream; per-tenant; 7-day retention on streams; durable consumers
- engine + workers + 3 APIs

Shared:
- ClickHouse cluster, 6 nodes, sharded by `tenant_id`; replication factor 2
- Kafka, 3-broker cluster; topic per resource_kind; consumer groups per consumer
- S3: hot bucket (90 days), cold bucket (years), per-tenant prefix
- data-api + webhook-dispatcher

Schema highlights:
- `accounts (id, tenant_id, ...)` — RLS in shared_pod tier; per-schema in namespace; per-DB in cluster+
- `audit_events` hash-chained, 7-year retention
- `ticks` Timescale hypertable; 7-day hot retention; promote to ClickHouse daily
- `settings` cascade; resolver caches in Redis 60s

`OPEN:` markers:
- `OPEN: per-tenant Redis at namespace tier vs shared Redis with key prefix — decide by 50 paying tenants OR first tenant complains about cache pressure. Switch criterion: cache hit rate < 80% on shared OR p95 cache latency > 5ms. Owner: data-platform lead.`
- `OPEN: ClickHouse vs QuestDB for warm-tier analytics — decide at first paying tenant volume measurement. Default: ClickHouse. Switch: ClickHouse cluster cost > $X/mo OR query p99 > 5s on common analytics. Owner: data-platform lead.`

## Cross-references

- `multi-tenancy.md` — for tier-driven schema isolation choice
- `caching-and-storage.md` — for the L1/L2/warm/cold layering
- `messaging-and-events.md` — for the audit-events outbox pattern
- `api-design.md` — for the URN identifier wrapping of internal IDs
- `disaster-recovery.md` — for backup/restore policies per tier
- `compliance-and-ownership.md` — for audit-events retention and tamper-evidence
