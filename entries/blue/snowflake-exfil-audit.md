---
id: snowflake-exfil-audit
title: Detect COPY INTO external unload (Snowflake QUERY_HISTORY)
detection: snowflake-query-history
event_ids: []
attack:
  tactic: TA0010
  techniques: [T1567.002]
source: Snowflake data-theft campaign (unload to external stage)
pair: snowflake-exfil-stage
---

`QUERY_TYPE = UNLOAD` is the invariant (a `COPY INTO <location>`). Internal-stage unloads
are routine, so the signal is an unload to an **external** stage / cloud URL, a large
`ROWS_UNLOADED`/byte volume, an unusual role or warehouse, or a first-time destination.
Prefer external stages behind a storage integration + allowlist, and alert on unloads
outside the known ETL identities.

Snowflake `ACCOUNT_USAGE.QUERY_HISTORY` telemetry, companion-only — `PURPLE-TEAM.md` is
on-prem Windows.

```spl
index=snowflake sourcetype=snowflake:query_history query_type=UNLOAD
| table _time, user_name, role_name, warehouse_name, query_text
```
