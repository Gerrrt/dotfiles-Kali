---
id: suid-abuse-auditd
title: Detect SUID abuse (setuid-bit change + root shell under a real loginuid)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0004
  techniques: [T1548.001]
source: Linux auditd syscall telemetry; chmod setuid watch + loginuid-vs-euid gap
pair: suid-abuse-privesc
---

Two moments are catchable, and they are different events. **Planting** a SUID bit is a
`chmod`/`fchmodat` that sets mode `04000` — auditd sees the syscall, and a new
setuid-root file (especially a shell or interpreter) is high-signal because legitimate
SUID binaries are installed by packages, not `chmod`'d into existence at runtime.
**Abusing** an existing SUID binary produces the same fingerprint the sudo path does:
a root shell (`euid=0`) whose `auid` is still a real login user, because the setuid
transition, like sudo, never rewrites the loginuid. Watch both.

```conf
# /etc/audit/rules.d/suid-privesc.rules — load with `augenrules --load`
# perm changes by a real login user (the chmod u+s plant); the b64/b32 split matters.
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=4294967295 -F key=suid_change
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=4294967295 -F key=suid_change
```

Linux auditd telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows. The abuse
arm reuses `priv_exec` from `sudo-abuse-auditd` — the loginuid-vs-euid gap is one
invariant covering every escalation that leaves `auid` behind, sudo and SUID alike.

```spl
index=linux sourcetype=linux:audit key=suid_change
| stats values(exe) AS via values(name) AS target min(_time) AS first by auid, ses, host
| sort -first
```

The `chmod` watch is deliberately broad — auditd cannot cheaply filter the rule down to
*only* the setuid bit across every `chmod` variant, so the rule catches all
perm changes by real users and the triage narrows to the setuid case: a mode that sets
`04000`, and a target that is a shell/interpreter or a file outside the baseline SUID
set (`find / -perm -4000` on a known-good host gives you that baseline). Do not tighten
the rule into silence — the same broad-catch, narrow-in-query shape the cron and systemd
watches use. For the abuse path, run `sudo-abuse-auditd`'s `priv_exec euid=0` query:
a root shell under a mortal `auid` is the outcome whether the vehicle was `sudo` or a
setuid binary, and the parent `exe` tells you which.
