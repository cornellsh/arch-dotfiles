# Branding and Customization

> Loaded when designing the per-tenant branding pipeline: custom-domain provisioning, theme pipeline, per-counterparty artifacts, code-signing per counterparty, 4-eyes review.

## What this layer covers

For B2B platforms where counterparties present the product under their own brand:

1. **Custom domain provisioning** — counterparty points DNS at us; we serve their content under their hostname.
2. **Theme pipeline** — colors, logos, fonts, copy, favicons applied per counterparty.
3. **Per-counterparty artifacts** — branded UI builds, branded mobile/desktop apps, branded documentation.
4. **Code-signing per counterparty** — for products that ship signed binaries (desktop apps).
5. **Review workflow** — branding requires legal/brand approval before going live.

This layer commonly underspecified. Plan it explicitly — counterparties care about brand fidelity more than architecture.

## Custom domain provisioning

The counterparty's flow when they want `app.theirbrand.com` to serve our product:

```
1. Counterparty adds DNS CNAME:
     app.theirbrand.com → <generated>.platform-cdn.com
     
2. Counterparty calls Manager UI: Settings → Domains → Add domain
   → control-API: POST /tenants/<id>/domains {hostname: "app.theirbrand.com"}
   
3. control-API tells the Custom-Domain-SaaS CDN to provision the cert:
   → CDN issues ACME challenge (HTTP-01 or DNS-01)
   
4. CDN attempts validation:
   - HTTP-01: tries to fetch a token from the counterparty's hostname
     → succeeds if CNAME is propagated and our edge handles the well-known path
   - DNS-01: requires counterparty to add a TXT record (more complex; less common)
   
5. Validation succeeds → cert issued → cert in CDN's pool
   
6. control-API marks tenant.domains.<hostname>.status = active
   
7. Edge filter starts routing app.theirbrand.com → counterparty's tenant pod
   
8. Counterparty admin can now share the URL
```

Common failure modes and handling:

| Failure | Cause | Handling |
|---|---|---|
| ACME validation fails repeatedly | CNAME not propagated; or counterparty has CAA record blocking | Surface error in Manager UI; counterparty fixes DNS; retry |
| Counterparty domain on a blacklist | Domain has a bad reputation | CDN refuses; route to manual review |
| Cert renewal fails (60-90 days post-issuance) | CNAME removed by counterparty; ACME validation fails | Alert at 30 days remaining; page on-call at 7 days |
| Counterparty stops paying / leaves | Tier downgrade or offboarding | Domain removed from edge; cert deleted; counterparty notified |

Document this flow in the canonical doc; counterparty integration teams ask about it.

## Theme pipeline

Branding parameters per tenant — what gets customized:

```sql
CREATE TABLE tenant_branding (
    tenant_id          UUID PRIMARY KEY,
    -- Visual
    primary_color      TEXT,             -- hex
    secondary_color    TEXT,
    accent_color       TEXT,
    background_color   TEXT,
    text_color         TEXT,
    -- Logos & graphics
    logo_url           TEXT,             -- main logo, square or wide
    logo_dark_url      TEXT,             -- for dark backgrounds
    favicon_url        TEXT,
    splash_image_url   TEXT,
    -- Typography
    primary_font       TEXT,             -- font family name
    font_url           TEXT,              -- if custom hosted; otherwise system
    -- Copy
    product_name       TEXT,             -- e.g. our "Platform" → tenant's "AcmeApp"
    company_name       TEXT,
    support_email      TEXT,
    support_url        TEXT,
    privacy_url        TEXT,
    terms_url          TEXT,
    -- Custom domain
    custom_domain      TEXT,
    -- Status
    review_status      TEXT,             -- 'draft', 'pending_review', 'approved', 'live', 'rejected'
    reviewed_by        UUID,
    reviewed_at        TIMESTAMPTZ,
    last_modified_at   TIMESTAMPTZ,
    last_modified_by   UUID
);
```

Branding is **review-gated** — see "4-eyes review" below.

### Theme application

Two patterns:

### Runtime theming

The UI fetches the tenant's theme JSON at app boot; applies via CSS variables:

```javascript
// On app boot
const theme = await fetchTheme(tenantId);   // /api/branding from edge
applyCSSVariables({
  '--primary-color': theme.primary_color,
  '--logo-url': `url(${theme.logo_url})`,
  ...
});
```

Pro: zero rebuild per tenant; one binary serves all brands; theme changes apply on next refresh.
Con: counterparty's logo URL must be on a CDN; can't change the framework's deep customizations (component shapes, layouts).

### Per-tenant artifact (build-time)

We build a separate artifact per counterparty with their branding baked in:

```
1. CI pipeline triggered when branding approved
2. Build runs: npm run build -- --tenant=<id>
3. Build script reads tenant_branding table
4. Outputs: dist-tenant-<id>/ with branding applied at build time
5. Pushed to CDN with custom-domain SaaS routing
```

Pro: fully customized; logo and theme baked in; faster client-side load.
Con: expensive at scale; rebuild for every branding change; per-tenant CDN footprint.

The default for most products is **runtime theming**. Per-tenant artifacts only when:
- Counterparty needs a deeply-customized UI (different component shapes, not just colors)
- Counterparty needs a code-signed desktop binary
- Compliance requires the counterparty's logo to be the only brand visible (no platform branding even at boot)

## Per-counterparty desktop apps (Tauri-class / Electron-class)

For products that ship desktop binaries:

```
1. Counterparty's branding approved
2. Build pipeline runs:
   - Pull latest source code
   - Inject tenant branding at build time
   - Compile per platform (Win, macOS, Linux)
   - Code-sign with platform certificate (or counterparty cert in advanced cases)
3. Outputs: 
   - <tenant_short>-<platform>-<version>.dmg (macOS)
   - <tenant_short>-<platform>-<version>.exe (Windows)
   - <tenant_short>-<platform>-<version>.AppImage (Linux)
4. Upload to per-tenant download bucket
5. Tenant admin downloads, distributes via their own channels
```

Code-signing options:

- **Platform-owned cert** (default): we sign all counterparty binaries with our platform's cert. Counterparty's binary shows our company name in the OS dialog.
- **Counterparty-owned cert** (advanced): counterparty owns their cert (Apple Developer, EV cert for Windows); we use it to sign. Counterparty's binary shows their company name.

Counterparty-owned cert is operationally heavier — counterparty must rotate, we must securely store. Charge for it (per `billing-and-commerce.md` add-ons).

## Auto-update for desktop apps

Counterparty desktop apps need an update mechanism:

```
1. Apps poll an updater endpoint at startup: 
     GET https://updates.platform.com/<tenant_short>/latest
2. Updater returns latest version + signed manifest
3. App compares to current version; if behind, downloads + verifies signature
4. Restart applies update
```

Updater endpoint per tenant:

- Versioning: per-tenant; some tenants stay on older versions (LTS-style)
- Manifest signed with the same cert that signed the binary
- Rollback: tenant admin can pin an older version via Manager UI if a release is bad

## Mobile apps

For products that ship mobile apps:

| Approach | When |
|---|---|
| **PWA (web app installable)** | Default; lowest friction; same codebase as web |
| **One platform-owned mobile app** with tenant selector | When the platform itself is the brand and counterparties are sub-brands within |
| **Per-counterparty white-label mobile app** | When counterparties demand their own App Store presence |

Per-counterparty mobile apps are operationally heavy:

- App Store / Play Store account per counterparty
- Per-counterparty app review (Apple's review takes 1-7 days; submission per release per counterparty)
- Per-counterparty crash analytics
- Per-counterparty push notification setup

Avoid until a counterparty pays for it (enterprise tier add-on).

## Branding review workflow (4-eyes)

Branding is brand and legal-sensitive. Review-gate it.

```
1. Counterparty admin uploads branding (Manager UI: Settings → Branding)
2. Status: 'draft'
3. Counterparty admin clicks "Submit for review"
4. Status: 'pending_review'
5. Email sent to platform brand-review team
6. Brand reviewer (platform staff) reviews:
   - Logo quality and rights (counterparty must confirm they own/license it)
   - Color contrast accessibility (WCAG AA minimum)
   - Copy: terms/privacy URLs valid; support contact reachable
   - Trademark concerns (no impersonation of third parties)
7. Reviewer marks approved or rejected with comments
8. If approved: status → 'approved'; counterparty clicks "Go live"; status → 'live'
9. If rejected: status → 'rejected'; counterparty edits and resubmits
```

Why 4-eyes:

- Trademark misuse becomes our problem if we hosted it.
- Accessibility failures look bad on us.
- A legitimate-looking brand can be a phishing vector targeting their end users.

Audit log every branding change with reviewer ID and rationale.

### Self-service branding for trial / shared_pod tier

For T0/T1 tiers, the review overhead may not pay back. Two options:

- **Limited self-service:** colors + display name only; no logo upload (use platform logo).
- **Auto-approve for low-risk changes:** color picker + name within a whitelist of patterns.

Document the per-tier review policy.

### Self-serve branding tier (at scale)

At ~50+ counterparties, the review queue becomes an ops bottleneck. Introduce self-serve branding for trusted counterparties (cluster+ tier) with light auto-checks:

- Logo dimensions / file size validation
- Color contrast auto-check
- Trademark scan via vendor service
- Auto-approve if all checks pass; flag for human review if any fail

`OPEN:` marker in the canonical doc: *"At ~50 counterparties the 4-eyes branding workflow becomes ops bottleneck; introduce self-serve branding for cluster+ tier at that threshold."*

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Branding in code; deploy to change | Counterparty waits for engineering to ship a logo | DB-driven; runtime theming or build pipeline |
| No review workflow | Bad logos / accessibility failures / trademark issues | 4-eyes review gate |
| Same review process for trial and enterprise | Ops drowns at trial scale | Tier-driven; self-serve / auto-approve at low tiers |
| Counterparty-owned cert without secure storage | Cert leaks → forged binaries | Vault per-counterparty; access logged |
| Manual binary signing | Doesn't scale; missed releases | Automated build + sign pipeline |
| Branding pipeline outside of CI | Drift; manual intervention | All branding builds in CI/CD |
| No auto-update for counterparty desktop apps | Stale apps; security drift | Updater endpoint per tenant; signed manifests |
| Counterparty-owned App Store apps without strict ROI test | Months of ops burden per counterparty | Charge enough; reserve for enterprise tier |
| Custom-domain provisioning manual | Counterparty admin waits for ops | API-driven via control-plane; automated ACME |
| Cert renewal silent on failure | Outage at expiry | Alert at 30/7 days remaining |
| Theme JSON cached aggressively | Counterparty changes appear hours later | TTL ≤ 5 minutes for branding; or invalidate on update |
| One review queue for all counterparties | Bottleneck under load | Per-tier queues; SLA per tier |
| Branding fields in code-deployable config | Branding becomes deploy-coupled | DB-driven; reload-able |

## Worked example — branding pipeline for a B2B SaaS

Two-mode pipeline:

### Mode 1 — Runtime theming (default; T1 / T2)

```
1. Counterparty admin uploads logo (PNG/SVG, <1MB) via Manager UI
2. Logo stored in per-tenant S3 prefix; URL recorded in tenant_branding
3. Color picker for primary/secondary/accent; product name and copy fields
4. Submit for review
5. Brand-review team approves (or rejects with comments)
6. Status → live; theme JSON published to CDN
7. UI fetches theme on boot; applies via CSS variables
```

### Mode 2 — Per-counterparty desktop builds (T3 / T4)

```
1. Same branding upload + review
2. CI pipeline triggered on approval:
   - Pull source
   - Inject branding at build time
   - Build per platform (mac/win/linux) using Tauri-class framework
   - Code-sign with platform cert (or counterparty cert if T4 add-on)
   - Upload to per-tenant download bucket
3. Tenant admin distributes binaries
4. Auto-update endpoint per tenant: updates.platform.com/<short>/latest
```

Custom-domain provisioning (concrete steps):

```
1. Counterparty enters "trade.acme-corp.com" in Manager UI
2. control-API records hostname; status=pending_dns
3. UI shows: "Add CNAME: trade.acme-corp.com → cname.platform-cdn.com"
4. Counterparty adds CNAME via their DNS provider
5. Counterparty clicks "Verify DNS" in Manager UI
6. control-API checks CNAME via DNS lookup; if propagated, advances
7. control-API requests cert from custom-domain SaaS CDN
8. CDN does ACME HTTP-01 challenge
9. On success, status=active; UI shows "Domain live"
10. Edge starts routing trade.acme-corp.com → tenant's pod
```

Review workflow:

- Trial / self-serve: colors + name self-service; logo upload requires review
- Branded / dedicated: full review for all branding changes
- Enterprise: dedicated brand reviewer; SLA 24h

`OPEN:` markers:

- `OPEN: counterparty-owned cert as a billing add-on — currently not offered. Add at $X/mo when first counterparty asks. Owner: revenue ops.`
- `OPEN: per-counterparty mobile apps — currently PWA only. Build per-counterparty native app pipeline if first counterparty pays $Y for it. Owner: same.`
- `OPEN: self-serve branding for cluster+ tier — at 50 counterparties the manual review queue becomes a bottleneck; build auto-checks + auto-approve. Owner: brand-review lead.`

## Cross-references

- `multi-tenancy.md` — for tier-driven branding offering
- `edge-and-routing.md` — for custom-domain SaaS CDN routing
- `operations-and-deployment.md` — for Tenant Operator provisioning branding artifacts
- `billing-and-commerce.md` — for branding-related add-ons (custom domains, counterparty cert, mobile)
- `compliance-and-ownership.md` — for trademark and brand-rights ownership (counterparty's domain)
