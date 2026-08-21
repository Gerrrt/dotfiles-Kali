---
id: asrep-probing-4771
title: Detect AS-REP roast (4768 no-preauth)
detection: splunk-spl
event_ids: [4768]
attack:
  tactic: TA0006
  techniques: [T1558.004]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: asreproast-getnpusers
---

Detect on the invariant, not the IOC. The roastable AS-REP is a *successful*
`4768` TGT request with **pre-authentication type 0** (no pre-auth) for a
non-machine account — that is the account `GetNPUsers`/`--asreproast` actually
harvests. The AS-REP is issued under the account's long-term key — RC4 (`0x17`)
where it's enabled, AES (`0x11`/`0x12`) in RC4-disabled domains — and cracked
offline (`hashcat -m 18200` for the RC4 case). Unlike Kerberoasting the attacker
doesn't force the etype, so the *invariant* is the type-0 pre-auth on a user, not
the negotiated cipher — key on it directly and don't constrain the encryption
type, or AES-only domains slip through. A normal account pre-auths with type 2
(encrypted timestamp), so type 0 on a user is the tell.

```spl
index=main EventCode=4768 Pre_Authentication_Type=0 Account_Name!="*$"
| stats count values(Account_Name) AS Accounts by Client_Address
| sort -count
```

**Not here:** the one-source-to-many-accounts `4771 Failure_Code=0x18` burst. It is a real
signal, but it is *not* this technique — it fires on wrong-password pre-auth failures against
pre-auth-**required** accounts (Kerbrute enum / spraying) and never on the roast itself, which
succeeds. It is `password-spray-4625`'s primary query, at a threshold tuned for it; running a
lower-threshold copy here only doubles the alerts on someone else's finding. Pivot to that
entry when the two fire together — enumeration followed by roasting is one operator working
through the domain.
