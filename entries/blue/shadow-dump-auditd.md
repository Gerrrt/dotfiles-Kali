---
id: shadow-dump-auditd
title: Detect /etc/shadow read (auditd read watch, non-auth reader)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1003.008]
source: Linux auditd read-access telemetry; /etc/shadow reader allowlist
pair: shadow-dump-credaccess
---

`/etc/shadow` is a file almost nothing should *read*, which is what makes a read watch
on it high-fidelity — unlike the persistence writes and the privesc perm-changes, the
volume here is naturally low. The legitimate readers are a short, nameable set: the auth
stack (`unix_chkpwd`, `sshd`, `login`, `su`, `sudo`), the account tools (`passwd`,
`chpasswd`, `chage`, `pwck`), and backup/config-management agents. Anything else reading
it — `cat`, `cp`, `dd`, `tail`, an interpreter, `unshadow`, or a binary running out of
`/tmp` / `/dev/shm` — is the finding. Add the `-p r` watch (auditd catches reads only
when you ask it to) and allowlist the readers rather than enumerate the attackers.

```conf
# /etc/audit/rules.d/shadow-read.rules — load with `augenrules --load`
-w /etc/shadow -p r -k shadow_read
-w /etc/gshadow -p r -k shadow_read
```

Linux auditd telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=linux sourcetype=linux:audit key=shadow_read
    NOT comm IN ("unix_chkpwd","sshd","login","su","sudo","passwd","chpasswd","chage","pwck","systemd")
| stats count values(exe) AS via values(name) AS file min(_time) AS first by auid, comm, host
| sort -first
```

The reading process is the discriminator, and `auid` names who ran it — a `cat
/etc/shadow` traces back to the human even when it runs as root, the same loginuid
survival the privesc pairs lean on. Tune the allowlist to your host's real auth stack
(distros differ — `unix2_chkpwd`, `systemd-userdbd`, a vendor backup agent), and treat a
newly-appearing reader as more interesting than a long-baselined one. `/etc/passwd` is
world-readable so a read of it is not worth watching on its own; the shadow read is the
event, and `unshadow` needs it.
