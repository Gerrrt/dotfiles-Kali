---
id: ransomware-encrypt-files
title: Data encrypted for impact (mass file encryption)
section: Impact
phase: Impact
attack:
  tactic: TA0040
  techniques: [T1486]
platform: [windows]
source: MITRE ATT&CK T1486; ransomware encryption payload
pair: mass-encrypt-4663
---

The payoff stage: walk the filesystem (and mapped shares) and encrypt documents in
bulk, rename with a campaign extension, and drop a ransom note in each directory.
The behavioral signature is volumetric — one process touching a very large number of
files across many folders in a short window, rewriting each and often changing the
extension — not any single file op. On-host telemetry sees a burst of writes; the
tell is the rate and breadth, plus the note file appearing everywhere.

```text
# behavioral shape (illustrative — do NOT run on real data):
#   for each file under the target roots:
#       read plaintext -> AES-encrypt -> overwrite -> rename *.<campaign-ext>
#   drop <RANSOM-NOTE>.txt in every touched directory
#   (a real payload also walks mapped drives \\host\share and disables VSS first)
```
