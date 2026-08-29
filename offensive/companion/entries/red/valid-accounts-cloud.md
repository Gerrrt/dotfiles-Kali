---
id: valid-accounts-cloud
title: Valid cloud accounts (credential stuffing → tenant sign-in)
section: Microsoft 365 / Entra ID
phase: Initial Access
attack:
  tactic: TA0001
  techniques: [T1078.004]
platform: [cloud]
source: MITRE ATT&CK T1078.004; credential stuffing against Entra
pair: valid-accounts-signin
---

No exploit, no malware — just log in. A leaked or purchased credential, or one recovered
from a combolist, is sprayed against the tenant until it hits, and then you are simply a
user: the sign-in is legitimate, carries the victim's access, and looks like them. It is
the quietest initial access there is, which is why the *pattern around the login* — not
the login itself — is the only tell. Legacy/basic-auth endpoints that skip MFA are the
preferred target; where modern auth is enforced this pairs with the AiTM route
(`aitm-phish`) to clear MFA. (Cloud — no on-host target, so no slots.)

```sh
# spray a single leaked password across tenant users, low-and-slow to dodge lockout
MSOLSpray --userlist users.txt --password '<leaked-pass>'
# then just sign in with the hit — nothing exploitative about it
az login -u <user>@<tenant>.onmicrosoft.com -p '<leaked-pass>'
```
