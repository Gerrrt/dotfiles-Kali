---
id: npm-2fa-disable
title: npm publish-2FA disable (open the publish path)
section: npm / registry
phase: Defense Impairment
attack:
  tactic: TA0112
  techniques: [T1685]
platform: [npm]
source: npm supply-chain evasion (2FA requirement tamper)
pair: npm-2fa-audit
---

A package's "require two-factor to publish" setting is the control that stops a bare stolen
token from shipping a release. Set it to `none` and an automation token publishes with no
second factor and no interactive prompt — quietly clearing the path for the malicious-publish
step. The change writes an npm audit event `action=package.edit` with the publish `mfa`
requirement set to `none`. (Registry control plane — no slots.)

```sh
# drop the package's 2FA-to-publish requirement so a stolen token can publish unattended
npm access set mfa=none <package>
```
