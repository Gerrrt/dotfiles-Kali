---
id: ssh-authkeys-auditd
title: Detect SSH authorized_keys persistence (auditd watch on key files)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098.004]
source: Linux auditd file/syscall telemetry; authorized_keys write watches
pair: ssh-authkeys-persist
---

There is no process to catch — the attack is a single append to a file — so the write
*is* the detection. Watch `authorized_keys` and alert on any modification, because a
legitimate change to one is genuinely rare: keys are normally provisioned by
configuration management, not edited by hand on the box. The discriminator is again the
writer, and here it cuts cleanly: a write by `ansible`, `puppet`, `chef-client`, or
your provisioning identity is expected; a write by `bash`, `tee`, `vi`, `sshd`'s own
session shell, or anything under `/tmp` is the finding. The hard part is coverage, not
logic — the files are scattered across every home directory.

```conf
# /etc/audit/rules.d/ssh-keys.rules — load with `augenrules --load`
# root and the service accounts are nameable; cover /home with a directory watch.
-w /root/.ssh/authorized_keys -p wa -k ssh_authkeys
-w /etc/ssh/sshd_config -p wa -k ssh_authkeys
-w /etc/ssh/sshd_config.d/ -p wa -k ssh_authkeys
-w /home -p wa -k ssh_authkeys
```

Linux auditd telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=linux sourcetype=linux:audit key=ssh_authkeys name="*authorized_keys*"
| stats values(exe) AS via values(name) AS file min(_time) AS first by auid, key
| sort -first
```

The `/home` watch is broad on purpose — it is the only way to cover an
`authorized_keys` under an arbitrary user — so filter the results to paths ending in
`authorized_keys` and rank by writer, rather than trying to enumerate every home in the
rule. Keep the separate `sshd_config` / `sshd_config.d` watch: it catches the
`AuthorizedKeysCommand` variant that plants the key logic in config instead of the file,
which the `authorized_keys` watch never sees. A hit there should be read alongside an
`sshd` restart/reload.
