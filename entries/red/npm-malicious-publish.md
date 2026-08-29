---
id: npm-malicious-publish
title: npm malicious package publish (supply-chain implant)
section: npm / registry
phase: Initial Access
attack:
  tactic: TA0001
  techniques: [T1195.002]
platform: [npm]
source: npm supply-chain compromise (trojanized publish)
pair: npm-publish-audit
---

With a compromised maintainer session or a stolen automation token, publish a trojanized
version of a package you now control. Every downstream `npm install` — CI runners, developer
laptops, production images — pulls and runs your code (often straight from a `postinstall`
hook), so a single publish fans out across the whole dependency graph. Bump the patch
version so it looks routine. The publish writes an npm audit event `action=package.publish`.
(Registry control plane — no on-host target, so no slots.)

```sh
# publish a trojanized patch of a package you control (postinstall runs on every install)
npm version patch --no-git-tag-version
npm publish --//registry.npmjs.org/:_authToken="<stolen-token>"
```
