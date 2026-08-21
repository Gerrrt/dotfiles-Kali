---
id: snowflake-user-audit
title: Detect user creation / ACCOUNTADMIN grant (Snowflake QUERY_HISTORY)
detection: snowflake-query-history
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1136.003]
source: Snowflake tenant persistence (rogue user / role grant)
pair: snowflake-rogue-user
---

Two invariants: `QUERY_TYPE = CREATE_USER`, and a `GRANT` whose text carries a high-power
role (`ACCOUNTADMIN`/`SECURITYADMIN`). Both are rare, admin-level changes, so one by an
unexpected actor — especially a create immediately followed by an ACCOUNTADMIN grant, or a
grant outside the identity-management workflow — is the persistence tell. Reconcile new
users against provisioning and alert on privileged grants outside change control.

Snowflake `ACCOUNT_USAGE.QUERY_HISTORY` telemetry, companion-only — `PURPLE-TEAM.md` is
on-prem Windows.

```spl
index=snowflake sourcetype=snowflake:query_history (query_type=CREATE_USER OR (query_type=GRANT (query_text="*ACCOUNTADMIN*" OR query_text="*SECURITYADMIN*")))
| table _time, user_name, role_name, query_text
```
