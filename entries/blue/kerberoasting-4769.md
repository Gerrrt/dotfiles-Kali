---
id: kerberoasting-4769
title: Detect Kerberoasting (4769 TGS request)
detection: splunk-spl
event_ids: [4769]
attack:
  tactic: TA0006
  techniques: [T1558.003]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: kerberoast-getuserspns
---

Detect on the invariant, not the IOC — and the invariant here is **not** the cipher.
An RC4 (`0x17`) service ticket for a non-machine, non-krbtgt SPN is the loudest
version of this: tools like Orpheus, and Rubeus' `/tgtdeleg` route, force RC4
precisely to keep the roast crackable, so the downgrade is a near-free true positive.
But the paired red (`impacket-GetUserSPNs -request`, `nxc --kerberoasting`) does *not*
force the etype — the TGS is issued under the SPN account's
`msDS-SupportedEncryptionTypes`, so an AES-only service account yields a `0x11`/`0x12`
ticket and cracks fine (`hashcat -m 19700`). A `0x17`-only filter never sees it. Same
lesson as `asrep-roast-4768`: don't constrain the encryption type or AES-only domains
slip through.

So key on both — RC4 on a user SPN as the fast path, and the shape the roast can't
hide at any etype: one client pulling tickets for *many distinct* SPN accounts in a
burst. A workstation legitimately touches a handful of services; it does not enumerate
thirty.

```spl
index=main EventCode=4769 Service_Name!="*$" Service_Name!="krbtgt"
    (Ticket_Encryption_Type=0x17 OR Ticket_Encryption_Type=0x11 OR Ticket_Encryption_Type=0x12)
| eval rc4=if(Ticket_Encryption_Type=="0x17", 1, 0)
| stats dc(Service_Name) AS ServiceAccounts values(Service_Name) AS Services
        max(rc4) AS RC4_Downgrade by Client_Address, Account_Name
| where RC4_Downgrade=1 OR ServiceAccounts>=5
| sort -RC4_Downgrade, -ServiceAccounts
```

Tune `ServiceAccounts` to your environment before trusting the AES arm — the count that
means "enumeration" depends on how many SPNs a normal client touches. Baselining the
requesting account against its own history beats a global threshold where you can
afford to keep the state.
