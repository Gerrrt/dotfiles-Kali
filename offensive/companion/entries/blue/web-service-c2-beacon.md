---
id: web-service-c2-beacon
title: Detect web-service C2 (non-browser process to SaaS API)
detection: splunk-spl
event_ids: [3]
attack:
  tactic: TA0011
  techniques: [T1102.002]
source: Sysmon Network Connection (Event ID 3) process attribution
pair: web-service-c2-telegram
---

The destination is trusted, so pivot off the *source process*, not the domain — a
domain allowlist just moves the goalposts to the next trusted SaaS (Discord,
Dropbox, Pastebin, Google Drive, Notion are all documented web-service C2). Sysmon
Event ID 3 attributes each outbound connection to its `Image`; browsers, mail
clients, Teams, and updaters talk to SaaS APIs — `powershell.exe`, `wscript.exe`, a
random binary in `%TEMP%`, or an Office child process beaconing to *any* SaaS API on
an interval does not. Gate on the process: exclude the known API-consumers, weight
images in user-writable paths (`\Users\`, `\AppData\`, `\Temp\`, `\ProgramData\`),
and alert when such a process makes repeated 443 connections to a host that is rare
*for that host*. The four domains below are a seed IOC list to triage first, **not**
the gate.

```spl
index=sysmon EventCode=3 Initiated=true DestinationPort=443
| search NOT (Image="*\\chrome.exe" OR Image="*\\msedge.exe" OR Image="*\\firefox.exe" OR Image="*\\Teams.exe" OR Image="*\\OneDrive.exe" OR Image="*\\outlook.exe" OR Image="*\\Dropbox.exe" OR Image="*\\slack.exe" OR Image="*\\Code.exe")
| eval user_writable=if(match(Image,"(?i)\\\\(Users|AppData|Temp|ProgramData|Public)\\\\"),1,0)
| bucket _time span=1h
| stats count as conns, dc(_time) as active_hours, values(DestinationHostname) as dests by host, Image, User, DestinationIp, user_writable
| where conns>3 AND active_hours>2
| sort -user_writable -conns
```

Seed list for a fast first triage (relabel, don't gate):
`api.telegram.org`, `*.slack.com`, `api.github.com`, `gist.githubusercontent.com`.

**Tune per host role before deploying.** The exclusion list above is a *Windows
desktop* one. On servers and CI/build agents the same thresholds fire on ordinary
work: `python.exe`, `node.exe`, `curl.exe`, `git.exe`, and agent binaries under
`\ProgramData\` legitimately make repeated 443 calls to package registries and SaaS
APIs all day. The `user_writable` weighting then works against you: that field is
just this query's own heuristic — its regex matches `\ProgramData\` (and `\Users\`,
`\AppData\`, `\Temp\`, `\Public\`) as a *proxy* for drop-site paths, not a claim
about the ACLs — and on a build agent the legitimate tooling lives in exactly those
directories, so the signal you meant to rank droppers by ranks the agent. Split the
search by host role
(or join an asset/CMDB lookup) and give server and CI fleets their own exclusion
list and a higher `conns`/`active_hours` floor — otherwise the process-context
discipline this detection is built on is lost to volume.
