---
id: snowflake-network-policy-audit
title: Detect network-policy change (Snowflake QUERY_HISTORY)
detection: snowflake-query-history
event_ids: []
attack:
  tactic: TA0112
  techniques: [T1686.001]
source: Snowflake defense evasion (network-policy tamper)
pair: snowflake-network-policy
---

`NETWORK POLICY` in the query text is the invariant — a `CREATE`/`ALTER`/`DROP` of a
network policy or an `ALTER ACCOUNT/USER SET NETWORK_POLICY`. These are rare and
high-impact (they gate where every login may originate), so any change is worth review,
and a new policy with a wide `ALLOWED_IP_LIST` (`0.0.0.0/0`) or a drop of the enforced one
is the tell. Exclude read-only `SHOW` and reconcile against change control.

Snowflake `ACCOUNT_USAGE.QUERY_HISTORY` telemetry, companion-only — `PURPLE-TEAM.md` is
on-prem Windows.

```spl
index=snowflake sourcetype=snowflake:query_history (query_text="*NETWORK POLICY*" OR query_text="*NETWORK_POLICY*") NOT query_text="SHOW *"
| table _time, user_name, role_name, query_type, query_text
```
