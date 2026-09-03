# Purple Team — detections for the attacks in `hacktheplanet`

The offensive half of an engagement lives in
[`offensive/hacktheplanet`](offensive/hacktheplanet). This file is its mirror:
**what each of those attacks looks like to the defender**, and the philosophy
behind hunting it. Field notes from TrustedSec's *Actionable Purple Teaming*
(Black Hat USA 2023), generalized out of the lab.

> Why this lives in an offensive repo: a red operator who knows exactly which
> event ID their action writes is a better operator. Every command in
> `hacktheplanet` has a telemetry footprint — knowing it is OPSEC, and validating
> it is the entire point of purple teaming.
>
> **Defender-authored capability lives across the fence in [`dotfiles-Defense`](https://github.com/dotgibson/dotfiles-Defense).**
> This file is *attacker-authored* purple — "here's the telemetry I trip," next to the
> attack that trips it. Portable, deployable detection content (Sigma rules, Sysmon
> baselines, Zeek/Suricata tuning, SIEM saved-searches) and the Dockerized detection lab
> are a different job from a different seat, so they get their own blue Role repo. The
> split is deliberate: run the attack here, confirm the rule fires there.

---

## The philosophy

- **Purple, not red-then-blue.** Run the attack and watch the detection fire *in
  the same session*. A detection nobody has triggered on purpose is a hypothesis,
  not a control. Execute → confirm the alert → tune → repeat.
- **Detect on the invariant, not the IOC.** Tool names, file hashes and ports
  change for free. Detect the thing the technique *can't* avoid: Kerberoasting
  needs an RC4 service ticket (`4769`, downgraded encryption); DCSync needs the
  directory-replication right (`4662`); a relay produces a logon whose source
  host ≠ the account's own host. Those don't change when the attacker swaps tools.
- **Honey tokens are the cheapest high-signal control.** A fake user that no
  human should ever touch, a fake SPN no service should ever request — any hit is
  true-positive by construction. Near-zero false positives, near-zero cost.
- **Coverage is a license/logging problem too.** You can't alert on a log you
  don't keep. Sysmon for process/inject visibility on endpoints; in M365, audit
  retention and the high-value events (MailItemsAccessed, Send) gate on the E5/G5
  tier. Decide what you're blind to *before* the assessment.
- **Red OPSEC is the other side of the same coin.** In-memory `execute-assembly`
  / BOFs avoid the `4688` that a dropped binary or `cmd /c` would write — so the
  defender's answer is endpoint telemetry (Sysmon, AMSI, EDR), not just the
  Windows Security log.

---

## Attack → detection map (Splunk SPL unless noted)

Queries assume a Windows Security / Sysmon feed in `index=main`. Field names
follow the common Splunk add-on schema — adjust to your CIM/normalization.

> Blocks fenced by `<!-- companion:gen ID -->` markers are **generated** from the
> structured companion (`offensive/companion/entries/`), which is canonical for
> those — edit the entry and run `offensive/companion/gen-views.sh`, not the block
> here (CI rejects a hand-edit). Everything outside the markers is hand-authored.
>
> **Scope: this map is the Windows Security / Sysmon mirror.** Every section below
> keys off a Windows event ID, which is why only 24 of the companion's 102 blue
> entries project here. The other 78 mostly detect in logs this file has no section for —
> AWS CloudTrail, GCP audit logs, Entra sign-in/audit, Okta system log, GitHub/GitLab
> audit, Vault audit device, Snowflake account usage — plus the C2-egress and Impact
> detections. Read those with `htpx` (`~/companion`), which shows each detection
> beside the attack that trips it. That split is deliberate, not a backlog: a
> cloud-audit query has nothing to do with a Sysmon feed in `index=main`.
>
> Of those 78, **69** genuinely carry no Windows event ID. Seven of the remaining
> nine are the C2-egress and Impact detections named above. The last two —
> `bloodhound-collect-4662` and `ldap-recon-4662` — key off event **4662**, which is
> this file's own criterion for projecting, and yet project nowhere. That pair is a
> real gap rather than part of the split, and it mirrors exactly the two unprojected
> red entries `hacktheplanet` now flags. Read them with `htpx` until it is closed.
>
> These counts are hand-maintained and go stale on every `companion-sync`. No htpx version
> is named here on purpose — one stamped into prose rots the way these counts did;
> `companion.lock` names the vendored revision. `make view-counts` checks them now, so a
> stale number is CI's problem rather than a reader's; if they disagree with
> `ls offensive/companion/entries/blue | wc -l`, this file is wrong, not the corpus.

### Recon / credential access

<!-- companion:gen password-spray-4625 -->
**Detect password spray (one source, many accounts — 4771 + 4625)**

The shape, not the count: one source address failing against many *distinct*
accounts in a short window — the inverse of a single user who simply forgot
their password. Counting distinct accounts per source beats a raw failure-rate
threshold because the spray is deliberately slow.

Which event carries that shape depends on the spray path, and getting this wrong
is how a spray detection misses. `kerbrute passwordspray` sprays **Kerberos
AS-REQ pre-authentication**, so a wrong password lands on the DC as `4771` with
`Failure_Code=0x18` — it never generates `4625`, which is the
NTLM/interactive/SMB logon-failure event. Key on `4771` first; keep `4625` for
the NTLM/SMB path (`nxc smb ... -p`), where it is the right event.

```spl
index=main EventCode=4771 Failure_Code="0x18" Account_Name!="*$"
| stats dc(Account_Name) AS Accounts values(Account_Name) by host, Client_Address
| where Accounts > 10 | sort -Accounts
```

Secondary — the NTLM/SMB/interactive spray path, where the same one-source-to-
many-accounts shape shows up as `4625` instead:

```spl
index=main EventCode=4625 NOT (Source_Network_Address IN ("-","127.0.0.1"))
| eval Account=mvindex(Account_Name,1)
| stats dc(Account) AS Accounts by host, Source_Network_Address
| where Accounts > 10 | sort -Accounts
```
<!-- companion:end password-spray-4625 -->

<!-- companion:gen asrep-roast-4768 -->
**Detect AS-REP roast (4768 no-preauth)**

Detect on the invariant, not the IOC. The roastable AS-REP is a *successful*
`4768` TGT request with **pre-authentication type 0** (no pre-auth) for a
non-machine account — that is the account `GetNPUsers`/`--asreproast` actually
harvests. The AS-REP is issued under the account's long-term key — RC4 (`0x17`)
where it's enabled, AES (`0x11`/`0x12`) in RC4-disabled domains — and cracked
offline (`hashcat -m 18200` for the RC4 case). Unlike Kerberoasting the attacker
doesn't force the etype, so the *invariant* is the type-0 pre-auth on a user, not
the negotiated cipher — key on it directly and don't constrain the encryption
type, or AES-only domains slip through. A normal account pre-auths with type 2
(encrypted timestamp), so type 0 on a user is the tell.

```spl
index=main EventCode=4768 Pre_Authentication_Type=0 Account_Name!="*$"
| stats count values(Account_Name) AS Accounts by Client_Address
| sort -count
```

**Not here:** the one-source-to-many-accounts `4771 Failure_Code=0x18` burst. It is a real
signal, but it is *not* this technique — it fires on wrong-password pre-auth failures against
pre-auth-**required** accounts (Kerbrute enum / spraying) and never on the roast itself, which
succeeds. It is `password-spray-4625`'s primary query, at a threshold tuned for it; running a
lower-threshold copy here only doubles the alerts on someone else's finding. Pivot to that
entry when the two fire together — enumeration followed by roasting is one operator working
through the domain.
<!-- companion:end asrep-roast-4768 -->

<!-- companion:gen kerberoasting-4769 -->
**Detect Kerberoasting (4769 TGS request)**

Detect on the invariant, not the IOC — and the invariant here is **not** the cipher.
An RC4 (`0x17`) service ticket for a non-machine, non-krbtgt SPN is the loudest
version of this: tools like Orpheus, and Rubeus' `/tgtdeleg` route, force RC4
precisely to keep the roast crackable, so the downgrade is a near-free true positive.
But the paired red (`impacket-GetUserSPNs -request`, `nxc --kerberoasting`) does *not*
force the etype — the TGS is issued under the SPN account's
`msDS-SupportedEncryptionTypes`, so an AES-only service account yields a `0x11`/`0x12`
ticket and cracks fine (`hashcat -m 19700`). A `0x17`-only filter never sees it. Same
lesson as `asrep-roast-4768`: don't constrain the encryption type or AES-only domains
slip through.

So key on both — RC4 on a user SPN as the fast path, and the shape the roast can't
hide at any etype: one client pulling tickets for *many distinct* SPN accounts in a
burst. A workstation legitimately touches a handful of services; it does not enumerate
thirty.

```spl
index=main EventCode=4769 Service_Name!="*$" Service_Name!="krbtgt"
    (Ticket_Encryption_Type=0x17 OR Ticket_Encryption_Type=0x11 OR Ticket_Encryption_Type=0x12)
| eval rc4=if(Ticket_Encryption_Type=="0x17", 1, 0)
| stats dc(Service_Name) AS ServiceAccounts values(Service_Name) AS Services
        max(rc4) AS RC4_Downgrade by Client_Address, Account_Name
| where RC4_Downgrade=1 OR ServiceAccounts>=5
| sort -RC4_Downgrade, -ServiceAccounts
```

Tune `ServiceAccounts` to your environment before trusting the AES arm — the count that
means "enumeration" depends on how many SPNs a normal client touches. Baselining the
requesting account against its own history beats a global threshold where you can
afford to keep the state.
<!-- companion:end kerberoasting-4769 -->

<!-- companion:gen golden-ticket-4769 -->
**Detect Golden Ticket (4769 with no preceding 4768)**

A forged TGT is minted offline, so the account uses Kerberos services (`4769` TGS
requests) without the DC ever issuing it a TGT (`4768`). Per account+host window,
a principal with TGS activity but zero TGT issuance is the invariant. Secondary
tells back it up: RC4 (`0x17`) when the realm is otherwise AES, and absurd ticket
lifetimes. Tune the window to your normal ticket-renewal cadence.

```spl
index=main EventCode IN (4768,4769) Account_Name!="*$"
| stats sum(eval(EventCode==4768)) AS tgts sum(eval(EventCode==4769)) AS tgs_reqs
    by Account_Name, Client_Address
| where tgs_reqs > 0 AND tgts == 0
```
<!-- companion:end golden-ticket-4769 -->

<!-- companion:gen silver-ticket-4769 -->
**Detect Silver Ticket (Kerberos service logon with no 4769)**

Detection posture: **soft** — a silver ticket's whole point is that it never
touches the DC, so there is no `4769` to alert on directly. The realistic tell is
the *absence*: a Kerberos network logon (`4624` type 3) landing on a service host
for an account the DC issued no service ticket (`4769`) to in the window. Correlate
by `Account_Name` in a single pass (no fragile `join`/subsearch): pull both event
types and compare per-account counts. Set the search/alert **time range** to your
ticket-renewal cadence (a few hours). The durable backstop is enabling PAC
validation, which rejects the forged ticket outright.

```spl
index=main (EventCode=4624 Logon_Type=3 Authentication_Package_Name="Kerberos" Account_Name!="*$")
    OR EventCode=4769
| stats sum(eval(EventCode==4624)) AS kerb_logons sum(eval(EventCode==4769)) AS tgs_issued
    values(Source_Network_Address) AS sources by Account_Name
| where kerb_logons > 0 AND tgs_issued == 0
```
<!-- companion:end silver-ticket-4769 -->

<!-- companion:gen gpp-cpassword-5145 -->
**Detect GPP cpassword hunt (5145 SYSVOL Groups.xml read)**

The decrypt is offline, so the only on-wire moment is reading the GPP XML out of
SYSVOL — a `5145` detailed-file-share-access event on the `SYSVOL` share whose
relative target ends in a credential-bearing GPP file. Group Policy clients read
these too, so scope to *interactive* accounts (not `*$` machine accounts).
Honey-policy a fake `Groups.xml` for a near-zero-false-positive tripwire.

```spl
index=main EventCode=5145 Share_Name="*SYSVOL*" Account_Name!="*$"
| regex Relative_Target_Name="(?i)(Groups|Services|ScheduledTasks|Printers|DataSources)\.xml$"
| table _time, host, Account_Name, Source_Address, Relative_Target_Name
```
<!-- companion:end gpp-cpassword-5145 -->

<!-- companion:gen smb-enum-5145 -->
**Detect SMB share/session enumeration (5145 srvsvc/wkssvc fan-out)**

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
<!-- companion:end smb-enum-5145 -->

**LDAP recon by one principal** — explicit-cred logons `4648` fanning out:

```spl
index=main EventCode=4648 Network_Address!="-"
| stats count by host, Network_Address | sort -count

```

### Poisoning, relay, coercion

<!-- companion:gen ntlm-relay-4624 -->
**Detect NTLM relay (4624 workstation mismatch)**

A relayed logon carries the *victim's* workstation name but arrives from the
*relay's* source address — so the tell is a `4624` whose `Workstation_Name`
doesn't resolve to its `Source_Network_Address`. That mismatch is the invariant;
the attacker can't relay without it.

```spl
index=main EventCode=4624 Workstation_Name!="-" Source_Port!="0"
| eval RelayedFrom=if(host!=Workstation_Name, Workstation_Name, "")
| lookup dnslookup clienthost AS RelayedFrom OUTPUT clientip AS IP
| where RelayedFrom!="" AND Source_Network_Address!=IP
| table _time, host, Account_Name, Source_Network_Address, RelayedFrom, IP
```
<!-- companion:end ntlm-relay-4624 -->

<!-- companion:gen coercion-5145 -->
**Detect coercion (5145 named-pipe access)**

Every coercion vector reaches the same handful of named pipes over `IPC$`, with a
detailed file-share-access event (`5145`). Detect on the pipe set, not the tool: the
target endpoint can't change even as the coercion technique does.

The set is the union of the three protocols that carry coercion, and each name in it
earns its place:

- **MS-EFSR** (PetitPotam) is exposed over **five** pipes — `efsrpc`, `lsarpc`, `samr`,
  `lsass`, `netlogon`. Note that `\pipe\lsass` really is one of them: it is an RPC
  endpoint the EFSRPC interface binds to, *not* the LSASS process appearing by name, and
  PetitPotam and `coercer` both spray it. Dropping it because it reads like a process
  name opens a hole on the vector's most-used path.
- **MS-RPRN** (printerbug) → `spoolss`.
- **MS-DFSNM** (DFSCoerce) → `netdfs`, DC-only.

```spl
index=main EventCode=5145
| regex Share_Name="(?i).*ipc\$$"
| regex Relative_Target_Name="(?i)(spoolss|efsrpc|lsarpc|netlogon|lsass|samr|netdfs)"
| table _time, host, Account_Name, Source_Address, Share_Name, Relative_Target_Name, Access_Mask
```

`Access_Mask` is reported rather than filtered. `0x3` (read+write) is what a typical RPC
pipe bind requests and is a reasonable tightening if this is noisy in your environment —
but as a *filter* it is a silent drop for any client that opens the pipe with a different
mask, which trades away the whole premise that the endpoint is the invariant and the tool
is not. Tighten only after confirming the masks you actually observe.
<!-- companion:end coercion-5145 -->

### Lateral movement & dumping

<!-- companion:gen lateral-4624-fanout -->
**Detect pass-the-hash lateral movement (4624 type-3 NTLM fan-out)**

One source address logging on (`4624` type 3, network) to many distinct hosts in
a short window is the reuse pattern — pass-the-hash, sprayed creds, or a relay all
fan out the same way. The auth succeeds, so the signal is the breadth, not a
failure.

Breadth alone is not enough, though: type-3 network logons are the most common event
in a Windows estate, and any backup agent, scanner, or management server fans out the
same shape all day. **Pass-the-hash is specifically an NTLM authentication** — the NT
hash *is* the NTLM secret, so `nxc -H`, `evil-winrm -H` and `impacket-psexec -hashes`
all land on the target as a type-3 logon with `Authentication_Package="NTLM"` and
`Logon_Process="NtLmSsp"`. Key on that first; it is the discriminator that separates
the paired attack from ordinary network-logon fan-out, and it lets the host floor rise
past the noise.

```spl
index=main EventCode=4624 Logon_Type=3
    (Authentication_Package="NTLM" OR Logon_Process="NtLmSsp")
    NOT (Source_Network_Address IN ("-","::1","127.0.0.1"))
| eval Account=mvindex(Account_Name,1)
| stats dc(host) AS Hosts values(host) AS Hosts_Seen by Source_Network_Address, Account
| where Hosts > 4 | sort -Hosts
```

Keep the package-agnostic sweep as a second, broader hunt — it is noisier by
construction, so run it as a hunt rather than an alert. It covers the sibling
techniques the NTLM clause deliberately excludes: **overpass-the-hash** converts the
hash into a Kerberos TGT and then authenticates as Kerberos, and a `4624` fan-out
with a *mixed* authentication package for one account is itself worth a look:

```spl
index=main EventCode=4624 Logon_Type=3 NOT (Source_Network_Address IN ("-","::1","127.0.0.1"))
| eval Account=mvindex(Account_Name,1)
| stats dc(host) AS Hosts values(Authentication_Package) AS Packages by Source_Network_Address, Account
| where Hosts > 4 | sort -Hosts
```

Baseline before alerting either way. Legacy applications, IP-literal SMB access and
inter-forest access all produce legitimate NTLM, so the floor is environment-specific —
tune it to your estate rather than trusting the number above, and treat a source that
has never fanned out before as more interesting than one that always does.
<!-- companion:end lateral-4624-fanout -->

<!-- companion:gen lsass-4656 -->
**Detect LSASS access (4656 dump-shaped handle)**

Credential theft from memory needs a handle to `lsass` with read/dump access
rights — `4656` with a dump-shaped access mask, from any process that isn't the
AV engine, is the signal. Endpoint telemetry (Sysmon 10 process-access) sees this
better than the Security log, but the mask filter catches the obvious cases.

```spl
index=main EventCode=4656 Object_Name=*lsass* TaskCategory="Kernel Object"
    Process_Name!=*MsMpEng.exe
    (Access_Mask="0x1010" OR Access_Mask="0x1410" OR Access_Mask="0x1FFFFF")
| table _time, host, Account_Name, Process_Name, Access_Mask, Object_Name
```
<!-- companion:end lsass-4656 -->

**Remote secrets dump (svcctl/winreg over IPC$/ADMIN$)** — `5145`:

```spl
index=main EventCode=5145 Relative_Target_Name IN ("svcctl","winreg")
| regex Share_Name="(?i).*(ipc|admin)\$$"
| table _time, host, Account_Name, Source_Address, Relative_Target_Name

```

<!-- companion:gen dcsync-4662 -->
**Detect DCSync / NTDS replication (4662)**

A `4662` directory-access event with the replication access mask (`0x100`) from a
non-system SID is the signal — legitimate replication comes from DC machine
accounts, so a user/admin SID requesting it is the anomaly.

```spl
index=main EventCode=4662 Access_Mask="0x100" Security_ID!="S-1-5-18"
| stats count by host, Account_Name, Object_Server | sort -count
```

Tighter: alert on `Properties` containing the **DS-Replication-Get-Changes-All**
extended right `1131f6ad-9c07-11d1-f79f-00c04fc2dcd2` requested by anything that
isn't a domain controller.
<!-- companion:end dcsync-4662 -->

<!-- companion:gen ntds-ntdsutil-4688 -->
**Detect NTDS theft via ntdsutil/VSS (4688 + 8222)**

Copying NTDS.dit avoids the replication right (`4662`), so detect on host
behavior instead: on a domain controller, `ntdsutil` with an `ifm`/`create full`
argument, or `vssadmin`/`diskshadow`/`wbadmin` creating a shadow copy (`4688`).
Corroborate with the `8222` shadow-copy-created event. Almost nothing legitimately
runs `ntdsutil ... ifm` outside a planned DC backup or migration — allowlist
those windows and alert on the rest.

```spl
index=main EventCode=4688
| regex Process_Command_Line="(?i)(ntdsutil.*(ifm|create\s+full)|vssadmin\s+create\s+shadow|diskshadow|wbadmin\s+start\s+backup)"
| table _time, host, Account_Name, New_Process_Name, Process_Command_Line
```
<!-- companion:end ntds-ntdsutil-4688 -->

<!-- companion:gen wmiexec-4688 -->
**Detect WMI exec (4688 WmiPrvSE child process)**

WMI execution drops no service (`7045`) to catch, but the payload runs as a child
of `WmiPrvSE.exe`. A `4688` whose creator is `WmiPrvSE.exe` spawning
`cmd.exe`/`powershell.exe` is the signal — especially with impacket-wmiexec's
`cmd.exe /Q /c ... 1> \\127.0.0.1\ADMIN$\...` output-redirect shape. Legitimate
WMI providers spawn children too, so pair the parent with a shell target and the
SMB output-redirect string.

```spl
index=main EventCode=4688 Creator_Process_Name="*\\WmiPrvSE.exe"
    New_Process_Name IN ("*\\cmd.exe","*\\powershell.exe")
| table _time, host, Account_Name, Creator_Process_Name, New_Process_Name, Process_Command_Line
```
<!-- companion:end wmiexec-4688 -->

### Execution, persistence, AD CS

**LOLBAS execution** — `4688` process creation, regex on known abuse shapes:

```spl
index=main EventCode=4688
| regex Process_Command_Line="(?i)(\.(hta|sct)|msbuild\.exe|^hh\s|,ShellExec_RunDLL|regasm|process\s+call\s+create|/u\s+.*\.dll|urlcache.*(http|file))"
| table _time, host, Account_Name, New_Process_Name, Process_Command_Line

```

**Obfuscated command lines** — `4688` heavy in `,` `^` `%`:

```spl
index=main EventCode=4688 (Process_Command_Line="*,*" OR Process_Command_Line="*^*" OR Process_Command_Line="*%*")
| eval n=len(Process_Command_Line)-len(replace(Process_Command_Line,"[,^%]",""))
| where n > 1

```

**Service creation (psexec / RDP-hijack service)** — `7045`, allowlist the known:

```spl
index=main EventCode=7045 Service_Name!="MpKsl*"
| regex Service_File_Name!="(?i)(SplunkUniversalForwarder|Microsoft.Net\\Framework64)"
| table _time, host, Service_Name, Service_File_Name, Service_Account

```

<!-- companion:gen rdp-hijack-4688 -->
**Detect RDP session hijack (4688 tscon)**

The hijack can't happen without a `tscon ... /dest:rdp-tcp#` command line, so the
process-creation event (`4688`) carrying that argument is a near-zero-false-
positive tell — legitimate admins almost never `tscon` to a different session's
RDP endpoint by hand.

```spl
index=main EventCode=4688
| regex Process_Command_Line="(?i)/dest:rdp-tcp#"
```
<!-- companion:end rdp-hijack-4688 -->

<!-- companion:gen potato-seimpersonate-4688 -->
**Detect Potato privesc (service account → SYSTEM shell, 4688)**

Detection posture: **moderate** — the impersonation itself is a legitimate API,
and `4688` alone can't show the new process's run-as-SYSTEM result. So this query
flags the *shape* it can see — a service identity (app-pool / `*$` / NETWORK|LOCAL
SERVICE) spawning an interactive shell — and you confirm the SYSTEM outcome with
endpoint telemetry: Sysmon 17/18 on the `spoolss`/DCOM named pipe, plus Sysmon 1
correlating the parent service process to a SYSTEM child. Tune the service-account
list to your environment.

```spl
index=main EventCode=4688 New_Process_Name IN ("*\\cmd.exe","*\\powershell.exe")
    Account_Name IN ("*$","*APPPOOL*","NETWORK SERVICE","LOCAL SERVICE")
| table _time, host, Account_Name, Creator_Process_Name, New_Process_Name, Process_Command_Line
```

**Know how this query fails.** The `Account_Name` filter assumes the shell is spawned *as*
the service identity, but that is the state the exploit has already left: PrintSpoofer and
GodPotato impersonate the SYSTEM token **before** calling `CreateProcessAsUser`, so the
4688 Subject can be logged as `SYSTEM` — and a SYSTEM-spawning-`cmd.exe` event is excluded
by the very service-account list meant to find it. The narrower your list, the more reliably
it drops the successful escalations and keeps only the failed ones.

`Creator_Process_Name` is the sturdier key, because the parent is the potato binary itself
regardless of which token the child ends up with. Pivot to it when tuning:

```spl
index=main EventCode=4688 New_Process_Name IN ("*\\cmd.exe","*\\powershell.exe")
| regex Creator_Process_Name="(?i)(printspoofer|godpotato|juicypotato|roguepotato|sweetpotato|efspotato)"
| table _time, host, Account_Name, Creator_Process_Name, New_Process_Name, Process_Command_Line
```

That trades one weakness for another — it is name-based, so a renamed binary walks past it —
which is why the entry rates itself moderate and why Sysmon 17/18 on the `spoolss`/DCOM
named pipe should lead. Use the two 4688 queries as corroboration, not as the primary.
<!-- companion:end potato-seimpersonate-4688 -->

**Rogue account creation** — `4720` (created), pair with `4722` (enabled):

```spl
index=main EventCode IN (4720,4722)
| eval Creator=mvindex(Account_Name,0), NewAccount=mvindex(Account_Name,1)
| table _time, host, Creator, NewAccount

```

<!-- companion:gen schtask-4698 -->
**Detect scheduled-task persistence (4698 task created)**

Task creation writes `4698` with the full task XML in the event. Detect on the
action, not the name: a task whose command runs encoded/hidden PowerShell, a
LOLBin, or something from a user-writable/temp path. Baseline your software's
legit tasks and alert on the rest; `4702` (task updated) catches the
modify-an-existing-task variant. (Needs the Object Access > Other Object Access
audit subcategory enabled.)

```spl
index=main EventCode=4698
| regex Task_Content="(?i)(-enc\b|-w\s+hidden|FromBase64|\\\\Users\\\\|\\\\Temp\\\\|mshta|regsvr32|rundll32|powershell.*(http|iex))"
| table _time, host, Subject_Account_Name, Task_Name, Task_Content
```
<!-- companion:end schtask-4698 -->

<!-- companion:gen wmi-subscription-sysmon -->
**Detect WMI subscription persistence (Sysmon 20 consumer)**

The Security log barely sees this; Sysmon does. The WMI-eventing family is Sysmon
`19` (WmiFilter), `20` (WmiConsumer), `21` (WmiBinding). The command lives in the
consumer, so this query keys on event `20` and matches its `Destination` — a
`CommandLineEventConsumer` running PowerShell/cmd/a LOLBin is the high-fidelity
tell. The binding (`21`) and filter (`19`) carry no command, so don't fold them
into this `Destination` regex; instead treat **any** new `21`
(`__FilterToConsumerBinding`) as its own cheap, low-volume alert. Legitimate
permanent consumers are rare and usually from known management software, so
allowlist those and alert on the rest. Requires Sysmon with WMI eventing
(schema ≥ 4.1).

```spl
index=main EventCode=20
| regex Destination="(?i)(powershell|cmd\.exe|mshta|wscript|cscript|rundll32|-enc|FromBase64)"
| table _time, host, User, Name, Type, Destination, Query
```
<!-- companion:end wmi-subscription-sysmon -->

<!-- companion:gen adcs-esc1-4886 -->
**Detect AD CS SAN abuse (4886/4887 ESC1/relay)**

The invariant of ESC1 (and relay-to-ADCS) is a certificate request whose
subject-alternative-name names a *different* principal than the requester — compare
the requested/issued SAN to the `Requester`. Prefer **4887** (certificate *issued*),
which records the requester and the resolved subject once the CA has processed the
CSR; back the requester≠SAN comparison with CA-side **request-attribute auditing**
enabled so the SAN is actually logged.

> Caveat: the SAN rides in the CSR attributes and is surfaced in the `4886`
> ("request received") Message only once CA request-attribute auditing is on, in a
> variable format — so a `4886`-only `upn=` parse is **best-effort** and can read
> zero results as "no ESC1" (a silent miss). Treat 4887 as primary.

```spl
index=main (EventCode=4887 OR EventCode=4886)
| rex field=Message "(?i)(?:SAN|Subject Alternative Name)\s*[:=].*?(?:upn|dns)=(?<RequestedSAN>[^\s,]+)"
| stats latest(_time) as _time, latest(Requester) as Requester, latest(RequestedSAN) as RequestedSAN, values(EventCode) as codes by RequestID, host
| where isnotnull(RequestedSAN) AND RequestedSAN!=Requester
| table _time, host, RequestID, Requester, RequestedSAN, codes
```

Separately, `5136` writes to the `userCertificate` attribute are shadow-credential /
relay telemetry (certificate mapping onto an object), **not** the ESC1-SAN signal —
watch them, but as their own detection rather than a backstop for this one.
<!-- companion:end adcs-esc1-4886 -->

### Delegation & key-trust abuse

<!-- companion:gen shadow-credentials-5136 -->
**Detect Shadow Credentials (5136 msDS-KeyCredentialLink write)**

The attack *must* write the `msDS-KeyCredentialLink` attribute — so a `5136`
directory-object-modified event naming that attribute is the invariant. Almost
nothing legitimately writes it except Windows Hello for Business enrollment, so
scope out those known sources and alert on the rest. (Requires the directory-
service-access audit subcategory + a SACL on the objects.)

```spl
index=main EventCode=5136 Attribute_LDAP_Display_Name="msDS-KeyCredentialLink"
| table _time, host, Subject_Account_Name, Object_DN, Operation_Type
```
<!-- companion:end shadow-credentials-5136 -->

<!-- companion:gen rbcd-5136 -->
**Detect RBCD abuse (5136 msDS-AllowedToActOnBehalfOfOtherIdentity write)**

Configuring RBCD means writing `msDS-AllowedToActOnBehalfOfOtherIdentity` on the
target computer — a `5136` naming that attribute is the invariant. Legitimately
it's set by admins delegating a service; a write sourced from a normal user (not a
delegation admin) onto a computer object is the anomaly. Pair with a `4741`
computer-account-created burst (the attacker's machine account) for higher
fidelity.

```spl
index=main EventCode=5136 Attribute_LDAP_Display_Name="msDS-AllowedToActOnBehalfOfOtherIdentity"
| table _time, host, Subject_Account_Name, Object_DN, Operation_Type
```
<!-- companion:end rbcd-5136 -->

<!-- companion:gen unconstrained-deleg-4624 -->
**Detect unconstrained-deleg abuse (DC machine-account auth to a non-DC, 4624)**

Detection posture: **soft** — the TGT caching is legitimate Kerberos. The realistic
tell is the coerced auth *landing*: a domain controller's computer account doing a
network logon (`4624`) to a host that isn't a DC, which DCs essentially never do.
Allowlist your DC computer accounts and DC hosts below. Best paired with the
coercion alert (`coercion-5145`) firing just before, and with config hygiene —
inventory `TRUSTED_FOR_DELEGATION` accounts that shouldn't have it.

```spl
index=main EventCode=4624 Logon_Type=3 Account_Name="*$"
| search Account_Name IN ("DC1$","DC2$")
| where NOT (host IN ("DC1","DC2"))
| table _time, host, Account_Name, Source_Network_Address
```
<!-- companion:end unconstrained-deleg-4624 -->

<!-- companion:gen dcshadow-4742 -->
**Detect DCShadow (rogue DC registration, 4742 GC SPN)**

DCShadow has to make the directory believe a non-DC is a DC, and that leaves
prints: a computer account gets a `GC/...` (global-catalog) service principal name
added (`4742`), a server/`nTDSDSA` object is created under the Sites container
(`5137`), and replication (`4662`) then originates from a host that is not a real
DC. The SPN write is the cleanest invariant — alert on a `GC/` SPN appearing on
any account that isn't an established domain controller. The `("DC1$","DC2$")`
list below is a **placeholder** — replace it with your real DC computer-account
inventory before relying on the rule.

```spl
index=main EventCode=4742 Service_Principal_Names="*GC/*"
| search NOT Target_Account_Name IN ("DC1$","DC2$")
| table _time, host, Account_Name, Target_Account_Name, Service_Principal_Names
```

Corroborate with `5137` creating an `nTDSDSA`/server object, and `4662` replication
(`DS-Replication-Get-Changes`) sourced from a host outside your DC inventory.
<!-- companion:end dcshadow-4742 -->

<!-- companion:gen dpapi-backupkey-5145 -->
**Detect DPAPI backup-key theft (protected_storage pipe, 5145)**

Detection posture: **narrow but real** — the backup-key retrieval rides MS-BKRP
over the DC's `protected_storage` named pipe (`5145`), and almost nothing but a
genuine domain backup operation touches it. A non-backup principal accessing
`protected_storage` on a DC is the tell. The *offline* decryption that follows is
invisible — this RPC is the only on-wire moment. Needs detailed file-share
auditing on DCs.

```spl
index=main EventCode=5145 Relative_Target_Name="protected_storage"
| regex Share_Name="(?i).*ipc\$$"
| table _time, host, Account_Name, Source_Address, Share_Name, Relative_Target_Name
```
<!-- companion:end dpapi-backupkey-5145 -->

---

## Windows Event ID quick reference

| ID                | Meaning                                           | Shows up for                                |
| ----------------- | ------------------------------------------------- | ------------------------------------------- |
| 4624 / 4625       | logon success / failure                           | spray, lateral movement, relay              |
| 4648              | logon w/ explicit creds                           | runas, LDAP recon fan-out                   |
| 4662              | directory-service object access                   | **DCSync**                                  |
| 4688              | process creation                                  | LOLBAS, obfuscation, hijack, recon binaries |
| 4720 / 4722       | account created / enabled                         | persistence                                 |
| 4769              | Kerberos TGS request                              | **Kerberoasting** (RC4 downgrade)           |
| 4771              | Kerberos pre-auth failed (`0x18`)                 | Kerbrute / AS-REP probing                   |
| 4886 / 4887       | cert requested / issued                           | AD CS abuse (SAN mismatch)                  |
| 5136              | directory object modified                         | `userCertificate` writes, ACL abuse         |
| 5145              | detailed file-share access                        | coercion pipes, remote secretsdump          |
| 5156              | WFP connection allowed                            | NFS/SMB/LDAP flow detection (firewall)      |
| 7045              | service installed                                 | psexec, RDP-hijack service                  |
| Sysmon 1 / 8 / 10 | proc create / CreateRemoteThread / process access | injection, migration, LSASS access          |

## Honey tokens (build these before you're attacked)

- **Honey user** — a never-used account; any `4625`/`4624` referencing it is real.

  ```spl
  index=main EventCode=4625 TERM("<honey-username>")

  ```

- **Honey SPN** — register a fake SPN (`setspn -A MSSQLSvc/fake:1433 <acct>`); any
  `4769` for it means someone enumerated/roasted SPNs:

  ```spl
  index=main EventCode=4769 Service_Name="<honey-spn-account>"

  ```

- **Responder honeypot (HoneyCreds)** — broadcast fake creds so an attacker's
  Responder/relay tooling bites a poisoned credential you can alarm on.

---

*Credit: TrustedSec, "Actionable Purple Teaming," Black Hat USA 2023. Queries
generalized and cleaned from the class command reference; tune field names and
thresholds to your environment before relying on them.*
