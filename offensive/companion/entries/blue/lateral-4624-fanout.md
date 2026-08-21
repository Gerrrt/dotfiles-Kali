---
id: lateral-4624-fanout
title: Detect pass-the-hash lateral movement (4624 type-3 NTLM fan-out)
detection: splunk-spl
event_ids: [4624]
attack:
  tactic: TA0008
  techniques: [T1550.002]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: pth-lateral-nxc
---

One source address logging on (`4624` type 3, network) to many distinct hosts in
a short window is the reuse pattern — pass-the-hash, sprayed creds, or a relay all
fan out the same way. The auth succeeds, so the signal is the breadth, not a
failure.

Breadth alone is not enough, though: type-3 network logons are the most common event
in a Windows estate, and any backup agent, scanner, or management server fans out the
same shape all day. **Pass-the-hash is specifically an NTLM authentication** — the NT
hash *is* the NTLM secret, so `nxc -H`, `evil-winrm -H` and `impacket-psexec -hashes`
all land on the target as a type-3 logon with `Authentication_Package="NTLM"` and
`Logon_Process="NtLmSsp"`. Key on that first; it is the discriminator that separates
the paired attack from ordinary network-logon fan-out, and it lets the host floor rise
past the noise.

```spl
index=main EventCode=4624 Logon_Type=3
    (Authentication_Package="NTLM" OR Logon_Process="NtLmSsp")
    NOT (Source_Network_Address IN ("-","::1","127.0.0.1"))
| eval Account=mvindex(Account_Name,1)
| stats dc(host) AS Hosts values(host) AS Hosts_Seen by Source_Network_Address, Account
| where Hosts > 4 | sort -Hosts
```

Keep the package-agnostic sweep as a second, broader hunt — it is noisier by
construction, so run it as a hunt rather than an alert. It covers the sibling
techniques the NTLM clause deliberately excludes: **overpass-the-hash** converts the
hash into a Kerberos TGT and then authenticates as Kerberos, and a `4624` fan-out
with a *mixed* authentication package for one account is itself worth a look:

```spl
index=main EventCode=4624 Logon_Type=3 NOT (Source_Network_Address IN ("-","::1","127.0.0.1"))
| eval Account=mvindex(Account_Name,1)
| stats dc(host) AS Hosts values(Authentication_Package) AS Packages by Source_Network_Address, Account
| where Hosts > 4 | sort -Hosts
```

Baseline before alerting either way. Legacy applications, IP-literal SMB access and
inter-forest access all produce legitimate NTLM, so the floor is environment-specific —
tune it to your estate rather than trusting the number above, and treat a source that
has never fanned out before as more interesting than one that always does.
