---
id: npm-owner-add
title: npm rogue maintainer add (durable publish rights)
section: npm / registry
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [npm]
source: npm supply-chain persistence (package ownership)
pair: npm-owner-audit
---

Add an attacker-controlled account as an owner/maintainer of the package (or to the org
team that owns it). Now you can publish forever with your OWN credentials — the durable
version of a stolen token, surviving the victim maintainer's password reset and MFA
re-enrollment. It blends in among legitimate collaborator changes. The grant writes an npm
audit event `action=package.owner_add` (or `team.user_add` at the org). (Registry control
plane — no slots.)

```sh
# add your account as a maintainer for durable publish rights
npm owner add <attacker-user> <package>
```
