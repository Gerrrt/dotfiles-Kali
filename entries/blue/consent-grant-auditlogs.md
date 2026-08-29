---
id: consent-grant-auditlogs
title: Detect illicit consent grant (Entra audit, Consent to application)
detection: kql-entra-audit
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1528]
source: Microsoft / Mandiant, illicit consent grant attacks
pair: consent-grant
---

The invariant is the consent event itself: an Entra audit "Consent to application"
where a *user* (not an admin) grants delegated permissions to a third-party app —
especially high-value mail/file scopes. Hunt `AuditLogs` for the operation and
triage by the app, the scopes, and whether the app is newly registered or
unverified. Restricting user consent to verified-publisher / low-risk scopes turns
this from detection into prevention.

This is **Entra audit telemetry (KQL / Sentinel), not the Windows Security log**,
so it lives only here in the companion — `PURPLE-TEAM.md` is scoped to on-prem
Splunk and deliberately doesn't carry cloud detections.

Admin consent lands on the *same* `Consent to application` operation, so the user-consent
invariant has to be read out of the event rather than assumed: the
`ConsentContext.IsAdminConsent` modified property is what separates the two. Without that
filter this query is noisy in any tenant that permits user consent — and it buries the
tenant-wide admin grant, which is the more serious event, in the same undifferentiated
stream.

```kql
AuditLogs
| where OperationName has "Consent to application"
| mv-expand mp = TargetResources[0].modifiedProperties
| extend prop = tostring(mp.displayName), val = tostring(mp.newValue)
| extend actor = coalesce(tostring(InitiatedBy.user.userPrincipalName), tostring(InitiatedBy.app.displayName))
| extend app = tostring(TargetResources[0].displayName)
| summarize props = make_bag(pack(prop, val)) by TimeGenerated, CorrelationId, actor, app
| extend scopes = tostring(props["ConsentAction.Permissions"]),
         is_admin_consent = tolower(tostring(props["ConsentContext.IsAdminConsent"])) has "true"
| where scopes has_any ("Mail.Read","Mail.ReadWrite","Files.Read.All","offline_access","Sites.Read.All")
| where not(is_admin_consent)          // flip to `where is_admin_consent` to hunt tenant-wide grants
| project TimeGenerated, actor, app, is_admin_consent, scopes
```

Run it both ways. A user grant is the phishing shape this pair is built around; an admin
grant on the same scopes is rarer, louder, and worse — it covers every mailbox in the
tenant at once, so it deserves its own alert rather than being filtered away as noise.
