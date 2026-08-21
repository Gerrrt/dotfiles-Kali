---
id: ntlm-relay-ntlmrelayx
title: NTLM relay (ntlmrelayx → SMB, no signing)
section: Poisoning & relay — Responder / ntlmrelayx
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1557.001]
platform: [windows, network]
source: hacktheplanet §"Poisoning & relay — Responder / ntlmrelayx"
pair: ntlm-relay-4624
---

Don't crack the NetNTLM hash — relay it. Capture an authentication (Responder
poisoning LLMNR/NBT-NS, or a coercion) and forward it to a host that doesn't
enforce SMB signing; you act as that user without ever knowing their password.
`-socks` parks the authenticated session so you can ride it with proxychains4
(the binary; the apt pkg `proxychains4` only *Provides:* the bare name).
Build the no-signing target list first (`nxc --gen-relay-list`).

```sh
impacket-ntlmrelayx -t smb://{{rhost}} -smb2support -socks
proxychains4 nxc smb {{rhost}}
```
