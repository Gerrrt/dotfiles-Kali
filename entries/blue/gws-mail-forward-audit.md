---
id: gws-mail-forward-audit
title: Detect external mail forwarding (Google Workspace audit)
detection: gws-audit-log
event_ids: []
attack:
  tactic: TA0009
  techniques: [T1114.003]
source: Google Workspace BEC (external auto-forwarding)
pair: gws-mail-forward
---

`email_forwarding_out_of_domain` is the invariant — a mailbox set to auto-forward outside
the org, the durable exfil channel behind most BEC. Enabling it is uncommon and rarely
legitimate for external destinations, so alert on any occurrence, prioritize forwarding to
new/free-mail domains, and pair with the admin setting that disables automatic external
forwarding org-wide. Also watch delegate-access and filter-create events for the same intent.

The event is a **User Accounts** audit activity — it sits under `user_accounts` with
`2sv_enroll` and `password_edit`, not under the Gmail application, which is why the sourcetype
below looks like the login feed. It carries the destination as
**`email_forwarding_destination_address`**; that is the parameter Google documents and emits,
so select it by that name rather than a shorter guess, or the alert fires with an empty
destination column and triage stalls on the one field it needs.

```spl
index=gws sourcetype=gws:reports:user_accounts eventName=email_forwarding_out_of_domain
| table _time, actor.email, email_forwarding_destination_address, ipAddress
```

**Coverage caveat — the API path.** The paired attack enables forwarding through the **Gmail
API** (`users.settings.updateAutoForwarding`), not the Gmail settings UI. Google documents
neither that this emits `email_forwarding_out_of_domain` nor that it does not, and it cannot
be settled from outside a tenant: verify it in your own before treating the query above as
complete coverage. Until you have, do not assume a single-arm detection here — the signals
below are complementary coverage, not optional extras.

The org-wide policy change is the other half. An attacker who needs external forwarding
*permitted* before their rule will stick flips the Gmail setting for the org or an OU, and
that lands on the admin feed as `CHANGE_APPLICATION_SETTING` for the Gmail application:

```spl
index=gws sourcetype=gws:reports:admin eventName=CHANGE_APPLICATION_SETTING APPLICATION_NAME=Gmail
| table _time, actor.email, SETTING_NAME, NEW_VALUE, ORG_UNIT_NAME, ipAddress
| sort -_time
```

Confirm the parameter names against your add-on's field extraction before alerting — Google
documents the event and its `APPLICATION_NAME`/`SETTING_NAME`/`NEW_VALUE` parameters, but
Splunk add-ons differ in how they flatten them.

Round it out with the two same-intent channels that route mail without touching the forwarding
setting at all: **mailbox delegation** (a granted delegate reads the mail in place) and
**filter creation** with a forward action. Both live in the Gmail log events rather than
`user_accounts`; hunt them on the same trigger — a new external destination on a mailbox that
never had one.

Google Workspace audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.
