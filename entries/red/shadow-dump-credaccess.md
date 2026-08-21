---
id: shadow-dump-credaccess
title: /etc/shadow dump (offline hash cracking)
section: Linux credential access
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1003.008]
platform: [linux]
source: MITRE ATT&CK T1003.008; unshadow + hashcat
pair: shadow-dump-auditd
---

Once you are root, the local password hashes are yours to take offline. `/etc/shadow`
holds the crypt hashes (`$6$` yescrypt/SHA-512, `$y$` yescrypt) and is `root`-readable
only; pair it with world-readable `/etc/passwd` via `unshadow` to feed a cracker.
Nothing exploitable happens on the box — you exfil the file and crack elsewhere, which
is exactly why the *read* is the only thing a defender can catch. Local — no target
slots.

```sh
cat /etc/shadow                                   # the hashes (root-only read)
unshadow /etc/passwd /etc/shadow > /tmp/.h        # merge for the cracker
hashcat -m 1800 /tmp/.h wordlist.txt              # $6$ SHA-512crypt, offline
```
