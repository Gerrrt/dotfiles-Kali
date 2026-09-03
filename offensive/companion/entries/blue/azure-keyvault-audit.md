---
id: azure-keyvault-audit
title: Detect Key Vault bulk secret read (AuditEvent diagnostic logs)
detection: kql-keyvault-audit
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1555.006]
source: MITRE ATT&CK T1555.006; HAFNIUM / Shai-Hulud Key Vault secret theft
pair: azure-keyvault-secret-dump
---

The invariant is **breadth in a window**: one identity reading many *distinct* secrets in a
short span. A single `SecretGet` is normal — every app reads its own secret on boot — so
bucket time first, then count distinct secrets; an unbucketed distinct-count aggregates over
the whole search range and a sweep spread across hours never trips it.

Make the floor **relative to the identity**, not absolute. A flat "more than N secrets" is
wrong both ways: the automation principal that legitimately reads 200 secrets a run never
alerts, while a targeted grab of the ten highest-value secrets sails under it. Baseline each
caller's normal per-window breadth and alert on the departure — the query below uses a plain
floor for legibility, but production should replace `> 10` with a per-`caller` baseline the
way `vault-secret-read-audit` does.

```kql
AzureDiagnostics
| where ResourceType == "VAULTS" and Category == "AuditEvent"
| where OperationName in ("SecretGet", "SecretList", "SecretListVersions")
| extend caller = tostring(identity_claim_upn_s),
         appid  = tostring(identity_claim_appid_g),
         secret = tostring(split(requestUri_s, "/")[4])
| summarize gets = countif(OperationName == "SecretGet"),
            secrets = dcount(secret), which = make_set(secret, 20)
          by bin(TimeGenerated, 15m), Resource, caller, appid, CallerIPAddress
| where secrets > 10
| order by secrets desc
```

Higher-confidence arm, and the one that matches what the paired red actually does: a
`SecretList` immediately followed by many `SecretGet`s from the same `caller` is the
list-then-drain signature, distinct from raw volume — an app reading its own handful of
secrets never lists the vault first.

> Caveat: Key Vault `AuditEvent` is **not** collected unless a diagnostic setting routes it
> to a workspace — it is off by default, and a tenant that never enabled it has no
> retrospective coverage at all. In *resource-specific* destination mode the rows land in
> the dedicated **`AZKVAuditLogs`** table instead of `AzureDiagnostics`, with its own column
> names (`OperationName`, `CallerIPAddress`, `identity_claim_*`), so check which mode the
> estate uses before deploying the query above. This is the same opt-in-telemetry footing as
> `aws-s3-exfil-cloudtrail`'s S3 data events — a real detection with a stated prerequisite,
> not a query against telemetry nobody has.

Key Vault diagnostic telemetry (KQL / Sentinel), companion-only — `PURPLE-TEAM.md` is
on-prem Windows.
