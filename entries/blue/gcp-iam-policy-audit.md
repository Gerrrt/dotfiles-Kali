---
id: gcp-iam-policy-audit
title: Detect IAM policy backdoor (GCP audit, SetIamPolicy binding ADD)
detection: gcp-logging
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: GCP IAM abuse (resource IAM policy binding persistence)
pair: gcp-iam-policy-backdoor
---

Every IAM grant lands in Cloud Audit Logs (Admin Activity) as a `SetIamPolicy`
call whose `serviceData.policyDelta.bindingDeltas` carries the `ADD` action, the
role, and the member. Alert on additions of sensitive roles
(`roles/owner`, `roles/editor`, `*Admin`) or grants to unexpected/external
principals — and treat a binding whose member is `allUsers`/`allAuthenticatedUsers`
as an immediate, standalone finding.

**Match the member independently of the role.** A public grant is the finding at
*any* role — `roles/viewer` to `allUsers` exposes the resource just as surely as
`roles/owner` does — so the member test cannot sit behind a sensitive-role
allowlist or the query is blind to the case this entry calls standalone. Keep the
two as separate branches of one OR: member-is-public, or role-is-sensitive. The
role branch matches `[aA]dmin$` rather than a fixed list, which covers
`resourcemanager.projectIamAdmin`, `iam.securityAdmin`,
`resourcemanager.organizationAdmin` and **custom** admin roles alike;
`serviceAccountTokenCreator`/`serviceAccountUser` are named separately because
they are impersonation privesc and do not end in `Admin`.

GCP Cloud Audit Logs telemetry (native Cloud Logging filter below; also queryable
as Sentinel `GCPAuditLogs`), companion-only — `PURPLE-TEAM.md` is on-prem Windows.
Triage each hit by `protoPayload.authenticationInfo.principalEmail` (the actor)
and the added `member`/`role`.

```text
logName=~"cloudaudit.googleapis.com%2Factivity"
protoPayload.methodName=~"SetIamPolicy$"
protoPayload.serviceData.policyDelta.bindingDeltas.action="ADD"
(
  protoPayload.serviceData.policyDelta.bindingDeltas.member=("allUsers" OR "allAuthenticatedUsers")
  OR protoPayload.serviceData.policyDelta.bindingDeltas.role=~"^roles/(owner|editor)$"
  OR protoPayload.serviceData.policyDelta.bindingDeltas.role=~"[aA]dmin$"
  OR protoPayload.serviceData.policyDelta.bindingDeltas.role=~"iam\.serviceAccount(TokenCreator|User)$"
)
```

One triage caveat: `bindingDeltas` is a *repeated* field, so Cloud Logging tests
each condition against **any** element of the array — the `action`, `member` and
`role` clauses above can be satisfied by three different deltas of the same
`SetIamPolicy` call (a policy edit that removes a public binding while adding an
unrelated one still matches). Read the full `bindingDeltas` array on the hit
rather than trusting the filter, and confirm the `ADD` and the member belong to
the same delta.
