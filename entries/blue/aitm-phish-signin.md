---
id: aitm-phish-signin
title: Detect AiTM phishing (Entra sign-in token replay across ASNs)
detection: kql-entra-signin
event_ids: []
attack:
  tactic: TA0001
  techniques: [T1566.002]
source: Entra sign-in logs; AiTM session-cookie replay correlation
pair: aitm-phish
---

The stolen thing is a session cookie, so the invariant is **replay**: the interactive
authentication happens through the phishing proxy at one network location, and the
attacker then uses the issued token from *their* location. In Entra that shows up as a
successful interactive sign-in from one ASN followed, within the token's life, by
non-interactive sign-ins for the same user from a **different** ASN — the auth and the
token-use disagreeing on where the user is. A single anomalous-location sign-in is weak
(travel, VPN); the auth-vs-token split is the AiTM-specific tell, because a real user's
token is used from where they authenticated.

This is **Entra sign-in telemetry (KQL / Sentinel), not the Windows Security log**, so it
lives only here — `PURPLE-TEAM.md` is scoped to on-prem Splunk.

```kql
let window = 2h;
SigninLogs
| where ResultType == 0 and IsInteractive == true
| project authTime=TimeGenerated, UserPrincipalName, authIP=IPAddress,
    authASN=tostring(AutonomousSystemNumber), AppDisplayName
| join kind=inner (
    AADNonInteractiveUserSignInLogs
    | where ResultType == 0
    | project tokTime=TimeGenerated, UserPrincipalName, tokIP=IPAddress,
        tokASN=tostring(AutonomousSystemNumber)
    ) on UserPrincipalName
| where tokTime between (authTime .. authTime + window) and authASN != tokASN
| project authTime, tokTime, UserPrincipalName, authIP, authASN, tokIP, tokASN, AppDisplayName
| sort by authTime desc
```

The ASN split is the discriminator to keep — not the raw IP, since a mobile user shifts
IPs within one carrier ASN legitimately, and not the geo, which resolves too coarsely.
Where the tenant has **Entra ID Protection** (P2), its `RiskDetections` are the
vendor-maintained version of this same idea — `RiskEventType` of `anomalousToken` or
`unfamiliarFeatures` flags AiTM token theft directly — so prefer that arm where it exists
and use the correlation above as the build-it-yourself fallback. Corroborate a hit with a
**new inbox rule** created in the same session (the standard AiTM follow-on that hides the
reply-chain), which lands in the Office audit log.
