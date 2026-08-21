---
id: password-spray-kerbrute
title: Password spray (kerbrute, low & slow)
section: Microsoft Windows Kerberos — TCP 88
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1110.003]
platform: [windows, network]
source: hacktheplanet §"Microsoft Windows Kerberos — TCP 88"
pair: password-spray-4625
---

One password against every user, not many passwords against one — that dodges
per-account lockout but lights up the auth log from a single source. Mind the
domain lockout policy (`nxc ... --pass-pol`); a bad-pwd-count tick per account is
the cost. AS-REQ pre-auth spraying via kerbrute is quieter than SMB but still
counts toward lockout.

```sh
kerbrute passwordspray -d {{domain}} --dc {{rhost}} users.txt '{{password}}'
```
