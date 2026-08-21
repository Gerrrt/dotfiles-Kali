---
id: systemd-persist-auditd
title: Detect systemd unit persistence (auditd watches on unit dirs)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1543.002]
source: Linux auditd file/syscall telemetry; systemd unit-directory watches
pair: systemd-persist
---

The invariant is a *new or modified unit file* in a directory systemd loads from,
followed by a `daemon-reload`/`enable` to activate it. Watch the unit dirs the way you
watch the cron dirs — the write is the event, and the process behind it is the
discriminator. Package installs and `systemctl` itself write here legitimately, so the
finding is a unit file authored by a shell/interpreter or landing from a temp path, not
a `.service` dropped by `dpkg` during a maintenance window. Do not forget the per-user
tree: an unprivileged implant persists under `~/.config/systemd/user/` without ever
touching a root-owned path. auditd watches nothing by default — load these first.

```conf
# /etc/audit/rules.d/systemd.rules — load with `augenrules --load`
-w /etc/systemd/system/ -p wa -k systemd_persist
-w /usr/lib/systemd/system/ -p wa -k systemd_persist
-w /run/systemd/system/ -p wa -k systemd_persist
```

Linux auditd telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=linux sourcetype=linux:audit key=systemd_persist name="*.service" OR name="*.timer"
| stats values(exe) AS via values(name) AS unit min(_time) AS first by auid, key
| sort -first
```

Rank on `exe`/`comm`: a unit written by `bash`, `python3`, `tee`, or a binary under
`/tmp` / `/dev/shm` is the tell; one written by the package manager is baseline. The
per-user watch cannot be a single root-tree rule — home directories vary — so cover it
with a watch on `/home` unit paths or with process telemetry for `systemctl --user
enable` from a non-interactive parent. Corroborate any hit with the activation step
(`execve` of `systemctl` with `daemon-reload`/`enable`), which the write alone does not
capture.
