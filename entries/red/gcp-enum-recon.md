---
id: gcp-enum-recon
title: GCP enumeration (projects, assets, IAM — recon)
section: GCP / cloud IAM
phase: Discovery
attack:
  tactic: TA0007
  techniques: [T1580, T1526, T1069.003]
platform: [cloud]
source: GCP post-access recon (blast-radius mapping)
pair: null
---

Once a token or service-account key lands, map the blast radius before touching
anything. List every reachable project, sweep all resources with the Asset
Inventory API, then read the IAM policy to learn who holds what — the shortest
path from "a credential" to "the accounts worth backdooring." Read-only and
low-signal on its own (Data Access telemetry, often unmonitored), which is why it
ships unpaired.
(Pure recon — no paired blue detection.)

```sh
gcloud projects list
gcloud asset search-all-resources --scope=projects/<project>
gcloud projects get-iam-policy <project> --format=json
```
