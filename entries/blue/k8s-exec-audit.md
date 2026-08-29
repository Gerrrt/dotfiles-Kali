---
id: k8s-exec-audit
title: Detect pod exec / attach (K8s audit)
detection: splunk-k8s-audit
event_ids: []
attack:
  tactic: TA0002
  techniques: [T1609]
platform: [kubernetes]
source: K8s post-exploitation (interactive pod access)
pair: k8s-exec
---

Every `kubectl exec`/`attach` is a `create` against the `pods/exec` (or
`pods/attach`) subresource in the audit log — that subresource *is* the invariant.
Routine in dev, but in production an exec by a human user (not a controller/service
account) is the hands-on-keyboard tell. Scope to production namespaces and alert on
interactive principals.

K8s audit telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=k8s sourcetype=*apiserver*audit* verb=create objectRef.resource=pods objectRef.subresource IN (exec, attach)
| spath
| table _time, user.username, objectRef.namespace, objectRef.name, sourceIPs{}
```
