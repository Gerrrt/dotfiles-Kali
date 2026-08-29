---
id: harbor-image-backdoor
title: Backdoored image over a trusted tag (poison the registry)
section: Harbor / container registry
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1525]
platform: [harbor]
source: Container supply-chain compromise (Implant Internal Image)
pair: harbor-image-push-audit
---

The supply-chain classic: with push rights to a trusted repo, rebuild a legitimate
image with your implant baked into a layer and push it over the tag consumers pull
(`:latest`, a release tag, or a base image everyone `FROM`s). Every downstream build
and deploy that pulls that tag now runs your code — one push fans out across the
fleet. Overwriting an existing tag (rather than adding a new one) is the tell. The
push writes an `operation=push` / artifact-create record to Harbor's audit log.
(Registry — no on-host target, so no slots.)

```sh
# rebuild the trusted image with an implant, then overwrite the tag everyone pulls
docker build -t <registry>/<project>/<repo>:latest .   # Dockerfile adds the backdoor
docker login <registry> && docker push <registry>/<project>/<repo>:latest
```
