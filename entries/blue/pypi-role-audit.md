---
id: pypi-role-audit
title: Detect collaborator add (PyPI journal)
detection: pypi-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: PyPI supply-chain persistence (project role)
pair: pypi-role-add
---

A journal entry beginning `add Owner` / `add Maintainer` is the invariant — a new identity
gaining durable publish rights on the project. Role additions are rare and map to a known
onboarding, so one adding an unfamiliar account, by an unexpected actor, or during an
incident is the persistence tell after an account compromise. Reconcile new
owners/maintainers against known collaborators and alert on out-of-band grants; an
`add Owner` followed by a `new release` is the takeover-then-ship shape.

PyPI journal telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=pypi sourcetype=pypi:journal (action="add Owner*" OR action="add Maintainer*")
| table _time, actor, action, project
```
