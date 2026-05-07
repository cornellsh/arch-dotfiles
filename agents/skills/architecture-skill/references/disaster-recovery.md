# Disaster Recovery and Durability

> Loaded when designing backups, restore, cross-region replication, write-once audit, restore drills, key management, right-to-be-forgotten.

## What this layer commits to

The DR layer answers concrete operational questions:

1. **How much data can we lose** in a disaster? (RPO — Recovery Point Objective)
2. **How long can we be down** in a disaster? (RTO — Recovery Time Objective)
3. **How often do we test the restore?** (Restore drill cadence)
4. **What's immutable?** (Audit logs, compliance evidence)
5. **What can be deleted on request?** (PII; right-to-be-forgotten)
6. **Who holds the keys?** (KMS topology; key rotation)
7. **What's our response procedure** for each disaster scenario?

These are tier-driven decisions. Different tenants get different RPO/RTO based on what they pay for.

## RPO / RTO targets per tier

Concrete defaults; tune to your product and SLA commitments:

| Deployment tier | RPO | RTO | Replication strategy |
|---|---|---|---|
| `shared_pod` | 24 hours | 8 hours | Daily snapshots; same-region; standby DB |
| `namespace` | 4 hours | 4 hours | Hourly snapshots + WAL streaming; same-region replica |
| `cluster` | 15 minutes | 1 hour | Continuous WAL streaming; same-region sync replica + cross-region async |
| `region` | 5 minutes | 30 minutes | Cross-region async replica; documented failover runbook |
| `on_prem` | tenant-defined | tenant-defined | Tenant operates; we ship + support |

What "RPO" means concretely: in a complete region failure, the most recent N minutes/hours of data may be unrecoverable. Customers must be told this in their SLA.

What "RTO" means concretely: time from disaster declaration to service restored, including DNS propagation, replica promotion, application restart. Includes humans in the loop.

## Postgres backup strategy

For each Postgres cluster (shared or per-tenant):

### Three backup classes

| Class | Frequency | Retention | Recovery use |
|---|---|---|---|
| **Continuous WAL** | Real-time | 30 days | Point-in-time recovery (PITR) to any second in window |
| **Daily snapshots** | Daily, 02:00 UTC | 35 days | Quick restore to a known-good day |
| **Long-term archives** | Monthly | 7 years | Compliance / regulatory restore |

WAL streamed to object storage (S3-class). Snapshots taken via cloud-vendor managed snapshot APIs OR `pg_basebackup` for self-hosted.

### Encryption at rest

- All backups encrypted with KMS-managed keys.
- Per-tenant DEKs (data encryption keys) for cluster+ tier; KMS holds the wrapping key.
- Backup-restore tests verify decryption works (the test is "we restored and read the data," not just "we ran pg_restore without error").

### Cross-region replication

- WAL replicated to a second region's object store with 5-minute target lag.
- Snapshots copied cross-region weekly; daily for cluster+ tier.
- Failover runbook documents promoting the cross-region replica.

### Schema migration safety

DB schema migrations are part of DR planning:

- Every migration is backwards-compatible (multi-step: add column → backfill → use → remove old column over multiple releases).
- Pre-migration: take a snapshot.
- Post-migration: smoke test before promoting.
- Rollback path documented for every migration that isn't trivially additive.

## Cross-region replication strategies

Three patterns, ordered by cost/complexity:

### Active-passive with documented failover

- Primary in one region; warm standby (replica) in another.
- Standby is read-only; no write traffic.
- Failover: declare disaster, promote standby, update DNS.
- RTO: 15-60 minutes (DNS TTL + promotion time + health checks).
- RPO: replication lag (typically 5-30 seconds).

Default for most products. Cost: ~30% extra (one extra cluster).

### Active-active with conflict resolution

- Both regions accept writes; conflicts resolved via last-write-wins or CRDTs.
- Lower RTO (no failover needed); harder design (every write path must handle conflicts).
- Use only when RTO < 1 minute is contractually required.

### Multi-region quorum (Spanner-class)

- Strongly consistent across regions; latency cost on every write.
- Use only when you genuinely need cross-region strong consistency.

The decision is per-tier. Active-active for enterprise tier with strict SLA; active-passive for everything else.

## Write-once audit log tier

Audit logs require tamper-evidence, often by regulation. Two layers:

### Hot tier (Postgres `audit_events`)

- Append-only at the application level (no UPDATE/DELETE allowed via app).
- Database-level: revoke UPDATE/DELETE on the table from the application role.
- Hash-chained rows: each row contains the SHA-256 of the previous row + its own content. Tampering requires recomputing the chain from the modified row forward.

```sql
CREATE TABLE audit_events (
    id            CHAR(26) PRIMARY KEY,        -- ULID
    tenant_id     UUID NOT NULL,
    occurred_at   TIMESTAMPTZ NOT NULL,
    actor_kind    TEXT,
    actor_id      UUID,
    action        TEXT NOT NULL,
    resource_kind TEXT,
    resource_id   CHAR(26),
    before        JSONB,
    after         JSONB,
    metadata      JSONB,
    prev_hash     BYTEA NOT NULL,               -- SHA-256 of the prior row
    self_hash     BYTEA NOT NULL,               -- SHA-256 of this row's content + prev_hash
    INDEX (tenant_id, occurred_at)
);

REVOKE UPDATE, DELETE ON audit_events FROM application_role;
```

### Cold tier (S3 with Object Lock)

- Daily rollup writes audit events to S3 in Parquet format.
- S3 Object Lock with retention period: legal hold + retention based on regulatory requirement (commonly 7 years for financial; 2-5 for general).
- Object Lock prevents deletion even by the bucket owner during the retention period.

### Periodic third-party anchoring (optional)

For compliance regimes that require third-party tamper-evidence:

- Compute a Merkle root over all audit events from a time window (e.g., hourly).
- Publish the root to an immutable third-party store (e.g., a managed notarization service such as AWS QLDB, Google Cloud Confidential Ledger, or any tamper-evident ledger).
- Verifiers can check a specific event by reconstructing the Merkle path and comparing to the published root.

This is overkill for most products. Use only when an external auditor or regulator requires it.

## Restore-test cadence

A backup that's never restored is hope, not insurance.

| Test | Frequency | Who |
|---|---|---|
| **Smoke restore** — pick a random day's snapshot, restore to a test instance, verify a few rows | Weekly, automated | DR pipeline |
| **Full restore drill** — restore the latest snapshot to a test environment, run a smoke test of the application | Monthly | SRE on rotation |
| **Cross-region failover drill** — fail over a non-prod replica to the standby region; observe DNS, app behavior, verify recovery | Quarterly | SRE + on-call |
| **Disaster scenario tabletop** — walk through "region X is gone; what do we do?" with the on-call team | Semi-annually | All SREs |
| **Long-term archive restore** — pull a year-old archive, restore it, verify decryptability | Annually | DR lead |

Every test produces a writeup; failures generate tickets. The tests catch:

- Encryption keys lost or rotated incorrectly.
- Backup formats drifted (e.g., Postgres major version upgrade).
- Permissions broken on the target environment.
- DNS TTLs longer than expected.
- Application config that points at the wrong region post-failover.

## Disaster scenarios — explicit response procedures

Every plausible disaster has a runbook. Examples:

### Scenario: Primary OLTP cluster fails (single-region)

```
1. Pager fires (DB unreachable, replication lag spike)
2. On-call confirms: managed-DB console; metric dashboards
3. If primary unrecoverable → promote standby
4. Update app config (or rely on DNS-based failover)
5. Verify writes succeed against new primary
6. Update status page
7. Post-incident: schedule postmortem within 48h
```

RTO target: 30 minutes. Documented step-by-step.

### Scenario: Cross-region failover (full region loss)

```
1. Pager fires (multiple service unreachable from outside)
2. SRE manager declares regional disaster
3. Failover decision (CTO + SRE lead approve)
4. Run regional failover playbook:
   a. Promote cross-region replica DB
   b. Update DNS (reduce TTL preemptively or accept propagation delay)
   c. Update edge load balancer to direct traffic to other region
   d. Restart application pods in receiving region (if cold)
   e. Verify auth, smoke-test critical paths
5. Communicate to counterparties (status page + email)
6. Post-incident
```

RTO target per tier:
- shared_pod / namespace: 4 hours (we'll be slow; tier accepts it).
- cluster: 1 hour.
- region: 30 minutes.

### Scenario: Data corruption (logical, not infrastructure)

```
1. Investigate scope: which tables, which time range
2. Identify last known-good snapshot
3. Restore the affected scope (PITR to time T) to a side-by-side instance
4. Reconcile: copy clean rows back to production
5. Customer notification if data was visibly wrong
6. Postmortem
```

This is the hardest scenario; full restore loses recent valid data, partial restore is delicate. Pre-document the procedure.

### Scenario: Security incident (breach, leak)

Separate from DR but interleaved:

```
1. Containment: revoke credentials, rotate keys, freeze affected accounts
2. Forensics: which data was accessed, by whom
3. Notification: legal counsel determines obligations (GDPR 72h, customer contracts, etc.)
4. Restoration: restore affected data from clean backup (post-breach point)
5. Post-incident: full review with legal + security
```

Document the legal-counsel contact and obligations explicitly. The technical response is a small piece of breach handling.

## Key management (KMS)

For products holding sensitive data:

### Layered keys

```
Customer Master Key (CMK) — KMS-rooted; envelope-encrypts all data keys
   │
   ├─ Per-tenant KEK — wraps per-tenant DEKs
   │     │
   │     ├─ Per-tenant DEK — encrypts row-level secrets
   │     │
   │     └─ Per-DB DEK — encrypts the per-tenant Postgres data
   │
   └─ Platform KEK — wraps platform-shared DEKs
         │
         └─ ...
```

Per-tenant KEKs allow tenant-specific operations:
- Right-to-be-forgotten: destroy a tenant's KEK; all their data becomes cryptographically inaccessible.
- Per-tenant key rotation without affecting other tenants.

### Rotation cadence

| Key | Rotation |
|---|---|
| CMK | Annual |
| Platform KEKs | Quarterly |
| Per-tenant KEKs | Annual or on-request |
| DEKs | Auto-rotate on data re-encryption events; otherwise quarterly |

### Bring-Your-Own-Key (BYOK) for enterprise tier

For tenants on `region` tier, optional BYOK: they hold their own root key in their own KMS; we use it to wrap their KEK. They can revoke at any time, which makes their data inaccessible to us.

This is a sales differentiator for highly-regulated tenants.

## Right-to-be-forgotten / data deletion

For PII regulations (GDPR, similar):

### What gets deleted

When a tenant or end user requests deletion:

1. **OLTP rows** — delete (or anonymize) within 30 days.
2. **OLAP / warm tier** — propagate the deletion via daily ETL.
3. **Cold archive** — overwrite or anonymize the affected files.
4. **Backups** — for backups during the retention window, deletion isn't immediate. Options:
   - Document that deletion is "as soon as backups expire from the rolling window" (typical 35 days).
   - For immediate deletion: rotate the per-tenant KEK; the data in old backups becomes cryptographically inaccessible (crypto-shredding).

### Audit log exemption

Audit logs are typically retained beyond deletion requests. The audit log entry "User X requested deletion on date Y" must itself be retained. Resolution: anonymize the user fields in the audit log (replace ID with a hash) but keep the event itself.

Document the deletion policy in the privacy section of the canonical doc; it's both customer-facing and an operations contract.

## Backup encryption + key management — concrete

For each backup:

```
1. Postgres takes snapshot (encrypted with per-cluster DEK)
2. Snapshot uploaded to S3
3. S3 server-side encryption with KMS-managed CMK (separate from cluster DEK; defense in depth)
4. Cross-region copy: S3 replication policy
5. Backup metadata (where, when, what) recorded in the control-plane DB
```

To restore:

```
1. Locate backup metadata
2. Verify backup integrity (checksum)
3. Pull backup from S3 (with KMS decryption)
4. Decrypt with per-cluster DEK (held in Vault)
5. Replay WAL to target time (PITR)
6. Verify
```

The two layers of encryption (S3 KMS + per-cluster DEK) protect against single-key compromise.

## Anti-patterns

| Anti-pattern | Reality | Fix |
|---|---|---|
| Backups never tested | First restore is during a real disaster | Restore drills weekly/monthly/quarterly |
| Same-region only | Region failure = total loss | Cross-region replication for cluster+ tier |
| Encrypted backups with single-region key | Key region failure = backup unreadable | Cross-region key replication; document recovery |
| Audit log mutable | Compliance failure; tamper risk | App-level append-only + DB GRANT revocation + S3 Object Lock |
| Schema migrations without rollback | One bad migration = days of recovery | Backwards-compatible migrations; multi-step |
| RTO/RPO undocumented | Customers and SREs disagree on expectations | Document per-tier; in SLA |
| Failover untested | Failover during real outage doesn't work | Quarterly drills |
| Right-to-be-forgotten ambiguous on backups | Compliance gap | Document explicitly; consider crypto-shredding |
| KMS keys in same region as data | Region loss = key loss = data loss | Cross-region key replication |
| BYOK without revocation testing | Customer revokes; we discover we can't actually disable | Test BYOK lifecycle including revocation |
| Audit log without `tenant_id` | Cross-tenant audit queries impossible | Index by tenant_id; per-tenant audit views |
| Long DNS TTL during failover | RTO inflates by TTL value | Reduce TTL preemptively before known maintenance |
| One backup format / tool / vendor | Vendor outage = no backups | Multi-tool: cloud-vendor + open-source format (Parquet, pg_dump) |
| Backups not encrypted at rest | Backup leak = full data leak | KMS-encrypted always |

## Worked example — DR posture for a B2B SaaS

Tier-aware RPO/RTO commitments:

| Tier | RPO | RTO | Backup strategy |
|---|---|---|---|
| shared_pod | 24h | 8h | Daily snapshot; same-region warm standby |
| namespace | 4h | 4h | Hourly + WAL; same-region sync replica |
| cluster | 15min | 1h | Continuous WAL; same-region sync + cross-region async |
| region | 5min | 30min | Cross-region async; documented failover runbook; quarterly drill |
| on_prem | tenant | tenant | We ship + support; tenant operates |

Backup pipeline (per-cluster):

- WAL → S3 (us-east-1); cross-region replicated to eu-west-1
- Daily snapshot at 02:00 UTC; retention 35 days
- Monthly archive snapshot; retention 7 years
- All encrypted with per-cluster DEK + S3 KMS

Audit pipeline:

- Application writes to `audit_events` (Postgres, hash-chained)
- Daily worker exports to S3 Object Lock (retention 7 years)
- Hourly Merkle root anchored to a notarization service (optional, for enterprise tier)

Restore drills:

- Weekly automated smoke restore (random snapshot, verify checksum + 100 rows)
- Monthly full restore drill (one tenant's DB to staging, run smoke test)
- Quarterly cross-region failover (non-prod cluster)
- Annual archive restore (year-old archive, verify decryptability)

Disaster runbooks (in repo):

- `runbooks/dr-primary-db-failure.md`
- `runbooks/dr-region-failover.md`
- `runbooks/dr-data-corruption.md`
- `runbooks/dr-security-incident.md`
- `runbooks/dr-byok-revocation.md` (for enterprise tier)

`OPEN:` markers:

- `OPEN: Merkle anchor cadence — currently hourly. Consider daily for cost reduction if no enterprise tenant requires hourly. Switch when first such ask. Owner: compliance lead.`
- `OPEN: Cross-region active-active vs active-passive — currently active-passive. Switch to active-active if RPO requirement < 1min in a contract. Owner: data-platform lead.`

## Cross-references

- `multi-tenancy.md` — for tier-driven DR commitments
- `data-plane.md` — for audit-events table and outbox pattern
- `caching-and-storage.md` — for tier hierarchy and S3 Object Lock
- `compliance-and-ownership.md` — for audit retention and right-to-be-forgotten ownership
- `operations-and-deployment.md` — for runbooks under GitOps
