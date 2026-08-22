---
id: okta-idp-backdoor
title: Rogue IdP → federation backdoor (sign in as anyone)
section: Okta / identity provider
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1556]
platform: [okta]
source: Okta tenant compromise (add-IdP / AiTM federation backdoor)
pair: okta-idp-audit
---

The high-end persistence play: add an attacker-controlled inbound identity provider,
then federate in as arbitrary users — an auth backdoor that sidesteps passwords and
MFA entirely (the technique behind several headline Okta tenant compromises). IdP
changes are rare and high-impact, which is exactly why they make both a good
backdoor and a good tripwire. (Cloud IdP — no slots.)

```sh
curl -s -X POST "https://<org>.okta.com/api/v1/idps" -H "Authorization: SSWS <admin-token>" -H "Content-Type: application/json" -d @rogue-idp.json
```
