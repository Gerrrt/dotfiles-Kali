---
id: password-spray-4625
title: Detect password spray (one source, many accounts — 4771 + 4625)
detection: splunk-spl
event_ids: [4771, 4625]
attack:
  tactic: TA0006
  techniques: [T1110.003]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: password-spray-kerbrute
---

The shape, not the count: one source address failing against many *distinct*
accounts in a short window — the inverse of a single user who simply forgot
their password. Counting distinct accounts per source beats a raw failure-rate
threshold because the spray is deliberately slow.

Which event carries that shape depends on the spray path, and getting this wrong
is how a spray detection misses. `kerbrute passwordspray` sprays **Kerberos
AS-REQ pre-authentication**, so a wrong password lands on the DC as `4771` with
`Failure_Code=0x18` — it never generates `4625`, which is the
NTLM/interactive/SMB logon-failure event. Key on `4771` first; keep `4625` for
the NTLM/SMB path (`nxc smb ... -p`), where it is the right event.

```spl
index=main EventCode=4771 Failure_Code="0x18" Account_Name!="*$"
| stats dc(Account_Name) AS Accounts values(Account_Name) by host, Client_Address
| where Accounts > 10 | sort -Accounts
```

Secondary — the NTLM/SMB/interactive spray path, where the same one-source-to-
many-accounts shape shows up as `4625` instead:

```spl
index=main EventCode=4625 NOT (Source_Network_Address IN ("-","127.0.0.1"))
| eval Account=mvindex(Account_Name,1)
| stats dc(Account) AS Accounts by host, Source_Network_Address
| where Accounts > 10 | sort -Accounts
```
