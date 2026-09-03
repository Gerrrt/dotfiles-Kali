---
id: bloodhound-collect-4662
title: Detect BloodHound collection (4662 directory-read burst; 1644 LDAP)
detection: splunk-spl
event_ids: [4662, 1644]
attack:
  tactic: TA0007
  techniques: [T1087.002, T1069.002, T1482]
source: TrustedSec AD monitoring; SharpHound collection telemetry
pair: bloodhound-collect
---

Collection has no single-event signature — every read it makes is a legitimate LDAP
operation — so the invariant is **volume and breadth from one source in a short window**,
not any one query. SharpHound touches thousands of directory objects to build the graph,
which on the DC shows up as a `4662` directory-access burst from one account against many
distinct objects far above that account's baseline. Detect the shape, then triage by who:
a workstation account or a user reading the whole directory tree is the tell, where a
management server that always does is baseline.

```spl
index=main EventCode=4662 Object_Type="*" Access_Mask IN ("0x10","0x20","0x100")
    Security_ID!="S-1-5-18"
| bin _time span=5m
| stats dc(Object_Name) AS objects count AS reads by _time, host, Account_Name
| where objects > 200 | sort -objects
```

Two things make this real rather than aspirational, and the entry is explicit about both.
**`4662` must be turned on** — it needs the *Directory Service Access* audit subcategory
enabled **and** a SACL for `Everyone` / `Read` on the domain naming context; without the
SACL the DC writes nothing to key on, the same "the backend emits nothing" trap the
Cloudflare and PyPI fixes called out. And the **`0x100` mask is shared with DCSync**
(`dcsync-4662`), so this query keeps it for coverage but the discriminator here is the
*fan-out* (`dc(Object_Name)`), where DCSync's is the *replication extended right* on a
handful of objects — same event, opposite shape.

The sturdier arm where it is available is **1644**, the expensive/inefficient-LDAP-search
event: SharpHound's filters are broad and land as costly searches. It requires field-
engineering registry values on the DC (`Expensive`/`Inefficient`/`Search Time`
thresholds under `NTDS\Diagnostics`) and is **off by default**, so treat it as a
prerequisite the tenant opts into — but where it is on, one client issuing a burst of
broad, costly LDAP searches is a cleaner signal than the `4662` volume:

```spl
index=main (EventCode=1644)
| bin _time span=5m
| stats count AS searches values(Client) AS client by _time, host
| where searches > 50 | sort -searches
```
