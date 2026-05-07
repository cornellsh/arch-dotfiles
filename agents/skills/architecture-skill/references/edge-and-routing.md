# Edge and Routing

> Loaded when designing the edge layer: TLS, custom-domain SaaS, anycast TCP, DDoS/WAF, edge filters, request-level routing, rate limiting.

## What the edge layer does

The edge layer is the first hop after the public internet. It owns:

1. **TLS termination** for all public hostnames (platform-owned + counterparty custom domains).
2. **Routing** — which backend service handles the request, based on hostname / path / header / token.
3. **DDoS mitigation and WAF** — drop bad traffic before it reaches expensive services.
4. **Rate limiting** — per-IP, per-credential, per-tenant, per-endpoint-class.
5. **CDN** for static assets where applicable.
6. **Tenant identification** — extract `tenant_id` from hostname or header before routing to per-tenant services.
7. **TCP-level proximity** for latency-sensitive APIs (anycast).

What it does NOT do:
- Authentication beyond initial token shape validation (auth happens at the service).
- Business logic (filters live at the service).
- Tenant authorization (RBAC happens at the service).

## The four-component pattern

A typical edge stack has four components:

```
                 ┌──────────────────┐
                 │   Public DNS     │
                 └────────┬─────────┘
                          │
    ┌─────────────────────┼─────────────────────┐
    │                     │                     │
┌───▼────────┐    ┌───────▼──────┐      ┌───────▼─────────┐
│ CDN/SaaS-  │    │  Anycast TCP │      │   Direct DNS    │
│ for-domains│    │  accelerator │      │   (legacy/test) │
│ (UI assets │    │  (latency-   │      │                 │
│  + custom  │    │  sensitive   │      │                 │
│  domains)  │    │  API low RTT)│      │                 │
└───┬────────┘    └───────┬──────┘      └───────┬─────────┘
    │                     │                     │
    └─────────────────────┼─────────────────────┘
                          │
                  ┌───────▼─────────┐
                  │  Edge proxy +   │
                  │  WASM/Lua filter│
                  │  (tenant-id     │
                  │   extraction,   │
                  │   routing)      │
                  └───────┬─────────┘
                          │
                  ┌───────▼─────────┐
                  │  Backend service│
                  │  (per tenant or │
                  │   shared)       │
                  └─────────────────┘
```

## Component classes (named, with default recommendations)

### CDN / Custom-Domain SaaS

For UI assets and counterparty-custom-domain hosting:

| Class | What it does | Default recommendation |
|---|---|---|
| **Custom-domain SaaS CDN** (e.g., the multi-tenant CDN-with-custom-domain pattern) | Counterparty points their CNAME at our SaaS host; SaaS provisions TLS via ACME automatically; routes to our origin | Default for any product where counterparties bring their own domain |
| **Self-managed CDN with cert-manager** | We run the CDN; provision certs via ACME-DNS challenge per counterparty | Only if SaaS is unavailable or the product needs CDN-level customization the SaaS doesn't expose |
| **Direct origin** (no CDN) | TLS at the load balancer | Internal/admin tooling only; never for public counterparty traffic |

The default for any multi-tenant B2B product where counterparties have brand domains is **custom-domain SaaS CDN**. Self-managing certs at scale (50+ counterparties) is operational overhead that doesn't pay back unless SaaS's restrictions block a real requirement.

### Anycast TCP accelerator

For latency-sensitive APIs (real-time data feeds, low-latency RPC, gaming, real-time collaboration):

| Class | What it does | When |
|---|---|---|
| **Anycast TCP accelerator** | Single global hostname; user's TCP connection lands on the nearest edge POP; backhaul to origin via cloud backbone | Latency-sensitive APIs where ~50-100ms savings matters |
| **Geo-DNS** | DNS resolves to the nearest origin; user goes direct | Sufficient for most APIs |
| **Single-region** | One hostname, one origin region | MVP; small user base |

The accelerator is paid; the ROI shows up only when latency matters at the connection-establishment layer (lots of short connections, mobile networks with high RTT, geographically distant users). For batch APIs and slow async workflows, geo-DNS is fine.

### Edge proxy with programmable filter

The proxy class (envoy-class, NGINX-class, HAProxy-class) handles request-level decisions. The programmable filter (WASM, Lua, or vendor-specific scripting) extracts the tenant identifier and chooses the backend.

Required filter responsibilities:

1. **Tenant extraction:**
   - From hostname (`<tenant>.platform.com` or counterparty custom domain via reverse mapping)
   - From request header (`X-Tenant-ID` for non-browser clients)
   - From subject claim of a presented token (after token introspection at the edge OR forwarded to service)
2. **Routing:**
   - To the per-tenant backend pod (for dedicated tiers) OR shared pod (for shared tier) — based on tenant's `deployment_tier` in a fast lookup table
3. **Pre-flight checks:**
   - Country geofence: drop requests from sanctioned IPs at the edge (cheap)
   - Rate limit lookup: per-IP / per-token / per-tenant / per-endpoint-class
4. **Logging metadata** — emit `tenant_id`, `request_id`, `client_country`, `auth_kind` for observability

The filter does NOT:
- Validate tokens cryptographically (forward to identity service)
- Make authorization decisions (forward to backend service)
- Modify request bodies beyond header injection (filter complexity grows quadratically with body parsing)

### Rate limiting

Apply at multiple scopes simultaneously:

| Scope | Default budget | Action on breach |
|---|---|---|
| Per IP, all endpoints | 1,000 req/min | 429 with retry-after |
| Per token (bearer or API key), all endpoints | 1,200 req/min | 429 |
| Per tenant, write-class endpoints | per-tier (see below) | 429 |
| Per tenant, read-class endpoints | per-tier (see below) | 429 |
| Per endpoint-class (e.g. login) | 60 attempts per 15 min per IP | 429; account lockout after threshold |

Per-tier examples (concrete numbers; tune on observation):

| Commercial tier | Read req/min | Write req/min |
|---|---|---|
| Trial | 60 | 30 |
| Self-serve | 600 | 200 |
| Branded | 3,000 | 1,000 |
| Dedicated | 12,000 | 4,000 |
| Enterprise | negotiated SLA | negotiated SLA |

Document the budgets per tier in the public API reference. Counterparties can plan their integration around them.

### WAF rules

Default ruleset:

- Block IPs from sanctioned countries (cloud-vendor managed list, refreshed daily).
- Block well-known scanner User-Agents (curl/wget allowed; sqlmap/nmap not).
- Reject requests with malformed headers (CRLF injection, etc.).
- Cap body size at the edge (1MB default for JSON; document larger limits per-endpoint).
- Per-tenant additional restrictions configurable via control plane.

WAF "smart" rules (SQL-injection signatures, XSS, etc.) — enable in monitor-only mode first, observe false-positive rate, promote to block-mode only after a quiet week.

## Tenant-routing strategies

The edge needs a fast (sub-millisecond) lookup of `tenant_id → backend pod or service` for every request. Three patterns:

### Pattern 1 — Hostname-based (simple)

`*.platform.com` → tenant is the subdomain. `app.<tenant>.com` → reverse-map via Custom-Domain-SaaS API. Edge filter does the lookup against a Redis or in-memory cache (refresh every minute).

Pro: simple; no token parsing needed.
Con: API tokens can't carry tenant scope; bot tokens have to be tenant-bound.

### Pattern 2 — Token-claim-based

The token (bearer or API key) carries a `tenant_id` claim. The edge introspects (cached) and routes accordingly.

Pro: tokens can carry tenant scope; one token, one tenant.
Con: token introspection cost; cache complexity.

### Pattern 3 — Hybrid (recommended default)

Hostname for browser-driven UI traffic; token-claim for programmatic API traffic. The edge tries hostname first; falls back to token introspection if hostname is generic (`api.platform.com`).

This is the default for products that serve both UI (where hostnames carry tenant brand) and bots (where hostnames are uniform `api.platform.com`).

## Custom-domain provisioning

The flow when a counterparty wants `app.theirdomain.com`:

```
1. Counterparty adds DNS CNAME: app.theirdomain.com → <provided>.platform-cdn.com
2. Counterparty calls our control-API: POST /tenants/:id/domains
3. Control-API tells the Custom-Domain-SaaS CDN to provision the cert (ACME)
4. CDN attempts ACME challenge (HTTP-01 or DNS-01); fails if CNAME isn't propagated
5. Counterparty retries; CDN provisions; cert appears in our cert pool
6. Edge filter starts routing app.theirdomain.com to the counterparty's tenant pod
7. Edge router records the mapping in the hostname → tenant_id lookup
```

Failure modes:

- CNAME not propagated → ACME fails, retry available; surface to counterparty in Manager UI.
- Counterparty domain blacklisted → CDN refuses; route to manual review.
- Cert renewal fails → SaaS auto-retries; alert at 7 days remaining; page on-call at 48 hours.

Document this flow in the canonical doc; counterparty integration teams will ask.

## Internal vs public exposure

The edge **only routes public-tier services**. Internal services (identity-api, tenant-operator, control-api, vault, broker, observability) MUST NOT have a public route. Enforce via:

1. Network policy: internal services accept ingress only from named service accounts within the cluster.
2. Edge config: no listener for internal hostnames; no path mapping that could leak internal services.
3. Periodic audit: scan edge config for any path that resolves to an internal service.

Common failure: an "internal" service gets exposed temporarily for debugging, expiry-stamp is set verbally instead of in config, exposure becomes permanent. Fix: every edge exposure has an expiry timestamp in config; CI pipeline rejects configs with `expires_at` in the past or > 30 days in the future.

## Observability at the edge

Every request gets metadata stamped:

- `request_id` — UUID; propagated to backend services
- `tenant_id` — from the lookup (or `unknown` if pre-routing)
- `auth_kind` — `bearer | api_key | none`
- `client_country` — from IP geo
- `client_ip` — preserved in `X-Forwarded-For` chain
- `route_decision` — which backend was chosen
- `edge_pop` — which edge POP handled the request

Emit to the observability stack with `tenant_id` as a primary label so per-tenant dashboards work without filtering noise.

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Authentication at the edge | Edge becomes a giant stateful service | Auth at the backend; edge does only token-shape validation |
| Body parsing at the edge for routing | Filter complexity explodes; latency rises | Route on headers/path/hostname; never on body |
| Per-tenant edge configuration files | At 50+ tenants, ops drowns | Tenant routing via lookup table fed by control-API; one edge config |
| Auto-renew certs without alerting | When ACME fails silently, you find out at expiration | Alert at 7-day countdown; page at 48h |
| Internal services with `if not internal then 403` | Defense in depth fails when "internal" is misclassified | No public listener; rely on network policy as primary defense |
| Rate-limit budgets in code | Tuning requires deploy | Budgets in config; reload-able; per-tier from control plane |
| Anycast accelerator before measuring need | Pays for latency you don't need | Benchmark first; add accelerator when measured RTT > X for your geography |

## Decision framework — choosing edge components

For each new edge feature:

1. Is the feature about routing/auth/limits/safety? → edge.
2. Is it business logic? → backend service.
3. Is it cross-cutting and stateful? → suspect; reconsider whether edge is the right home.
4. Will it scale to N tenants? Test at 10x current.
5. What's the failure mode if the edge is unavailable? Document.

## Worked example — multi-tenant analytics SaaS edge

Topology:

- Cloudflare for SaaS (or equivalent custom-domain SaaS CDN) for `app.<tenant>.com` and `dashboards.<tenant>.com`
- Direct DNS for `api.platform.com` (counterparty bots, no custom domains)
- Anycast TCP accelerator for `live.api.platform.com` (real-time WebSocket feeds)
- Envoy at origin with WASM filter that:
  - Maps custom domain → tenant_id via a lookup table (refreshed from control-API every 60s)
  - Forwards `X-Tenant-ID` header to backend
  - Applies per-tenant rate limits looked up from Redis (TTL 60s)
- Per-tenant pod selection via Kubernetes service routing (deployment_tier=`namespace`+) or shared pod selection (deployment_tier=`shared_pod`)

Failures planned for:

- CDN outage → fall back to direct DNS for the platform-owned hostname; counterparty custom domains fail open (their integration breaks; ours doesn't)
- Anycast accelerator outage → fall back to geo-DNS; document increased latency in runbook
- Origin Envoy panic → second region's Envoy takes over via DNS failover (60-second TTL)

## Cross-references

- `multi-tenancy.md` — for the tenant-routing lookup table and tier-aware backend selection
- `identity-and-auth.md` — for token introspection vs JWT validation at the edge
- `api-design.md` — for the rate-limit-class taxonomy
- `operations-and-deployment.md` — for edge config under GitOps; cert renewal observability
- `compliance-and-ownership.md` — for geofencing as us-mandatory
