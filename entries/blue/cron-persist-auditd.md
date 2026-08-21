---
id: cron-persist-auditd
title: Detect cron persistence (auditd watches on cron paths)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1053.003]
source: Linux auditd file/syscall telemetry; cron drop-directory watches
pair: cron-persist
---

Cron persistence is a *write to a cron path*, so watch the paths rather than the
`crontab` binary — an attacker who drops a file into `/etc/cron.d/` never runs
`crontab` at all. Add auditd watches on the directories cron reads and alert on any
write, then triage by who wrote it: package managers (`dpkg`, `rpm`, `apt`) touch
these paths legitimately, so the tell is a write whose triggering process is a shell,
an interpreter, or something running out of `/tmp` — not a periodic write from an
unexpected `auid`. This needs the rules **in place before** the write; auditd watches
nothing by default.

```conf
# /etc/audit/rules.d/cron.rules — load with `augenrules --load`
-w /etc/cron.d/ -p wa -k cron_persist
-w /etc/crontab -p wa -k cron_persist
-w /etc/cron.hourly/ -p wa -k cron_persist
-w /etc/cron.daily/ -p wa -k cron_persist
-w /etc/cron.weekly/ -p wa -k cron_persist
-w /etc/cron.monthly/ -p wa -k cron_persist
-w /var/spool/cron/ -p wa -k cron_persist
```

Linux auditd telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=linux sourcetype=linux:audit key=cron_persist
| stats values(exe) AS via values(name) AS path min(_time) AS first by auid, key
| sort -first
```

The `exe`/`comm` that triggered the watch is the discriminator — surface it. A write
from `/usr/bin/dpkg` on a maintenance window is the baseline; the same write from
`bash`, `python3`, `perl`, or a binary under `/tmp` or `/dev/shm` is the finding.
Pair with process-execution telemetry (`execve` of `crontab` with a non-interactive
parent) to catch the per-user `crontab -` path that writes `/var/spool/cron/` through
the setuid binary rather than as a plain file write.
