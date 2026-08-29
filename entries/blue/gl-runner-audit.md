---
id: gl-runner-audit
title: Detect rogue runner association (GitLab audit events)
detection: gitlab-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1543]
source: GitLab CI/CD abuse (rogue runner association)
pair: gl-runner-hijack
---

`set_runner_associated_projects` is the invariant. Runners are attached to projects
rarely and by a small set of maintainers, so a new association — especially of an
instance/group runner an unexpected actor controls, or onto a sensitive project — is a
strong tell that someone is positioning to harvest CI job secrets. Reconcile against the
known runner inventory, prefer project-scoped ephemeral runners, and alert on any
association outside change control.

GitLab audit-event telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=gitlab sourcetype=gitlab:audit event_type=set_runner_associated_projects
| table _time, author_name, event_type, entity_path, target_details
```
