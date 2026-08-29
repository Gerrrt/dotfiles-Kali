---
id: sudo-abuse-auditd
title: Detect sudo privilege escalation (root shell under a real loginuid)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0004
  techniques: [T1548.003]
source: Linux auditd syscall telemetry; loginuid-vs-euid gap + sudoers watch
pair: sudo-abuse-privesc
---

The invariant is a **privilege gap auditd preserves for you**: `sudo` changes the
effective user to root but never rewrites `auid` (the loginuid), which stays pinned
to the human who logged in. So a shell or interpreter running with `euid=0` while
`auid` is a real, non-root login user is the fingerprint of an escalation — and it
catches the GTFOBins escapes generically, because it keys on the *outcome* (a root
shell owned by a mortal login) rather than on which allowed binary was the vehicle.
Legitimate admin work trips this too, so it is a triage feed, not a silent alert:
the tell is which login user, from which session, running what.

```conf
# /etc/audit/rules.d/sudo-privesc.rules — load with `augenrules --load`
# execve by a real login user (auid>=1000), captured so the paired SYSCALL record
# carries the euid; also watch the sudoers config itself for the planted grant.
-a always,exit -F arch=b64 -S execve -F auid>=1000 -F auid!=4294967295 -F key=priv_exec
-a always,exit -F arch=b32 -S execve -F auid>=1000 -F auid!=4294967295 -F key=priv_exec
-w /etc/sudoers -p wa -k sudoers_change
-w /etc/sudoers.d/ -p wa -k sudoers_change
```

Linux auditd telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=linux sourcetype=linux:audit key=priv_exec euid=0
    comm IN ("bash","sh","dash","zsh","python","python3","perl","ruby")
| stats count values(exe) AS via values(comm) AS shell min(_time) AS first by auid, ses, host
| sort -first
```

`auid` is the human to chase — it survived the `sudo`, so it names the account that
escalated regardless of the binary used. Corroborate with the sudo record itself
(`type=USER_CMD` / the `sudo:` line in `auth.log`) to see the *allowed command* that
was the vehicle: a login user who is permitted only `sudo systemctl` but whose
`priv_exec` shell traces back to `sudo find`/`sudo vim` is abusing the grant. The
`sudoers_change` watch is the other half — it catches the misconfiguration being
*planted* (a `NOPASSWD` line dropped into `/etc/sudoers.d/`), which precedes the abuse
rather than following it. As with the persistence watches, a write there by a package
manager is baseline; one by a shell is the finding.
