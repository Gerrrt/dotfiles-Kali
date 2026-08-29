---
id: k8s-exec
title: kubectl exec into a running pod
section: Kubernetes
phase: Execution
attack:
  tactic: TA0002
  techniques: [T1609]
platform: [kubernetes]
source: K8s post-exploitation (interactive pod access)
pair: k8s-exec-audit
---

The container-runtime shell: drop into a running pod to run commands, pivot, or
read mounted secrets and the service-account token. With `pods/exec` rights (often
a broader grant than people realize) it's the fastest hands-on-keyboard move after
you compromise a kubeconfig or an SA token. (Cluster — no slots.)

```sh
kubectl auth can-i create pods/exec
kubectl exec -it <pod> -n <namespace> -- /bin/sh
```
