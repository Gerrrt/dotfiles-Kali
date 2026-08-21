---
id: pypi-trusted-publisher-audit
title: Detect trusted publisher add (PyPI journal)
detection: pypi-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: PyPI supply-chain persistence (OIDC trusted publisher)
pair: pypi-trusted-publisher
---

A journal entry adding a **trusted publisher** to a project is the invariant — a new external
CI identity granted credential-less OIDC publish rights. Trusted-publisher changes are rare
and high-impact (they authorize an outside repo/workflow to publish), so one naming an
unfamiliar org/repo, or added by an unexpected actor, is a durable-persistence tell: no token
to revoke, and every future release from that workflow is trusted. Pin the allowed publisher
to the project's own repo/workflow and alert on any addition that names another.

PyPI journal telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=pypi sourcetype=pypi:journal action="add*" action="*trusted publisher*"
| table _time, actor, action, project
```
