---
id: harbor-robot-backdoor
title: Harbor robot account (durable registry credential)
section: Harbor / container registry
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [harbor]
source: Container supply-chain persistence (registry robot account)
pair: harbor-robot-audit
---

After compromising a project admin, mint a **robot account**: a long-lived,
non-interactive registry credential (its own secret, no MFA, its own name) that keeps
push/pull access after the admin's password is reset — the registry equivalent of an
API token. Scope it wide (all projects, push+pull) and it is a clean foothold to keep
poisoning images or pulling private ones. Creation writes an `operation=create` /
`resource_type=robot` record. (Registry — no slots.)

```sh
# create a wide-scope robot via the Harbor API; the response returns its secret once
curl -s -u <admin>:<pass> -X POST "https://<registry>/api/v2.0/robots" \
  -H 'Content-Type: application/json' -d @robot.json  # permissions: push+pull, all projects
```
