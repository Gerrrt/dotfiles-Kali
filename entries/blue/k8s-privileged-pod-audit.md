---
id: k8s-privileged-pod-audit
title: Detect privileged / host-namespace pod (K8s audit)
detection: splunk-k8s-audit
event_ids: []
attack:
  tactic: TA0004
  techniques: [T1610, T1611]
platform: [kubernetes]
source: peirates / Bad Pods (BishopFox), K8s container breakout
pair: k8s-privileged-pod
---

The breakout needs a pod with `privileged: true`, `hostPID`, or a `hostPath` mount
of `/`, so the invariant is the pod-create audit event carrying one of those.
Detect on the kube-apiserver audit log (verb `create`, resource `pods`) where the
request object sets a node-escape capability. Better still, *block* it at admission
with Pod Security Admission (restricted), so this becomes prevention, not just an
alert.

K8s audit telemetry (Splunk / Elastic / Falco), companion-only — `PURPLE-TEAM.md`
is on-prem Windows.

```spl
index=k8s sourcetype=*apiserver*audit* verb=create objectRef.resource=pods
| spath
| where 'requestObject.spec.containers{}.securityContext.privileged'="true"
    OR 'requestObject.spec.hostPID'="true"
    OR 'requestObject.spec.volumes{}.hostPath.path'="/"
| table _time, user.username, objectRef.namespace, objectRef.name, sourceIPs{}
```
