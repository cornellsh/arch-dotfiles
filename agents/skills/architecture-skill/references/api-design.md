# API Design

> Loaded when designing the public API surface: identifiers, idempotency, exposure tiers, public-vs-internal enum collapse, decimal money, WS reconnect protocol, OpenAPI deliverable, error code taxonomy, two-auth pattern.

## What public-API design covers

The public API is the contract between the platform and external integrators. It must be:

1. **Smaller than the internal model** — internal richness collapsed deliberately at the boundary.
2. **Stable** — versioned; breaking changes follow a documented deprecation cycle.
3. **Retry-safe** — every state-changing endpoint is idempotent on a caller-supplied key.
4. **Predictable** — consistent identifier scheme, error taxonomy, response shape.
5. **Documented** — OpenAPI 3.x spec generated from the implementation; SDKs derived from the spec.

Everything in this layer is a counterparty-visible commitment. Changes are expensive.

## Three exposure tiers

Every endpoint lives in exactly one tier. Network rules and auth schemes follow.

| Tier | Audience | Hostname pattern | Auth | Network |
|---|---|---|---|---|
| **Public** | End users (browser, mobile, bot) | `app.platform.com`, `api.platform.com`, custom domain `app.<tenant>.com` | OAuth2 bearer (UI) or API key (bot) | Edge-exposed; rate-limited; WAF |
| **Counterparty-facing** | Programmatic integrations from named counterparties (their backend / CRM) | `live-<tenant>.api.platform.com` | OAuth2 client_credentials per counterparty | Edge-exposed at known subdomain; allowlisted; per-tenant audited |
| **Internal** | Other services in the same cluster | `*.svc.cluster.local` | mTLS or service-mesh identity | Cluster-internal only; no public route |

Discipline:

- Every service declares its tier in a single line of config.
- Internal services have no public route — enforced by network policy (fail-closed), not by code conditional.
- Counterparty-facing endpoints have per-counterparty rate limits, audit logs, credential rotation policy.
- Public endpoints are documented externally; internal endpoints aren't.

## Identifier scheme — URN format

Every resource uses a URN-formatted identifier visible to end users, bots, and counterparties:

```
urn:<namespace>:<type>:<ulid>
```

Examples (with a generic `pf` namespace):

| Resource | URN form | Example |
|---|---|---|
| User | `urn:pf:user:<ulid>` | `urn:pf:user:01H8XAYZ7B3K0M9NQRSTV5W6X7` |
| Tenant | `urn:pf:tenant:<ulid>` | `urn:pf:tenant:01H8XB0...` |
| Account | `urn:pf:account:<ulid>` | `urn:pf:account:01H8XB1...` |
| Order | `urn:pf:order:<ulid>` | `urn:pf:order:01H8XB2...` |
| Position | `urn:pf:position:<ulid>` | `urn:pf:position:01H8XB3...` |

Properties:

- **Type-prefixed.** Reader can tell a user from an order at a glance. Reduces "wrong-id-type" bugs.
- **ULID body.** 26-character base32; sortable by creation time; URL-safe.
- **Namespace-rebrandable.** Counterparties may rebrand the prefix in their OpenAPI export ("urn:acme:..." instead of "urn:pf:...") via a single config setting; internally the platform always speaks the canonical namespace.
- **Server-generated.** Never trust client-generated identifiers as the canonical primary key. Caller supplies only `intent_id` (idempotency).

Why ULID over UUID:

- 26 chars vs 36 (with hyphens). Shorter URLs.
- Lexicographically sortable by creation time. Useful for log correlation, pagination by id, debugging.
- URL-safe by default (no hyphens or underscores; pure base32-Crockford).
- Native generation libraries in every language.

Why type prefix:

- "Wrong type passed" failures fail-fast at request validation instead of cascading into wrong queries.
- Logs and tickets are scannable: `urn:pf:order:...` is obviously an order.

## Idempotency via caller-supplied keys

Every state-changing endpoint accepts a caller-supplied idempotency key (call it `intent_id` to disambiguate from the server-generated resource id):

```json
POST /accounts/<account_id>/orders
{
  "intent_id": "01H8XB2A3B4C5D6E7F8G9H0J1K",
  "exchange": "primary",
  "type": "limit",
  "side": "buy",
  "asset": "X",
  "quantity": "0.001",
  "price": "62500.00"
}
```

Server semantics:

- Caller generates `intent_id` (ULID) before sending.
- Server stores `(account_id, intent_id) → response` in Redis with 24-hour TTL.
- Re-submission with the same `intent_id` returns the original response (200/201 with the previously created resource), no side effects.
- Different request body with the same `intent_id` returns `409 Conflict — intent_id reused for a different request`.
- After 24 hours, a fresh request creates a new resource (rare; documented).

Discipline:

- `intent_id` is mandatory for state-changing endpoints (POST, PUT, PATCH, DELETE).
- Read endpoints don't need it.
- Document the retention window clearly. Counterparties build retry logic around it.

## Account-scoped endpoints

Most endpoints are scoped to an account:

```
GET    /accounts/<account_id>/orders
POST   /accounts/<account_id>/orders
GET    /accounts/<account_id>/orders/<order_id>
POST   /accounts/<account_id>/orders/<order_id>/cancel
GET    /accounts/<account_id>/positions
GET    /accounts/<account_id>/trades
GET    /accounts/<account_id>/settings/<key>
PUT    /accounts/<account_id>/settings/<key>
```

Auth flow at every call:

1. Edge or service introspects token; gets `user_id` + `tenant_id` + scopes.
2. Service validates URL `tenant_id` matches token `tenant_id`. (Defense against token-from-A used on URL-from-B.)
3. Service fetches `account_link(user_id, account_id)`; verifies the user owns or has role on this account.
4. Service checks scope against endpoint requirement (e.g., `write:order` for POST orders).
5. Service proceeds.

Cross-account operations are forbidden at the public API. If a counterparty needs to act on multiple accounts, they make multiple calls.

## Public-API enum collapse

The internal model has rich state. The public API exposes a smaller, stable enum.

### Example pattern

| Internal state (rich) | Public value | Why collapse |
|---|---|---|
| `mode_a_funded_real` | `live` | Caller cares about real-vs-paper, not internal routing |
| `mode_b_paper_audit` | `paper` | Same |
| `mode_c_paper_unaudited` | `paper` | Same |
| `mode_d_test_only` | `paper` | Same |
| `mode_e_partner_routed` | `live` | Same |
| `mode_f_specialized_routing` | `live` | Same |

Six internal states, two public values. Internal evolution doesn't break consumer integrations.

### Order status — practical example

```
Public statuses:
  pending → open → partially_filled → filled
  pending → rejected
  open → cancelled
  open → expired
```

Internal lifecycle has more states (e.g., `pending_validation`, `pending_routing`, `awaiting_venue_ack`, `risk_check_in_progress`). All collapse to `pending` at the public API. The richness exists for ops dashboards, not for counterparties.

### Discipline

1. The mapping table is in the API reference, exact and up to date.
2. Adding a new internal state requires picking which public value it maps to *before* the change ships.
3. The public enum is part of the API contract; changes follow deprecation cycle.
4. The internal enum can change every release.

## Decimal money — never floats

Monetary values, quantities of fungible items, and any cumulative value where small precision errors accumulate must be represented as decimal strings:

```json
{
  "amount": "199.99",
  "currency": "USD",
  "quantity": "0.000001",
  "fee_rate": "0.000150"
}
```

Reason: floats round in surprising ways. `0.1 + 0.2 != 0.3`. Once a rounding error enters the data, it propagates and can cascade into billing disputes.

Implementation guidance per language (in the API reference):

- TypeScript / JavaScript: `BigNumber` (bignumber.js) or `decimal.js`
- Python: `Decimal` (stdlib)
- Rust: `rust_decimal`
- Go: `shopspring/decimal`
- Java: `BigDecimal` (stdlib)

Apply to:

- Money (always)
- Quantities of physical/inventory items (when fractional matters)
- Probabilities, rates, fractions in financial/actuarial computations
- Anything cumulative summed millions of times

Don't apply to:

- Latency / timing (floats fine)
- Statistics for display (means, percentiles)
- Coordinate systems

## Error code taxonomy

A consistent error taxonomy makes integrations easier and reduces support burden. Two layers:

### Layer 1 — HTTP status codes (standard)

| Code | When |
|---|---|
| 200 | Read success / mutation success returning state |
| 201 | New resource created |
| 204 | Mutation success with no return body |
| 400 | Bad request — body invalid, missing required field |
| 401 | Authentication missing or invalid |
| 403 | Authenticated but not authorized |
| 404 | Resource not found |
| 409 | Conflict — `intent_id` reused for different request, or version conflict |
| 422 | Unprocessable entity — semantic validation failure (e.g., insufficient balance) |
| 429 | Rate limit exceeded |
| 500 | Server error — fault on our side |
| 503 | Service unavailable — load shedding or maintenance |

### Layer 2 — Body error code

Every 4xx/5xx response includes a body with a stable error code:

```json
{
  "error": {
    "code": "insufficient_balance",
    "message": "Account balance 100.00 is less than required 250.00",
    "details": {
      "account_id": "urn:pf:account:01H8XB1...",
      "available": "100.00",
      "required": "250.00"
    },
    "request_id": "01H8XB2A3B..."
  }
}
```

Standard error codes (extend per product):

| Code | HTTP | When |
|---|---|---|
| `unauthenticated` | 401 | No / invalid credential |
| `unauthorized` | 403 | Authenticated but lacks scope/role |
| `not_found` | 404 | Resource doesn't exist OR caller can't see it (don't leak existence) |
| `validation_failed` | 400 | Body malformed |
| `intent_reused` | 409 | `intent_id` reused for different content |
| `insufficient_balance` | 422 | Balance/quota check failed |
| `out_of_range` | 422 | Value outside allowed range |
| `rate_limited` | 429 | Per-tier rate limit exceeded |
| `internal_error` | 500 | Unhandled server-side failure |
| `temporarily_unavailable` | 503 | Maintenance window or load shedding |

Document every code in the OpenAPI spec with examples. Counterparty SDKs can then generate enum types and exhaustive switch statements.

## WebSocket / streaming reconnect protocol

Real-time feeds need a documented reconnect contract.

### Recommended default: at-most-once + REST snapshots as authoritative

1. **Heartbeat.** Server pings every 20s; client must pong within 10s. Dead connections terminate.
2. **Reconnect.** Client uses exponential backoff with jitter: initial 1s, cap 30s.
3. **Resumption semantics.** No server-side replay buffer. On reconnect, client refetches state via REST snapshot endpoints. Authoritative state lives in REST + audit log.
4. **Subscribe.** On reconnect, client re-subscribes to the channels it cared about.

This is the simplest design and avoids replay-buffer operational burden.

### Alternative: server-side replay buffer (when REST snapshots are too expensive)

1. Server maintains last N seconds (e.g., 60s) of events per connection family.
2. Reconnecting client sends `last_seen_event_id`; server replays from that cursor.
3. Buffer evicts after N seconds; if client missed too long, falls back to snapshot.

Use only when REST snapshot cost is prohibitive (e.g., high-resolution market data with millions of subscribers).

### Wire format example

```
Client → Server (subscribe):
  {"op": "subscribe", "channels": ["account.<id>.orders", "account.<id>.positions"]}

Server → Client (event):
  {"channel": "account.<id>.orders", "event": "order.filled", "data": {...}, "occurred_at": "2026-01-01T12:00:00Z"}

Server → Client (heartbeat):
  {"op": "ping", "ts": 1709136000}

Client → Server (heartbeat ack):
  {"op": "pong", "ts": 1709136000}
```

Document the contract in the OpenAPI spec (or AsyncAPI for streaming).

## Two-auth pattern: bearer + API key

Most products end up with two complementary auth schemes for the public API:

| Scheme | Audience | Format | Lifetime |
|---|---|---|---|
| Bearer (OAuth2) | Interactive UI | `Authorization: Bearer <jwt>` | 30min access; 30d sliding refresh |
| API key | Programmatic clients | `X-API-Key: pk_live_<random>` OR `Authorization: Bearer pk_live_<random>` | Long, until rotated |

Same identity behind both. Same scopes. Different operational profiles.

For counterparty backend → our REST API: OAuth2 client_credentials with per-counterparty `client_id`/`client_secret`.

Pick **one** of `Authorization: Bearer` or `X-API-Key:` for API keys; document; stick with it. (`Authorization: Bearer pk_...` is more standard and works with off-the-shelf HTTP libraries.)

## Pagination

Cursor-based, not offset-based:

```
GET /accounts/<id>/orders?limit=100&cursor=<opaque>
```

Response:

```json
{
  "data": [...],
  "next_cursor": "01H8XB2..." // or null if no more
}
```

The cursor is opaque to the client (typically the ULID of the last row + a direction). Counterparty SDKs treat it as a black box.

Why cursor over offset:

- Stable under inserts/deletes mid-iteration (offset-based skips or duplicates).
- O(1) per page (offset gets slow at deep pages).

Default page size: 100. Cap: 1000.

## OpenAPI 3.x deliverable

The API reference is generated from the OpenAPI spec, not hand-written. The spec is the contract:

```
spec/
  openapi.yaml             # OpenAPI 3.0.3 — full spec
  schemas/                 # split for maintainability
    Order.yaml
    Account.yaml
    ...
  examples/                # request/response examples per endpoint
    place-order.yaml
    cancel-order.yaml
```

Discipline:

- Every endpoint, request body, response body, error code in the spec.
- CI runs schema validation; PRs that break the spec without a deprecation are rejected.
- SDK generation runs from the spec; ensures the SDK matches the API exactly.
- The doc site is generated from the spec (Redocly, Swagger UI, etc.).

## API versioning

Two patterns:

### URL-based versioning

```
/v1/accounts/...
/v2/accounts/...
```

Pro: clear; clients pick a version explicitly.
Con: every breaking change is a major version bump; many versions live in parallel.

### Header-based versioning

```
GET /accounts/...
Accept-Version: 2026-01-01
```

Pro: continuous evolution; clients pin to a date.
Con: more nuanced versioning logic on the server; harder to test.

Recommendation: **URL versioning for major shape changes; minor changes are additive (new fields, new endpoints) and don't require a version bump.** A breaking change is a major version. Plan to support 2 major versions in parallel for at least 12 months when you bump.

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Public API mirrors internal model 1:1 | Every internal change breaks consumers | Collapse internal richness at the boundary |
| Sequential integer IDs in URLs | Predictable; reveals ordering | ULIDs with type prefix |
| No `intent_id` on POST endpoints | Network retries duplicate orders/charges | Caller-supplied `intent_id`; 24h server retention |
| Server-generated IDs as the only retry-correlation | First-request retry can't recover the original ID | Caller `intent_id` carries continuity |
| Float for monetary fields | Rounding errors accumulate | Decimal strings |
| 200 response for failures | SDKs can't distinguish | Use HTTP status correctly; body has detail |
| Generic 500 for all server errors | Counterparty has no actionable signal | Body code (`internal_error`, `temporarily_unavailable`, etc.) |
| Long-lived bearer tokens for bots | Theft window grows | API keys for bots; bearer for UI |
| Streaming endpoint with no reconnect contract | Every counterparty reinvents reconnection | Documented heartbeat + backoff + resumption |
| Offset pagination for unbounded resources | Slow at depth; unstable under writes | Cursor pagination |
| OpenAPI spec hand-edited and drifts from code | Counterparty SDKs lag reality | Spec generated from code OR code generated from spec; CI enforces parity |
| Versioning by header without clear rules | Servers and clients silently disagree | URL versioning for breaking; additive evolution otherwise |
| Internal taxonomy in error codes | Consumer code couples to internal evolution | Stable taxonomy; map internal failures to external codes |
| `next_cursor: ""` instead of `null` | Defensive coding burden in consumers | `null` for end-of-collection; consistent across endpoints |
| HMAC without timestamp | Replay attacks possible | Always include timestamp; reject if > 5min old |
| Cross-account operations in one call | Authorization complexity; partial-failure semantics | One account per call; counterparty issues parallel calls |

## Worked example — order submission API for a B2B platform

Endpoint: `POST /accounts/<account_id>/orders`

Request:

```json
{
  "intent_id": "01H8XB2A3B4C5D6E7F8G9H0J1K",
  "exchange": "primary",
  "product_type": "perp",
  "type": "limit",
  "side": "buy",
  "position_side": "long",
  "time_in_force": "GTC",
  "asset": "XYZ",
  "quantity": "0.001",
  "price": "62500.00",
  "reduce_only": false,
  "close_position": false
}
```

Headers:

```
Authorization: Bearer <token>
Content-Type: application/json
```

Successful response (201 Created):

```json
{
  "order": {
    "order_id": "urn:pf:order:01H8XB2A3B...",
    "intent_id": "01H8XB2A3B4C5D6E7F8G9H0J1K",
    "account_id": "urn:pf:account:01H8XB1...",
    "exchange": "primary",
    "asset": "XYZ",
    "type": "limit",
    "side": "buy",
    "status": "pending",
    "quantity": "0.001",
    "price": "62500.00",
    "cumulative_quantity": "0",
    "cumulative_quote": "0",
    "created_at": "2026-01-01T12:00:00.123Z"
  }
}
```

Failure cases:

| Body shape | HTTP | When |
|---|---|---|
| `validation_failed` | 400 | Missing `intent_id`; invalid `quantity` (not a decimal); etc. |
| `unauthenticated` | 401 | Missing or invalid token |
| `unauthorized` | 403 | Token tenant ≠ account tenant; or scope missing `write:order` |
| `not_found` | 404 | account_id doesn't exist OR caller can't see it |
| `intent_reused` | 409 | `intent_id` reused for a different body |
| `insufficient_balance` | 422 | Account balance below required margin |
| `out_of_range` | 422 | `quantity` below min lot size |
| `rate_limited` | 429 | Tier rate limit exceeded |
| `internal_error` | 500 | Unhandled server failure |

Idempotency: re-POSTing the same `intent_id` within 24h returns 201 (or 200) with the original order's body, no second order created.

Documented in OpenAPI; SDK generated; counterparty integration team builds against the spec.

`OPEN:` markers:

- `OPEN: cursor-pagination format — currently using ULID-of-last-row + direction; consider opaque base64 if a future feature needs multi-key cursors. Switch when first such feature surfaces. Owner: API team lead.`
- `OPEN: WebSocket replay buffer — currently at-most-once + REST snapshots. Add server-side buffer if first counterparty complains that REST snapshots are too expensive at their volume. Owner: API team lead.`

## Cross-references

- `identity-and-auth.md` — for the bearer + API key + client_credentials patterns
- `edge-and-routing.md` — for rate-limiting buckets and tier-based budgets
- `messaging-and-events.md` — for webhook delivery contract (the async-API counterpart of this REST contract)
- `data-plane.md` — for ULID PKs and decimal money in the schema
- `decision-discipline.md` — for compile-time over runtime + abstraction negative space
- `multi-tenancy.md` — for tenant-scoped exposure tiers
