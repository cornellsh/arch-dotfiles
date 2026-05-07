# Messaging and Events

> Loaded when designing the message-passing layer: command vs event bus, internal broker (NATS-class) vs external streaming bus (Kafka-class), the outbox pattern, idempotency contract, fan-out, retry semantics, webhook delivery.

## Two distinct buses

A non-trivial product has two distinct message buses with different responsibilities:

### Internal command/event bus (per-tenant)

NATS-class or RabbitMQ-class:

- **Commands** (request-reply or fire-and-forget) — service-to-service within the tenant pod
- **Internal events** (within-tenant fan-out) — engine emits, workers consume
- **Sub-second latency** at sub-1KB messages
- **Retention** — short (hours-days); not the source of truth
- **Per-tenant** at namespace+ tier; per-pod isolation

### External streaming bus (cross-tenant, shared)

Kafka-class or Redpanda-class:

- **Outbound to counterparty webhooks** — events fanned out to counterparty CRMs
- **Cross-tenant analytics ingest** — feed OLAP loaders
- **Long retention** (days-weeks; replayable)
- **Strong ordering per partition**
- **Shared infrastructure** with topic/consumer-group isolation

Don't conflate them. Commands belong on the internal bus; durable, replayable events belong on the external bus.

## Why two buses

Mixing them produces failure modes:

- Putting commands on Kafka inflates retention costs and adds latency.
- Putting durable events on NATS without persistence loses them on broker restart.
- Subscribing the webhook dispatcher directly to NATS couples per-tenant brokers to the cross-tenant fan-out — a tenant outage breaks webhook delivery for everyone.

The boundary: the **outbox pattern** transfers events from per-tenant bus to shared streaming bus.

## The outbox pattern

The single most important pattern in this layer.

```
                                ┌─────────────────────────────────────┐
                                │  Per-tenant pod (Postgres + worker) │
                                │                                     │
   1. service writes to DB ─────┼─> orders                           │
                                │     UPDATE / INSERT                 │
                                │                                     │
   2. same transaction          │  outbox                             │
      writes outbox row ────────┼─> INSERT (event_id, payload, ts)    │
                                │                                     │
   3. transaction commits ──────┼─> COMMIT                            │
                                │                                     │
   4. outbox-shipper worker     │  worker tails outbox table           │
      polls outbox ─────────────┼─> SELECT … WHERE shipped_at IS NULL │
      ships to Kafka ───────────┼─> kafka.produce(topic, payload)     │
                                │                                     │
   5. on success, mark shipped ─┼─> UPDATE outbox SET shipped_at = NOW()
                                └─────────────────────────────────────┘
```

Why this works:

- **Atomicity.** The outbox row commits in the same transaction as the domain change. If the DB commits, the event will be sent (eventually). If the DB rolls back, the event isn't sent.
- **At-least-once delivery.** The shipper retries until success; consumers must dedupe on `event_id`.
- **Decoupling.** The application doesn't care whether the broker is up; the outbox absorbs the buffer.
- **Replayable.** Events are in the DB until shipped; on broker outage, they wait. After the outage, they ship.

Schema:

```sql
CREATE TABLE outbox (
    event_id        CHAR(26) PRIMARY KEY,           -- ULID
    tenant_id       UUID NOT NULL,
    aggregate_kind  TEXT NOT NULL,                   -- 'order', 'account', etc.
    aggregate_id    CHAR(26) NOT NULL,
    event_kind      TEXT NOT NULL,                   -- 'order.created', 'account.updated', etc.
    payload         JSONB NOT NULL,
    occurred_at     TIMESTAMPTZ NOT NULL,
    shipped_at      TIMESTAMPTZ,                     -- NULL until shipped
    ship_attempts   INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX outbox_unshipped ON outbox (occurred_at) WHERE shipped_at IS NULL;
```

Shipper worker:

- Polls every ~1s; takes a small batch (100-1000 rows).
- Produces each to Kafka in order (per aggregate_id, to preserve ordering).
- Increments `ship_attempts`; on permanent failure (e.g., serialization error), moves to a DLQ table.
- After N successful shippings, mark `shipped_at`. (Two phases: ship → mark, with idempotent-produce-key in Kafka so retries don't dupe.)

## Idempotency in the consumer

Every consumer of the external bus MUST dedupe. Two patterns:

### Pattern 1 — Idempotency key in the message

Producer sets a unique key per message (Kafka headers; or `event_id`). Consumer maintains a deduplication store: "I've processed event X."

For long retention windows: a Postgres table `consumed_events (consumer_name, event_id, processed_at)` with index, partitioned by month for retention.

### Pattern 2 — Idempotent business logic

The action itself is idempotent: setting status to "settled" twice is the same as once. Order with the same intent_id can't create two orders.

When possible, prefer this pattern; consumer dedup state is then a backup, not the only line of defense.

## Webhook delivery

The webhook-dispatcher consumes the external bus and POSTs to counterparty webhook URLs.

### Delivery contract

What we promise counterparties:

1. **At-least-once delivery.** Each webhook may arrive more than once; counterparty must dedupe on `event_id`.
2. **Ordering per `aggregate_id`.** Events for the same order/account arrive in order.
3. **Retry with exponential backoff.** Initial delay 1s; cap 5 minutes; up to 24 hours total.
4. **Signed headers.** HMAC-SHA256 of body using a shared secret per counterparty + timestamp + nonce.
5. **Timeout.** We give the counterparty 10 seconds to respond with 2xx; otherwise treat as failure and retry.
6. **Dead-letter after 24 hours.** If still failing, move to a DLQ; counterparty alerted.

What we DON'T promise:

- Real-time delivery — 1-30 second latency is normal.
- Exactly-once — counterparty handles dedup.
- Ordering across `aggregate_id`s — only per-aggregate ordering.
- Indefinite retry — 24 hours is the cap.

### Schema for tenant-configured webhook endpoints

```sql
CREATE TABLE tenant_webhooks (
    id              CHAR(26) PRIMARY KEY,
    tenant_id       UUID NOT NULL,
    url             TEXT NOT NULL,
    event_kinds     TEXT[] NOT NULL,         -- which event_kinds this URL receives
    signing_secret  TEXT NOT NULL,           -- in Vault, not this column; this is a reference
    active          BOOLEAN NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    INDEX (tenant_id)
);

CREATE TABLE webhook_delivery_attempts (
    id              CHAR(26) PRIMARY KEY,
    webhook_id      CHAR(26) NOT NULL,
    event_id        CHAR(26) NOT NULL,
    attempt_n       INTEGER NOT NULL,
    status_code     INTEGER,
    latency_ms      INTEGER,
    error_message   TEXT,
    attempted_at    TIMESTAMPTZ NOT NULL,
    INDEX (webhook_id, attempted_at)
);
```

The `webhook_delivery_attempts` table is observability for both us and the counterparty. The Manager UI shows recent deliveries with status; useful when a counterparty asks "did event X reach my endpoint?"

### Webhook security headers

Standard set:

```
X-Platform-Signature: hmac-sha256=<hex>
X-Platform-Signature-Timestamp: 1709136000
X-Platform-Event-Id: <event_id>
X-Platform-Event-Kind: order.created
X-Platform-Tenant-Id: <tenant_id>
X-Platform-Delivery-Attempt: 3
```

Counterparty verifies by computing HMAC over `<timestamp>.<body>` with the shared secret and comparing to header. Timestamp prevents replay attacks (reject if > 5 minutes old).

### Backpressure

If a counterparty's endpoint is slow or failing, we don't want it to back up the dispatcher and affect other counterparties. Patterns:

- **Per-tenant consumer groups.** Each tenant has its own Kafka consumer group; one tenant's failures don't block others.
- **Per-tenant queue depth limits.** If a tenant's queue exceeds N messages, pause delivery and alert.
- **Concurrent in-flight limits per tenant.** Cap the number of concurrent in-flight POSTs to a tenant's URL (e.g., 10).

## Internal command bus patterns

For the per-tenant internal bus:

### Request-reply (RPC over message bus)

```
service-A publishes 'tenant.<id>.command.foo' with reply-to header
service-B (subscriber on that subject) receives, processes, publishes to reply-to
service-A awaits reply with timeout
```

Use NATS request-reply or RabbitMQ direct-reply-to. Don't try to build this on Kafka.

### Fire-and-forget command

```
service-A publishes 'tenant.<id>.command.bar' with no reply-to
service-B processes; emits event when done
```

Useful when the caller doesn't need a synchronous response.

### Fan-out within a tenant

```
engine emits 'tenant.<id>.event.order_filled'
worker-1 (records to DB), worker-2 (sends notifications), worker-3 (updates dashboards)
each subscribed independently
```

Use a streaming subject (NATS JetStream stream, RabbitMQ topic exchange) so consumers can replay if they restart.

## Ordering guarantees

Per partition / per aggregate, events are ordered. Cross-partition, no order is guaranteed.

To preserve order for a logical entity (an order, an account):

- Partition the topic by `aggregate_id`.
- All events for one aggregate land on one partition.
- One consumer (or one consumer-group member) processes that partition.
- Order is preserved.

Anti-pattern: trying to enforce global ordering across all events. Doesn't scale; not needed in practice. Per-aggregate ordering is what business logic actually requires.

## Retention and replay

Internal bus (NATS-class):
- Streams retain hours-days; replay is for catch-up after a worker restart, not for archive.

External bus (Kafka-class):
- Topic retention 7-30 days; long enough for consumers to catch up after extended outages, short enough to control storage cost.
- For longer retention (audit, compliance), the events also flow to a durable archive (see `caching-and-storage.md` cold tier).

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Direct service-to-service HTTP calls without backoff | Cascading failures; tight coupling | Async via internal bus; circuit breakers |
| Writing to broker without outbox | DB commit succeeds, broker write fails → lost event | Outbox pattern |
| One Kafka topic for everything | Schema drift; consumer scope creep; partitioning impossible | Topic per resource_kind or per logical event family |
| Global ordering enforcement | Throughput collapses | Per-aggregate ordering only |
| Webhook dispatcher inline with the API request | Counterparty's slow endpoint blocks our API | Async via outbox; never inline |
| Webhook delivery without HMAC | Counterparties can't verify; receivers attackable | HMAC always; timestamp + nonce |
| Indefinite webhook retry | DLQ never drains; storage bloat | 24-hour cap; explicit DLQ; counterparty alert |
| One Kafka consumer group for all tenants | One tenant's slow consumer slows others | Per-tenant consumer groups for tenant-scoped flows |
| Consumer not idempotent | Replay or retry duplicates side effects | Dedup on `event_id` in consumer state OR idempotent business logic |
| Mixing commands and events on the same bus | Latency-sensitive commands compete with replayable event traffic | Two buses |
| Outbox shipper batch too big | Long DB transactions; replication lag | Cap batch at 100-1000 rows; tune to throughput |
| Retention longer than legal-hold + audit need | Storage cost out of control | Match retention to actual need; archive to cold tier |

## Worked example — outbox + webhook fan-out for a B2B platform

Per-tenant pod:

```
1. Engine processes a customer action; writes order row + outbox row in one TX
2. Outbox shipper polls every 1s; takes up to 1000 unshipped rows
3. Produces each to shared Kafka, topic "orders" partitioned by tenant_id+order_id
4. Marks shipped_at on success
```

Shared infrastructure:

```
5. Webhook dispatcher consumes "orders" topic, partitioned per consumer group:
   - one consumer group per tenant
   - looks up tenant's webhook URL(s) for event_kind
   - signs + POSTs with 10s timeout
   - retries with exponential backoff up to 24h
   - logs delivery attempt to webhook_delivery_attempts
6. OLAP loader consumes "orders" topic, batches into ClickHouse
7. Audit-archive worker consumes "audit" topic, writes to S3 Object Lock
```

Per-tenant guarantees:

- At-least-once delivery to webhooks
- Per-order ordering preserved
- 24h max retry; DLQ + alert beyond
- HMAC-signed; timestamp + nonce against replay

What we tell the counterparty in API docs:

> *Webhook delivery is at-least-once. Your endpoint MUST be idempotent on `X-Platform-Event-Id`. Order is preserved within a single `aggregate_id` (e.g., all events for one order arrive in order). Cross-aggregate ordering is not guaranteed. We retry on non-2xx responses with exponential backoff up to 24 hours, after which the event is moved to a dead-letter queue and you are alerted via email.*

`OPEN:` markers:

- `OPEN: webhook signing scheme — current HMAC-SHA256; consider Ed25519 if a counterparty requires asymmetric verification. Switch on first such ask. Owner: API team lead.`
- `OPEN: Kafka cluster size — start at 3 brokers; scale to 6 if topic write throughput exceeds 50% sustained capacity for 7 consecutive days. Owner: shared-infra lead.`

## Cross-references

- `data-plane.md` — for the outbox table schema and audit-events
- `caching-and-storage.md` — for cold-archive of events from external bus
- `api-design.md` — for the WebSocket reconnect protocol (real-time fan-out alternative)
- `disaster-recovery.md` — for broker durability and cross-region replication
- `operations-and-deployment.md` — for per-tenant brokers vs shared brokers
