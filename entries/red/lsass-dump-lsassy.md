---
id: lsass-dump-lsassy
title: Remote LSASS dump (NetExec lsassy)
section: Lateral movement & remote execution
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1003.001]
platform: [windows, network]
source: hacktheplanet §"Lateral movement & remote execution"
pair: lsass-4656
---

With local-admin on a box, pull credentials from LSASS memory over SMB without
dropping a tool to disk — the `lsassy` module dumps the process and parses creds
in memory. Opening a handle to lsass is the unavoidable, noisy part: that's the
paired `4656`. (LSA secrets via `--lsa` are a *different* technique with different
telemetry — a candidate for its own pair, not this one.)

```sh
nxc smb {{rhost}} -u {{user}} -H {{nthash}} -M lsassy
```
