---
id: ssh-key-theft-credaccess
title: SSH private-key theft (harvest keys for lateral movement)
section: Linux credential access
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1552.004]
platform: [linux]
source: MITRE ATT&CK T1552.004; SSH private-key harvesting
pair: ssh-key-theft-auditd
---

Private keys are reusable credentials sitting in the clear. Sweep the box for them and
you inherit every host they open — the pivot that turns one foothold into many. The
obvious haul is `~/.ssh/id_*` across every home, but widen it: `.pem`/`.key`/`.ppk`
files, keys named in `~/.ssh/config` and `~/.bash_history`, and cloud/service keys under
app dirs. Unencrypted keys are usable as-is; passphrase-protected ones you crack offline
(`ssh2john`). The read is the whole attack — there is no exploit to fire. Local — no
target slots.

```sh
find / \( -name 'id_rsa' -o -name 'id_ed25519' -o -name '*.pem' \) 2>/dev/null
for h in /home/*/.ssh /root/.ssh; do cp "$h"/id_* /tmp/.k 2>/dev/null; done
grep -rIl 'BEGIN .*PRIVATE KEY' /home /root /etc /opt 2>/dev/null
```
