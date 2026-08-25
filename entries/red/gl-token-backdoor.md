---
id: gl-token-backdoor
title: Project/deploy token backdoor (durable GitLab access)
section: GitLab / CI/CD
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [gitlab]
source: GitLab post-compromise persistence (access/deploy token)
pair: gl-token-audit
---

Add your own credential so access outlives the compromised session: a **project access
token** (scoped `api`/`write_repository`) drives the API and pushes to the repo; a
**deploy token** gives durable clone + container-registry pull. Both are non-interactive,
MFA-free, survive a password reset, and blend in among legitimate CI credentials. A
project access token writes `project_access_token_created`, a personal access token
writes `personal_access_token_created`, and a deploy token writes
`deploy_token_created`. (Cloud CI — no slots.)

```sh
# mint a scoped project access token for durable API + push access
curl --request POST --header "PRIVATE-TOKEN: <token>" \
  "https://<gitlab>/api/v4/projects/<project_id>/access_tokens" \
  --data "name=ci-cache&scopes[]=api&scopes[]=write_repository"
```
