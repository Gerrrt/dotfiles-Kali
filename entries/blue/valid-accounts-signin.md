---
id: valid-accounts-signin
title: Detect valid-account abuse (Entra sign-in, stuffing hit from a new ASN)
detection: kql-entra-signin
event_ids: []
attack:
  tactic: TA0001
  techniques: [T1078.004]
source: Entra sign-in logs; failure-burst-then-success + new-ASN baseline
pair: valid-accounts-cloud
---

A valid-account sign-in is legitimate by construction, so there is no bad event to match
— only a bad *shape*. Two arms, because credential stuffing and a single clean
purchased-credential login look different. The stuffing hit is a **burst of failures then
a success** for the same user in a short window — the inverse of the AD spray, seen from
the winning side rather than `password-spray-4625`'s failing side. Key on the transition,
not a raw failure count.

This is **Entra sign-in telemetry (KQL / Sentinel), not the Windows Security log** —
companion-only, `PURPLE-TEAM.md` is on-prem Splunk.

```kql
SigninLogs
| where IsInteractive == true
| summarize failures = countif(ResultType != 0),
    firstSuccess = minif(TimeGenerated, ResultType == 0),
    successIP = anyif(IPAddress, ResultType == 0),
    successASN = anyif(tostring(AutonomousSystemNumber), ResultType == 0)
    by UserPrincipalName, bin(TimeGenerated, 1h)
| where failures > 10 and isnotempty(successIP)
| project UserPrincipalName, failures, firstSuccess, successIP, successASN
| sort by failures desc
```

The clean-credential login has no failure burst, so the second arm is a **success from an
ASN this user has never signed in from** — which needs a per-user baseline, the same
join-against-your-own-history the `vault-secret-read-audit` fix uses rather than a bare
threshold. Build the baseline over a trailing window and alert on first-seen ASNs:

```kql
let lookback = 14d;
let baseline = SigninLogs
    | where TimeGenerated between (ago(lookback) .. ago(1d)) and ResultType == 0
    | summarize by UserPrincipalName, knownASN = tostring(AutonomousSystemNumber);
SigninLogs
| where TimeGenerated > ago(1d) and ResultType == 0 and IsInteractive == true
| extend ASN = tostring(AutonomousSystemNumber)
| join kind=leftanti baseline on UserPrincipalName, $left.ASN == $right.knownASN
| project TimeGenerated, UserPrincipalName, IPAddress, ASN, AppDisplayName, LocationDetails
```

Where the tenant has **Entra ID Protection** (P2), `unfamiliarFeatures` /
`unlikelyTravel` risk detections are the maintained version of both arms — prefer them
and treat the KQL above as the fallback for tenants without P2. Rank hits by the app and
by whether the success came through a **legacy-auth** client (`ClientAppUsed` in the
non-modern set), since basic-auth endpoints are where stuffing lands when modern auth is
otherwise enforced.
