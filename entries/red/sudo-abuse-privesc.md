---
id: sudo-abuse-privesc
title: Sudo misconfiguration → root (allowed-binary escape)
section: Linux privilege escalation
phase: Privilege Escalation
attack:
  tactic: TA0004
  techniques: [T1548.003]
platform: [linux]
source: MITRE ATT&CK T1548.003; GTFOBins sudo escapes
pair: sudo-abuse-auditd
---

Escalate through what `sudo` already lets you run. Enumerate the grant first — a
`NOPASSWD` entry, a wildcard, or a single allowed binary is usually all it takes,
because dozens of ordinary tools (`find`, `vim`, `less`, `awk`, `tar`, `env`,
`python`) can be steered into spawning a shell, and a shell launched by a
root-run process is a **root** shell. The command runs as root, so the child
inherits `euid=0` while your original login identity is still recorded underneath
it. Local privesc — runs on the box you already have a foothold on, so no target
slots.

```sh
sudo -l                               # what am I allowed to run, and as whom
sudo find . -exec /bin/sh \; -quit    # GTFOBins: an allowed binary → root shell
sudo vim -c ':!/bin/sh'               # same idea, different allowed binary
```
