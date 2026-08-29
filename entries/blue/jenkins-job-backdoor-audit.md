---
id: jenkins-job-backdoor-audit
title: Detect job create/reconfigure (Jenkins audit log)
detection: jenkins-audit-log
event_ids: []
attack:
  tactic: TA0002
  techniques: [T1072]
source: Jenkins abuse (malicious job / pipeline)
pair: jenkins-job-backdoor
---

`/createItem` (new job) and `/job/<name>/configSubmit` (reconfigure) are the invariants.
Job changes are routine in active shops, so the signal is one by an unexpected actor, on
a sensitive/privileged job, outside config-as-code (JCasC/pipeline-in-SCM), or immediately
followed by a build. Prefer pipelines defined in version-controlled `Jenkinsfile`s so
config drift is reviewable, and alert on UI-side job edits that bypass that path.

Jenkins Audit Trail plugin telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=jenkins sourcetype=jenkins:audit ("/createItem" OR uri="*/job/*/configSubmit")
| table _time, user, uri
```
