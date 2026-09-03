---
id: ssh-key-theft-auditd
title: Detect SSH private-key theft (auditd read watch, cross-user sweep)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1552.004]
source: Linux auditd read-access telemetry; private-key reader + fan-out shape
pair: ssh-key-theft-credaccess
---

Harder than the shadow read, and the entry should say so: a private key is *supposed* to
be read on every outbound SSH, so a per-read alert on key files is pure noise. Two
signals cut through it. First, the **reader**: the baseline readers of a private key are
`ssh`, `sshd`, `ssh-agent`, `scp`, `sftp`, and `git`; a key read by `cat`, `cp`, `tar`,
`grep`, an interpreter, or a `/tmp` binary is the tell. Second, the **fan-out**: a
legitimate SSH reads *one* user's *own* key, while the theft sweep reads keys across
*many* users' `.ssh` dirs — one process, one `auid`, many distinct owning homes in a
short window is the shape no single login produces. Alert on the shape, triage by the
reader.

```conf
# /etc/audit/rules.d/ssh-key-read.rules — load with `augenrules --load`
# private-key reads are scattered across homes; a /home + /root read watch is the
# only way to cover an arbitrary user's key. Broad by necessity, narrowed in query.
-w /root/.ssh/ -p r -k sshkey_read
-w /home -p r -k sshkey_read
-w /etc/ssh/ -p r -k sshkey_read
```

Linux auditd telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=linux sourcetype=linux:audit key=sshkey_read
    (name="*/id_rsa" OR name="*/id_ed25519" OR name="*/id_ecdsa" OR name="*/id_dsa"
     OR name="*.pem" OR name="*.key" OR name="*.ppk")
    NOT comm IN ("ssh","sshd","ssh-agent","scp","sftp","git","systemd")
| eval home=replace(name,"(/home/[^/]+|/root)/.*","\1")
| stats dc(home) AS homes_swept values(comm) AS reader values(name) AS keys min(_time) AS first
    by auid, ses, host
| where homes_swept > 1 OR reader!=""
| sort -homes_swept -first
```

The `/home` read watch is broad on purpose — it is the same trade-off as the
`authorized_keys` write watch, and the same fix: filter to key-file names in the query,
rank by reader and by `homes_swept`, rather than trying to name every home in the rule.
`homes_swept > 1` is the strong arm (a cross-user sweep has no benign explanation); the
reader allowlist is the weaker arm that catches a single-key grab. Expect to tune the
baseline readers — backup agents, `rsync`, and config management legitimately read key
paths — and treat the `dc(home)` fan-out as the signal you would page on.
