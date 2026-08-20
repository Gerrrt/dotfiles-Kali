---
id: slack-2fa-disable
title: Slack 2FA enforcement disable (weaken workspace auth)
section: Slack / SaaS
phase: Defense Impairment
attack:
  tactic: TA0112
  techniques: [T1685]
platform: [slack]
source: Slack workspace compromise (2FA enforcement tamper)
pair: slack-2fa-audit
---

Workspace-enforced two-factor is the control that keeps a stolen password from being enough.
As an admin/owner, turn off the "require 2FA" workspace setting and every member's account
drops to password-only — widening the blast radius of any credential you already have or
phish next, and quietly. It is an org-settings action and writes a Slack audit event
`action=pref.two_factor_auth_changed` with the requirement set to off. (SaaS control plane —
no slots.)

```sh
# Slack 2FA enforcement is an org-settings action (Admin → Settings → Authentication):
#   turn OFF "Require two-factor authentication"
# audit records: pref.two_factor_auth_changed (two_factor_required=false)
```
