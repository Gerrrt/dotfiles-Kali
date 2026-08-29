---
id: k8s-rolebinding-audit
title: Detect cluster-admin binding (K8s audit)
detection: splunk-k8s-audit
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [kubernetes]
source: K8s RBAC abuse (cluster-admin binding)
pair: k8s-clusteradmin-binding
---

A `(cluster)rolebinding` whose `roleRef` names `cluster-admin` is the invariant —
pull `create`/`update`/`patch` on `(cluster)rolebindings` from the audit log and
match `roleRef.name == cluster-admin`. Almost nothing should mint new cluster-admin
bindings outside controlled platform automation, so with a good allowlist of
GitOps/IaC principals this is near-zero-false-positive.

K8s audit telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=k8s sourcetype=*apiserver*audit* verb IN (create, update, patch) objectRef.resource IN (clusterrolebindings, rolebindings)
| spath
| search "requestObject.roleRef.name"=cluster-admin
| table _time, user.username, objectRef.name, "requestObject.subjects{}.name"
```
