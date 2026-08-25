---
id: harbor-artifact-delete
title: Delete the trusted artifact (force re-pull + anti-forensics)
section: Harbor / container registry
phase: Stealth
attack:
  tactic: TA0005
  techniques: [T1070]
platform: [harbor]
source: Container supply-chain evasion (artifact deletion)
pair: harbor-artifact-delete-audit
---

Two supply-chain wins in one call: delete the known-good artifact so the trusted
baseline is gone (defenders can't diff the tampered layer against it) and so caches
miss and re-pull — resolving the tag to whatever you pushed last. Also used to remove
a temporarily-pushed malicious image once it has been pulled, erasing the evidence. A
`DELETE` on the artifact writes an `operation=delete` / `resource_type=artifact`
record. (Registry — no slots.)

```sh
# delete the trusted artifact by digest (or tag) via the Harbor API
curl -s -u <robot>:<secret> -X DELETE \
  "https://<registry>/api/v2.0/projects/<project>/repositories/<repo>/artifacts/<digest>"
```
