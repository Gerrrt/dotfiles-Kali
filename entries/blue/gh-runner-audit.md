---
id: gh-runner-audit
title: Detect self-hosted runner registration (GitHub audit log)
detection: github-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1543]
source: GitHub Actions CI/CD abuse (self-hosted runner registration)
pair: gh-self-hosted-runner
---

`self_hosted_runner.created` is the invariant. Self-hosted runners are rare and
long-lived, so a new registration — especially from an unexpected actor, on a
public repo, or with a label that shadows an existing pool — is a strong tell that
someone is positioning to harvest job secrets. Pair with the org's known-runner
inventory and alert on any registration outside change control.

GitHub Enterprise audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=github sourcetype=github:audit action=self_hosted_runner.created
| table _time, actor, action, repo, org, business
```
