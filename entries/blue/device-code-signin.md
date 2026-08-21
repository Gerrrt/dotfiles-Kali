---
id: device-code-signin
title: Detect device-code phishing (Entra sign-in, deviceCode flow)
detection: kql-entra-signin
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1528]
source: dirkjanm (ROADtools) & Secureworks CTU, device-code phishing
pair: device-code-phish
---

Device-code is a rare auth flow for normal interactive users, so the invariant is
the flow itself: filter Entra sign-in logs for `AuthenticationProtocol == "deviceCode"`,
then triage by user / IP / location / app. A device-code sign-in from a geo or IP
that doesn't match the user — or for a user who never uses it — is the tell.

This is **Entra sign-in telemetry (KQL / Sentinel), not the Windows Security log**,
so it lives only here in the companion — `PURPLE-TEAM.md` is scoped to on-prem
Splunk and deliberately doesn't carry cloud detections.

```kql
SigninLogs
| where AuthenticationProtocol == "deviceCode"
| project TimeGenerated, UserPrincipalName, IPAddress, AppDisplayName, LocationDetails, ResultType
```
