# Identity and Auth

> Loaded when designing the identity/auth layer: who logs in, with what credential, with what session lifetime, with what authorization scope, across which surfaces.

## What identity owns

The identity service is the single source of truth for:

1. **Users** (humans), **service principals** (bots, integrations), **counterparty admins** (operators of a tenant).
2. **Credentials** — passwords (with MFA), bearer tokens, API keys, signed-message proofs.
3. **Sessions** — active token lifecycles, refresh, revocation.
4. **Authorization scopes** — what a token can act on, expressed as scopes/claims/RBAC roles.
5. **Account linkage** — when one human has multiple accounts across surfaces (e.g., browser session + bot key + counterparty role), the linkage lives here.

What identity does NOT own:
- **Authorization decisions** — services decide what an authenticated principal can do; identity just confirms who they are and what scopes they hold.
- **Tenant data** — tenant resources live in tenant DBs.
- **Counterparty-driven identity verification (KYC-style)** — that's the counterparty's compliance program.

## The four credential classes

Most products end up with four credential classes, addressing four different surfaces:

| Class | Used by | Lifetime | Recovery |
|---|---|---|---|
| **Bearer (OAuth2)** | Interactive UI sessions (browser, desktop, mobile) | Short (minutes-to-hours); refresh token | Re-login or refresh |
| **API key** | Programmatic clients (bots, scripts, server-to-server) | Long (until rotated) | Rotate via UI |
| **Signed-message** (cryptographic challenge-response) | Non-account-bound flows | Per-action; nonce-bound | None — stateless |
| **Service-credentials (OAuth2 client_credentials)** | Service-to-service or counterparty backend (CRM) → our API | Token-based; refreshable | Rotate client_secret |

Both bearer and API key carry the same identity model behind them — same scopes, same RBAC. They differ in operational properties (theft-window, rotation cost, where they're stored).

## OAuth2 / OIDC patterns

Three flows account for ~95% of needs:

### Authorization Code with PKCE (interactive UI)

- Browser/Tauri/mobile sign-in.
- User redirects to identity provider; signs in; provider redirects back with auth code.
- Backend exchanges code for tokens.
- PKCE prevents code interception attacks on public clients (mobile, SPA).

### Refresh Token rotation

- Refresh tokens are single-use; exchanging a refresh token returns a new access + new refresh.
- Detect reuse: if the same refresh token is presented twice, the entire session family is revoked (signals theft).

### Client Credentials (service-to-service or counterparty backend)

- Two-leg flow: client presents `client_id` + `client_secret`; server returns access token.
- Scoped to the counterparty's tenant. Scopes are negotiated at credential creation, not at token request.
- Tokens are typically short-lived (1 hour); the client refreshes.

## API key format and lifecycle

Concrete recommendation:

- Format: `pk_live_<random>` for production keys, `pk_test_<random>` for sandbox/test keys (where `pk_` indicates "platform key" or similar branding; `live`/`test` is the environment).
- Length: 32+ random bytes (URL-safe base64 → ~43 chars).
- Visibility: shown ONCE at creation; we store only a hash + last 4 chars for display.
- Header: `Authorization: Bearer pk_live_...` OR `X-API-Key: pk_live_...` — pick one, document, stick with it.
- Rotation: new key issued; old key valid for a 7-day overlap window; alert if old key is still in use at the 5-day mark.
- Revocation: immediate (next request fails). Cache the deny list at the edge with 60s TTL.
- Audit: every key creation / rotation / revocation is logged with actor + reason.

Storage: hash with a constant-salt + per-key salt (e.g., bcrypt or argon2id). Key validation: parse prefix → look up by id (or last-4) → verify hash. Sub-millisecond lookups via Redis cache (TTL 60s; revoke pushes to cache invalidate).

Tier-based rate limits per key — see `edge-and-routing.md`.

## Multi-Factor Authentication (MFA)

Default policy:

- **TOTP** (RFC 6238) — first-class; users scan QR with authenticator app.
- **WebAuthn / passkeys** — preferred where supported (phishing-resistant); offer alongside TOTP.
- **Email/SMS OTP** — fallback only; not primary. SMS is vulnerable to SIM swap.
- **Recovery codes** — generated at MFA setup; one-time use; printed/saved by user.

MFA is mandatory for:
- Tenant admin accounts (Manager UI access)
- Platform staff accounts (Backoffice access)
- API key creation actions (require MFA at the moment of creation, even if session was established earlier)

MFA is optional for:
- End-user customer accounts (counterparty's policy choice; we provide the rails)

Enforcement happens at the identity service; the bearer token issued after MFA carries an `amr` claim listing which factors were used. Services check `amr` for sensitive operations.

## Session model

Concrete defaults:

| Property | Value |
|---|---|
| Access token lifetime | 30 minutes |
| Refresh token lifetime | 30 days (sliding window — each use extends) |
| Idle timeout (no activity) | 24 hours (force re-login) |
| Absolute timeout | 30 days (force re-login regardless of activity) |
| Concurrent sessions per user | unlimited by default; surface "active sessions" in user settings; per-tenant policy can cap |
| Session revocation | immediate (deny list cached at edge with 60s TTL) |

Tokens carry: `sub` (user_id), `tenant_id` (if tenant-scoped), `scopes` (array), `amr` (auth methods), `iat` (issued at), `exp` (expiry), `jti` (token id, for revocation). Use signed JWT (RS256) — inspect at the service without round-tripping to identity for every request. Short lifetime + jti deny-list = quick revocation.

## Multi-surface identity

A common product property: one human has multiple accounts across surfaces.

- Browser UI session at `app.platform.com`
- Counterparty admin role at `manager.tenant-x.com`
- API key for their bot
- Cryptographic identity (signed-message credential) for an alternate flow

The identity service models this as:

```
identity_user (1) ──── (N) credentials
                  │
                  └──── (N) account_links

account_link:
  user_id          uuid    (the human)
  tenant_id        uuid    (which tenant they have a relationship with)
  role             text    (their role in that tenant: admin, member, end_user, etc.)
  account_kind     text    (counterparty_admin, counterparty_member, end_user, ...)
  account_uuid     uuid    (the per-tenant account ID inside the tenant DB)
  linked_at        ts
  status           text    (active, pending, revoked)
```

This lets one user navigate across tenants without re-authenticating, and lets services answer "is this user authorized for this tenant_id?" via a fast lookup.

## Service exposure of the identity service

**The identity service is INTERNAL ONLY.** It must not have a public route.

| Caller | How |
|---|---|
| Identity portal frontend (e.g., `id.platform.com`) | Backend talks to identity service via mTLS within the cluster |
| Public API services (customer-API, counterparty-API) | Token introspection via mTLS-authenticated calls; cached results |
| Counterparty backend (CRM) | Through the public counterparty-API which mediates; never directly to identity |

Why: identity is the highest-value target. Direct public exposure expands attack surface unnecessarily. All access goes through services that have rate-limited, audited, scope-checked endpoints.

NetworkPolicy enforces: identity service accepts ingress only from named service accounts; egress to identity DB only.

## Account linkage and merging

When a user authenticates with a new credential class (e.g., they had an email account, now they want to add an API key), the linkage flow:

1. User authenticates via existing credential (proving they own the user_id).
2. User initiates new credential creation (within Settings).
3. New credential is bound to the same `user_id`.
4. Audit log records: actor, action, IP, user-agent, timestamp.

Two users discovering they're the same person (rare; usually after an organizational change) require a manual merge by platform staff with audit and double-confirm. Don't automate this; the failure mode of automated merge is catastrophic (data leak between unrelated users).

## Scope and RBAC

Scopes are coarse; RBAC is fine.

- **Scopes** carried in the token; checked at the API edge for endpoint-class authorization (e.g., `read:account`, `write:order`, `admin:tenant`).
- **RBAC roles** stored in the tenant DB; checked at the service for resource-level authorization (e.g., "can this user modify this specific account?").

Default scope set:

| Scope | Grants |
|---|---|
| `read:profile` | Read user's own profile |
| `read:account` | Read accounts the user owns |
| `write:account` | Modify accounts the user owns (orders, positions, settings) |
| `read:tenant` | Read tenant-level data (admin) |
| `write:tenant` | Modify tenant-level data (admin) |
| `admin:tenant` | Tenant admin operations (RBAC, branding, settings) |
| `admin:platform` | Platform staff operations |

Custom scopes per product as needed; document each in the API reference.

## Geographic and country considerations

- **Geofencing** at the edge (per `edge-and-routing.md`) blocks sanctioned countries before identity is even reached.
- **Country of residence** stored on the user; tenant policy may require country whitelist (e.g., counterparty-X only allows users from EU).
- **Data residency** — for users whose data must reside in specific regions, the user record may need region pinning. This is rare and tier-driven; default is global storage with cross-region replication.

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Identity service exposed publicly | High-value target; large attack surface | Internal only; mediated by API services |
| Long-lived access tokens (days) | Theft window grows; revocation lags | 30-minute access + rotating refresh |
| Same credential for UI and bots | Bots get long-lived bearers (theft risk) or UIs get API keys (poor UX) | Two-credential pattern: bearer for UI, API key for bots; same identity behind both |
| Storing API keys plaintext | Database breach = total compromise | Hash with bcrypt/argon2id; show key once at creation |
| MFA optional for tenant admins | Phished admin = tenant takeover | Mandatory for admin classes; optional for end users |
| Authorization decisions at identity | Identity becomes a giant policy engine; latency rises | Authentication at identity; authorization at services |
| Session timeouts not enforced | Stolen session token works forever | Idle + absolute timeout; revocation cache |
| Account-link manual merging automated | Identity confusion = data leak | Manual review; double-confirm; audit log |
| Token format embeds tenant in `sub` | Tenant change = user_id change = data orphaned | `sub` is user; `tenant_id` is a separate claim |
| Scopes too fine-grained ("read:order_id_123") | Scope explosion; tokens become huge | Coarse scopes for API edge; fine RBAC at service |

## Worked example — three-surface identity

Setting: a B2B platform with three user-facing surfaces — counterparty admin UI, end-user UI, counterparty backend (CRM) integration.

Identity model:

```
identity_user — one row per human
  ├─ credential[] — their auth methods (password+MFA, API key, etc.)
  └─ account_link[] — their relationships
       ├─ {tenant: A, role: counterparty_admin}    ← they manage tenant A
       ├─ {tenant: A, role: end_user}              ← they're also a user of tenant A's product
       └─ {tenant: B, role: end_user}              ← they're a user of tenant B's product

counterparty_service_principal — one row per counterparty backend integration
  └─ credential — OAuth2 client_credentials for tenant A's CRM
```

Auth flows:

| Flow | Credential | Where |
|---|---|---|
| Counterparty admin signs into Manager UI | Bearer (after password+MFA) | `manager.<tenant>.com` |
| End user signs into product UI | Bearer (after password+MFA-optional) | `app.<tenant>.com` |
| Counterparty CRM calls our REST API | OAuth2 client_credentials | `live-<tenant>.api.platform.com` |
| End user's bot calls product API | API key | `api.platform.com` |
| All identity-service internal calls | mTLS-authenticated service principals | cluster-internal only |

Authorization at the service:

```
customer-api receives a request with bearer token
  → introspect token (cached); get user_id, tenant_id, scopes
  → check scope against endpoint requirement (read/write/admin)
  → check tenant_id matches the URL's tenant
  → fetch account_link for (user_id, tenant_id)
  → check role allows the action (RBAC)
  → proceed with request handling
```

Common failure mode: services that skip the `tenant_id` check assume the token's tenant binds the request. An attacker with a valid token for tenant A can then request data from tenant B if the URL allows. Defense: every service-side authorization includes the `tenant_id` from the URL/path, not from the token.

## Cross-references

- `edge-and-routing.md` — for token-based routing and edge-level rate limiting
- `multi-tenancy.md` — for per-tenant identity scoping and counterparty-admin model
- `api-design.md` — for the two-credential pattern at the API surface
- `compliance-and-ownership.md` — for the audit log of identity operations
- `operations-and-deployment.md` — for identity service exposure (internal only) and NetworkPolicy
