---
id: vault-secret-read-audit
title: Detect bulk secret read (Vault audit log)
detection: vault-audit-log
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1555]
source: HashiCorp Vault post-compromise (secret-store exfil)
pair: vault-secret-exfil
---

The invariant is **breadth in a window**: one identity issuing `read` against many distinct KV
paths in a short span (a single read is normal automation). Both halves matter — an unbucketed
distinct-count aggregates over the whole search range, so a sweep spread across hours, or split
across tokens and source IPs, never reaches the threshold no matter how large it is. Bucket the
time first, then count.

Make the floor **relative to the token, not absolute**. A flat "more than 25 paths" is wrong in
both directions: the automation identity that legitimately reads 200 secrets a run never alerts,
while a targeted grab of the ten highest-value secrets sails under. Baseline each token's normal
per-window breadth and alert on the departure from it.

HashiCorp Vault audit-device telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=vault sourcetype=vault:audit type=request request.operation=read request.path=secret/*
| bin _time span=5m
| stats dc(request.path) AS paths, values(request.path) AS which BY _time, auth.display_name, request.remote_address
| eventstats avg(paths) AS base_avg, stdev(paths) AS base_sd BY auth.display_name
| eval floor=max(5, base_avg + 3*base_sd)
| where paths > floor
| sort - paths
```

Secondary tell — the **interactive** token. `auth.display_name` carries the auth-method prefix
(`userpass-`, `oidc-`, `ldap-` are humans; `approle` and `token` are machines), and a human
token walking `secret/` at all is a standalone finding, so it gets a far lower floor than the
baselined automation above:

```spl
index=vault sourcetype=vault:audit type=request request.operation=read request.path=secret/*
    ("auth.display_name"="userpass-*" OR "auth.display_name"="oidc-*" OR "auth.display_name"="ldap-*")
| bin _time span=5m
| stats dc(request.path) AS paths, dc(request.remote_address) AS srcs BY _time, auth.display_name
| where paths > 5
```

Third arm, and the one that catches the low-and-slow sweep both thresholds miss: keep a lookup
of each token's known `request.remote_address` set and alert on a read from an address outside
it **regardless of volume**. A stolen token is used from somewhere new; that is true on read
number one, before any breadth signal exists. Scope tokens tightly and prefer short leases so a
stolen one drains less, and treat a token that was rotated out then reappears as a finding in
itself.
