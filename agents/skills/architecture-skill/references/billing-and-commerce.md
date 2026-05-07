# Billing and Commerce

> Loaded when designing the billing model: out-of-band vs in-app, usage tracking for invoice support, tier-based pricing matrices, per-product billing dimensions, "created" vs "active" carryover, what fields live in the platform DB.

## What this layer covers

How counterparties pay you, how end users pay counterparties (if applicable), how usage is tracked for invoice support, and what fields live where.

This layer has high architectural impact because billing decisions cascade through:

- The data model (what's tracked per tenant)
- The control plane (subscription_status drives feature gating)
- The customer-facing API (does the platform even handle end-user billing or is it the counterparty's domain?)
- Compliance (financial records retention; reconciliation)

## Two distinct flows

A B2B platform has two separate money flows:

| Flow | Direction | Architectural impact |
|---|---|---|
| **Counterparty ↔ platform** | Counterparty pays platform for the SaaS service | Subscription billing; tier-driven |
| **End user ↔ counterparty** | End users pay counterparty for the counterparty's product | Usually counterparty's PSP / banking; we may track for usage-based pricing |

These are separate concerns; conflating them is a category error.

## Counterparty ↔ platform: out-of-band vs in-app

Two patterns; pick deliberately and explicitly.

### Out-of-band billing (recommended default for B2B)

Counterparty subscription handled through traditional sales contract:

```
1. Sales call → contract negotiation (offline, non-platform)
2. Master Service Agreement (MSA) signed
3. Order Form specifies: tier, monthly fee, term, included capabilities
4. Counterparty pays via wire transfer / ACH / SEPA
5. Platform issues invoices through accounting (QuickBooks / Xero / similar) — no in-app invoice generation
6. Payment confirmation flows from accounting to platform ops via Slack/email
7. Backoffice operator manually flags `tenant.subscription_status` in control-plane DB
```

Why this works for B2B:

- Enterprise customers expect contracts, not subscribe buttons.
- Compliance teams of customers approve contracts, not third-party subscribe pages.
- Higher-value contracts justify the manual workflow.
- Avoids being a money-services-business under most jurisdictions.

What the platform DB tracks:

```sql
ALTER TABLE tenants ADD COLUMN subscription_status TEXT;
-- ACTIVE, PAST_DUE, GRACE_PERIOD, SUSPENDED, CANCELLED, ARCHIVED

ALTER TABLE tenants ADD COLUMN commercial_tier TEXT;
-- 'trial', 'self_serve', 'branded', 'dedicated', 'enterprise', 'on_prem_license'

ALTER TABLE tenants ADD COLUMN billing_cycle TEXT;
-- monthly | quarterly | annual

ALTER TABLE tenants ADD COLUMN contract_start_date DATE;
ALTER TABLE tenants ADD COLUMN contract_end_date DATE;
ALTER TABLE tenants ADD COLUMN last_payment_date DATE;
ALTER TABLE tenants ADD COLUMN next_invoice_date DATE;
ALTER TABLE tenants ADD COLUMN account_manager_id UUID;     -- our sales/CSM

CREATE TABLE tenant_subscription_audit (
    tenant_id   UUID,
    actor_id    UUID,
    action      TEXT,           -- payment_received, status_changed, etc.
    old_status  TEXT,
    new_status  TEXT,
    notes       TEXT,
    ts          TIMESTAMPTZ
);
```

The subscription_status drives feature gating: PAST_DUE may show a banner; SUSPENDED locks new actions; CANCELLED initiates offboarding.

### In-app billing (for self-serve / consumer-facing)

If the product is self-serve at the lowest tier (free trial → paid self-serve), in-app billing makes sense:

- Hosted-checkout payment processor integration (any major PSP that supports subscriptions).
- Customer enters card; subscribes to a plan.
- Webhooks from PSP update `subscription_status` automatically.
- Receipts and invoices auto-generated from PSP.

This is appropriate for shared_pod / namespace tiers where contracts are overhead. Higher tiers stay out-of-band.

### Hybrid (typical for tier-spanning products)

- shared_pod / namespace: in-app billing via a hosted-checkout PSP
- branded / dedicated / enterprise: out-of-band

The control-plane DB tracks both flows uniformly; the source of payment data differs.

## Pricing dimensions

A product's pricing model varies by what's expensive to serve. Common dimensions:

### Setup fee

One-time at onboarding per product line. Covers integration, branding, training, certification. Larger for higher tiers.

### Monthly base fee

Ongoing infrastructure + support. Per tenant. Scales by tier.

### Per-resource fees (storage, processing, throughput)

Charged based on what costs us:

- Per-account per month (when each account costs storage and ops)
- Per-event or per-million-events (when load drives cost)
- Per-GB stored per month
- Per-API-call (rare; usually included in tier)

### Usage-based dimensions

When the cost of serving is highly variable per tenant:

- Per-million events processed
- Per-GB ingested
- Per-active-user (as opposed to per-created-user)
- Revenue share (we get N% of certain revenue events)

### Per-feature add-ons

- Custom domain: $X/mo extra
- BYOK: $Y/mo extra
- Dedicated egress IP: $Z/mo extra
- 24/7 named CSM: $W/mo extra

## Tier matrix — concrete example

For a B2B SaaS:

| Tier | Setup | Monthly base | Per-account/mo (created) | Per-account/mo (active) | Per-million events | Custom domain |
|---|---|---|---|---|---|---|
| **T0 Trial** | $0 | $0 | $0 | $0 | $0 | No |
| **T1 Self-serve** | $2,500 | $500 | $0.50 | $5 | $0.10 | No |
| **T2 Branded** | $10,000 | $2,500 | $1.00 | $10 | $0.05 | Yes |
| **T3 Dedicated** | $25,000 | $7,500 | $0.50 | $5 | $0.05 (or unlimited above 100M) | Yes + dedicated infra |
| **T4 Enterprise** | $50,000+ | $15,000+ | negotiated | negotiated | negotiated | Yes + multi-region |
| **T5 On-prem** | $100,000+ | License $250k+/yr | bundled | bundled | bundled | Their domain |

Numbers are illustrative; tune to your unit economics.

## "Created" vs "Active" — carryover rules

For per-account billing, distinguish "created" from "active" and apply a carryover rule to prevent gaming and to align fees with sustained value.

### Definitions

**Created account:** a live account row exists in the tenant's DB at end of month, regardless of whether it transacted. Demo/test accounts excluded. Archived/closed accounts excluded after the month they were closed.

**Active in month M:** the account either:
- Performed at least one billable action during month M, OR
- Held an open position / active resource at any point in month M

**Billable as active in month M:** active in BOTH month (M − 1) AND month (M − 2). I.e. demonstrated **two consecutive prior months** of activity. The active fee then kicks in starting month M and continues for as long as the rolling 2-month streak holds.

### Why the carryover rule

- Prevents "test once, get billed" gaming (counterparty can't open accounts and run a single action just to say "we have N active users").
- Aligns the active fee to **sustained** value, not one-off engagement.
- Tenant gets a "free" first 2 months on every new account (only pays the small per-created fee during ramp).
- Matches reality: many accounts open, only some graduate to real use.

### Example timeline

| Month | State | Per-created? | Per-active? |
|---|---|---|---|
| Jan | Created, no activity | yes | no |
| Feb | Active (first event) | yes | no |
| Mar | Active (second consecutive month) | yes | no |
| Apr | Active (third month) — graduates | yes | **yes** ← active fee starts |
| May | Inactive (gap month) | yes | yes (already past streak; one gap allowed) |
| Jun | Inactive (second gap) | yes | no (streak broken; requires re-qualification) |
| Jul | Active again | yes | no (rebuilding streak) |

The streak check uses the prior two months. Once an account has graduated, it stays in active billing as long as either of the prior two months was active. Two full inactive months drop it back to created-only.

Demo accounts never charged on either component.

## Per-product billing dimensions

Products with multiple revenue lines (e.g., a platform that supports several distinct surfaces) bill per-line, not flatly:

| Product line | Setup | Monthly base | Per-created | Per-active | Per-million volume | Notes |
|---|---|---|---|---|---|---|
| **Surface 1** (full state load on us) | yes | yes | yes | yes | optional | Full data plane runs on our side |
| **Surface 2** (we route to external) | yes | yes | small | yes | strong default | Order-flow load is real; storage less |
| **Surface 3** (light integration, fee revshare) | yes (small) | yes (small) | no | no | n/a + revshare | Thin integration; revshare drives revenue |

Different surfaces have different cost-to-serve. A counterparty running multiple surfaces sees multiple line items per month.

## Usage tracking — for invoice support, not billing

Even for out-of-band billing, the platform tracks usage:

- **Active accounts per month** — for invoice line items and dispute resolution
- **Volume processed** (events / transactions / GB)
- **Compute cost allocated** (internal — not for invoice; for our unit economics)
- **Per-feature usage** (custom domain hits, BYOK rotations, etc.)

```sql
CREATE TABLE tenant_usage_monthly (
    tenant_id        UUID NOT NULL,
    month            DATE NOT NULL,             -- first of month
    accounts_created INTEGER NOT NULL DEFAULT 0,
    accounts_active  INTEGER NOT NULL DEFAULT 0,
    accounts_active_billable INTEGER NOT NULL DEFAULT 0,
    events_processed BIGINT  NOT NULL DEFAULT 0,
    storage_gb_avg   NUMERIC NOT NULL DEFAULT 0,
    compute_cost_internal NUMERIC NOT NULL DEFAULT 0,    -- our cost; for unit-econ
    PRIMARY KEY (tenant_id, month)
);
```

This table is the source of truth for invoice line items. Workers populate it monthly from the per-tenant DBs (cluster+ tier) or from filtered queries (shared tier).

## Revenue-share / commission models

When the platform earns a percentage of the counterparty's revenue (e.g., the counterparty processes payments through a vendor that pays us a referral; the counterparty's downstream provider offers a partner-fee program):

- Daily reconciliation worker pulls from the source.
- Aggregated per (tenant, source, period).
- Payout: counterparty gets their share via direct payment OR offset against next invoice (counterparty choice in contract).
- We retain platform's % (negotiated per contract).

Schema:

```sql
CREATE TABLE revenue_share_events (
    id          CHAR(26) PRIMARY KEY,
    tenant_id   UUID NOT NULL,
    source      TEXT NOT NULL,      -- which downstream paid this
    period      DATE NOT NULL,      -- billing period
    gross       NUMERIC NOT NULL,   -- gross revenue before split
    platform    NUMERIC NOT NULL,   -- our share
    counterparty NUMERIC NOT NULL,  -- their share
    payout_method TEXT,             -- direct / offset / pending
    payout_at   TIMESTAMPTZ,
    notes       TEXT
);
```

Documented in the contract. Reconcile monthly with the counterparty before payout.

## End user ↔ counterparty billing

This flow is **counterparty-domain** (per `compliance-and-ownership.md`). The counterparty:

- Operates their own PSP integration (any major payment service provider)
- Holds the merchant account
- Reconciles end-user transactions
- Files tax reports

What the platform may do:

- **Track end-user balances** in the per-tenant DB (the counterparty's source of truth for their accounting; we hold it for them).
- **Apply revenue splits** in custodial mode (we execute the split per their config; not our money flow).
- **Generate event streams** for their PSP / accounting (via webhook delivery).

What the platform DOESN'T do:

- Process end-user card payments
- Hold end-user funds in our merchant account
- File tax reports on the counterparty's behalf
- Issue refunds (counterparty does)

Document this boundary explicitly. Sales conversations often blur it.

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Single `tier` column for both pricing and infra | Collisions; locked to identity mapping | Split per `decision-discipline.md` |
| In-app billing for enterprise contracts | Procurement teams reject "subscribe" buttons | Out-of-band for higher tiers |
| Per-account fee without "created vs active" distinction | Counterparty gamed by opening unused accounts | Carryover rule + 2-month streak |
| Demo accounts billable | Counterparty can't onboard prospects | Demo accounts always free |
| Usage tracking only for invoice — not for unit econ | We don't know which tenants are unprofitable | Track compute cost internally too |
| Subscription status only in CRM | Engineering can't gate features | `subscription_status` in platform DB; CRM is source of truth, DB is replica |
| Manual invoice generation in code | Brittle; locked-in | Out-of-band invoice via accounting tool; platform DB tracks status only |
| Revenue-share without daily reconciliation | Disputes go stale; data drifts | Daily reconciliation worker; alert on drift |
| Platform processing end-user payments | Money-services-business obligations; counterparty's domain | Counterparty's PSP; platform doesn't touch the money |
| One pricing model across all products | Different products have wildly different cost-to-serve | Per-product billing dimensions |
| Tier features defined in code | Change requires deploy | Feature entitlements in DB; loaded at runtime |
| No graceful PAST_DUE behavior | Sudden cutoff alienates customers | Banner → grace period → SUSPENDED → CANCELLED with notice each step |

## Worked example — billing model for a B2B SaaS

Pricing model:

- T0 Trial (30 days free, then auto-converts to T1 unless contract signed)
- T1 Self-serve: $500/mo + $0.50 per created account + $5 per active account + $0.10 per million events
- T2 Branded: $2,500/mo + same per-account but waived setup; custom domain included
- T3 Dedicated: $7,500/mo + lower per-account; dedicated infra; SLA-backed
- T4 Enterprise: contract; negotiated
- T5 On-prem: license $250k+/yr; we ship + support

Billing flow:

```
1. Tenant signs up at app.platform.com (T0 trial)
2. Hosted-checkout PSP sets up subscription (T0 → T1 auto-convert at day 30 unless they cancel)
3. Higher tiers: sales conversation; contract; out-of-band wire
4. Backoffice flags subscription_status; commercial_tier; billing_cycle
5. Monthly worker computes usage:
   - tenant_usage_monthly populated from per-tenant DBs
   - active-account streak computed; billable count populated
6. Invoice generation:
   - T1: PSP auto-invoices
   - T2+: accounting tool generates from usage data
7. Payment received → status updated → next month begins
```

What's tracked in platform DB:

- `tenants.subscription_status` (drives feature gating)
- `tenants.commercial_tier`, `deployment_tier` (mapping per `multi-tenancy.md`)
- `tenants.contract_start_date`, `contract_end_date`, `last_payment_date`
- `tenant_usage_monthly` (per-month aggregates)
- `revenue_share_events` (where applicable)
- `tenant_subscription_audit` (every status change)

What's NOT in platform DB:

- PSP subscription details (PSP is source of truth for in-app billing)
- Bank account details (accounting tool's domain)
- Invoice PDF storage (accounting tool stores; platform links)
- End-user payments (counterparty's PSP domain)

`OPEN:` markers:
- `OPEN: in-app billing for T2 if a sales-cycle pattern emerges where contracts cost more than they earn for branded tier — switch when 30% of branded customers self-serve their procurement. Owner: revenue ops.`
- `OPEN: revenue-share with X downstream provider — currently 70/30 split; renegotiate at $1M ARR. Owner: BD.`

## Cross-references

- `multi-tenancy.md` — for commercial_tier vs deployment_tier separation
- `decision-discipline.md` — for tier-modeling discipline
- `data-plane.md` — for usage tracking schema
- `compliance-and-ownership.md` — for boundary between platform billing and end-user payments
- `operations-and-deployment.md` — for subscription_status as feature gate
