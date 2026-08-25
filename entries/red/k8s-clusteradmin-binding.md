---
id: k8s-clusteradmin-binding
title: Bind to cluster-admin (RBAC privesc / persistence)
section: Kubernetes
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [kubernetes]
source: K8s RBAC abuse (cluster-admin binding)
pair: k8s-rolebinding-audit
---

With rights to write RBAC (a common over-grant), bind any principal — a user, a
group, or a service-account token you already hold — to the built-in
`cluster-admin` role. Instant, durable cluster ownership that outlives the pod you
came in on. (Cluster — no slots.)

```sh
kubectl create clusterrolebinding pwn --clusterrole=cluster-admin --serviceaccount=default:default
kubectl auth can-i '*' '*' --all-namespaces
```
