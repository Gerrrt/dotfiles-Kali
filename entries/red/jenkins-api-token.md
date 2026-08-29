---
id: jenkins-api-token
title: Jenkins user API token (durable non-interactive access)
section: Jenkins / CI/CD
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [jenkins]
source: Jenkins persistence (user API token)
pair: jenkins-api-token-audit
---

Mint an **API token** for a user (your own, or a higher-privileged one you've
compromised): a long-lived, non-interactive credential that drives the Jenkins REST API
and CLI, keeps working after the account's password/session is reset, and blends in among
CI automation. Generating one hits
`.../descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken`, which the
Audit Trail plugin records. (CI controller — no slots.)

```sh
# mint an API token for durable API + CLI access
curl -s -u <user>:<pass> -X POST \
  "https://<jenkins>/user/<user>/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" \
  --data "newTokenName=ci-cache"
```
