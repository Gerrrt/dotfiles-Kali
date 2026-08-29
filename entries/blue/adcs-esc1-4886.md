---
id: adcs-esc1-4886
title: Detect AD CS SAN abuse (4886/4887 ESC1/relay)
detection: splunk-spl
event_ids: [4886, 4887, 5136]
attack:
  tactic: TA0006
  techniques: [T1649]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: adcs-esc1-certipy
---

The invariant of ESC1 (and relay-to-ADCS) is a certificate request whose
subject-alternative-name names a *different* principal than the requester — compare
the requested/issued SAN to the `Requester`. Prefer **4887** (certificate *issued*),
which records the requester and the resolved subject once the CA has processed the
CSR; back the requester≠SAN comparison with CA-side **request-attribute auditing**
enabled so the SAN is actually logged.

> Caveat: the SAN rides in the CSR attributes and is surfaced in the `4886`
> ("request received") Message only once CA request-attribute auditing is on, in a
> variable format — so a `4886`-only `upn=` parse is **best-effort** and can read
> zero results as "no ESC1" (a silent miss). Treat 4887 as primary.

```spl
index=main (EventCode=4887 OR EventCode=4886)
| rex field=Message "(?i)(?:SAN|Subject Alternative Name)\s*[:=].*?(?:upn|dns)=(?<RequestedSAN>[^\s,]+)"
| stats latest(_time) as _time, latest(Requester) as Requester, latest(RequestedSAN) as RequestedSAN, values(EventCode) as codes by RequestID, host
| where isnotnull(RequestedSAN) AND RequestedSAN!=Requester
| table _time, host, RequestID, Requester, RequestedSAN, codes
```

Separately, `5136` writes to the `userCertificate` attribute are shadow-credential /
relay telemetry (certificate mapping onto an object), **not** the ESC1-SAN signal —
watch them, but as their own detection rather than a backstop for this one.
