---
id: smb-enum-5145
title: Detect SMB share/session enumeration (5145 srvsvc/wkssvc fan-out)
detection: splunk-spl
event_ids: [5145]
attack:
  tactic: TA0007
  techniques: [T1135, T1087.002]
source: dotfiles-Defense detections/sigma/discovery/host_enum_srvsvc_wkssvc_5145.yml
pair: smb-enum-nxc
---

Enumeration has no bad event — opening a file server's `IPC$` is what happens when a
user browses a share. The invariant is **breadth across hosts, not volume against one**:
normal use re-touches a small set of file servers all day and stays at one or two
distinct hosts, while an enumeration pass touches each host once. So count *distinct
hosts per principal* in a window; that is `nxc smb <range>` walked across a subnet,
`net view \\host` in a loop, or SharpHound's Session and LoggedOn collection.

Key on the **pipe**, not the tool. `srvsvc` and `wkssvc` are the RPC transport for the
classic Windows enumeration calls — `srvsvc` carries `NetShareEnum` (shares) and
`NetSessionEnum` (who is connected), `wkssvc` carries `NetWkstaUserEnum` (who is logged
on). That set is **disjoint** from the other two 5145 detections in this corpus, and the
split is the whole point rather than an oversight to consolidate later:
`coercion-5145` keys on `spoolss`/`efsrpc`/`lsarpc`/`netlogon`/`lsass` (coercion, T1187)
and `dpapi-backupkey-5145` on `protected_storage`. Same event ID, different RPC
interface, different technique.

```spl
index=main EventCode=5145 Account_Name!="*$"
| regex Share_Name="(?i).*ipc\$$"
| regex Relative_Target_Name="(?i)(srvsvc|wkssvc)"
| bin _time span=10m
| stats dc(host) AS hosts values(Relative_Target_Name) AS pipes by _time, Account_Name
| where hosts >= 10 | sort -hosts
```

`Account_Name!="*$"` drops machine accounts, which bind these pipes to each other as
routine business. Backup, monitoring and file-server-inventory platforms enumerate shares
and sessions estate-wide *by design* and are the only other principals that can reach a
double-digit host count — suppress those by name rather than lowering the threshold. A
logon-script or GPO drive-mapping run at shift change is the other false positive worth
knowing; triage on whether the fan-out is that user's normal set of servers.

Two prerequisites, both already paid for. It needs the **Detailed File Share** audit
subcategory (`5145`), which the two detections above already assume, so this costs no new
ingestion. And it is deliberately the **second** way to see this behaviour: the
process-creation view catches `net view` / `net session` on the command line, but an
operator working over SMB from a foothold — or `nxc`, making the RPC call in-process —
writes no process-creation event on the target at all. Detecting the same behaviour on
two independent feeds is the resilience, not redundancy.

The paired rule in `dotfiles-Defense` also tags T1049 (System Network Connections
Discovery) and T1033 (System Owner/User Discovery), because `NetSessionEnum` and
`NetWkstaUserEnum` ride the same two pipes. This entry keeps its pair's tags; the wider
set is the same behaviour framed from the detection side.
