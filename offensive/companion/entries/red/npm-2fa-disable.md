---
id: npm-2fa-disable
title: npm publish-2FA downgrade (open the publish path)
section: npm / registry
phase: Defense Impairment
attack:
  tactic: TA0112
  techniques: [T1685]
platform: [npm]
source: npm supply-chain evasion (2FA requirement tamper)
pair: npm-2fa-audit
---

A package's publish-2FA level is the control that stops a bare stolen token from shipping
a release. You do not need to turn it off to beat it — you need `automation`, which npm
defines as "2FA required, **but automation tokens override it**". Drop `publish` to
`automation` and a stolen automation token publishes unattended, no second factor, no
interactive prompt, with the setting still reading as 2FA-protected to anyone skimming.
That last part is why it beats switching the control off outright: `mfa=none` is the
obvious tamper, and npm's secure-by-default work has been narrowing it out of the
documented values — `automation` is the downgrade that survives and hides. The change
writes an npm audit event `action=package.edit`. (Registry control plane — no slots.)

```sh
# downgrade publish-2FA so a stolen automation token can publish unattended
npm access set mfa=automation <package>
```
