# Changelog

All notable changes to this repo's own layer — the offensive role layer
(`offensive/`, `install/`), `bootstrap.sh`, and the tooling around the two vendored
subtrees.

**Not** in scope: changes inside `core/` or `offensive/companion/`. Those are
vendored copies with their own changelogs
([dotfiles-core](https://github.com/dotgibson/dotfiles-core/blob/main/CHANGELOG.md),
[htpx](https://github.com/dotgibson/htpx)). A sync that bumps `core.lock` or
`companion.lock` is worth a line here; the upstream contents are not.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This repo is auto-patch-tagged by CI on a vendored-subtree bump, so version
headings record what was vendored at a point in time rather than a maintained
release line.

## [Unreleased]

### Security

- **Engagement-data write guard.** `note`, `logshell`, `bhce` and `nmapsweep` used
  to fall back to `$PWD` when `$ENGAGEMENT` was unset, so running them inside a
  checkout wrote client data into that repo. They now resolve their root through
  `_eng_writeroot`, which refuses any `$PWD` inside a git work tree.
- **The field references open read-only.** `htp`/`xdev`/`evade`/`ipp` are symlinks
  to tracked files, and `hacktheplanet`'s "target fill" recipe told you to
  substitute the real client IP/hostname/domain into the buffer — one `:w` from
  publishing engagement data. They now open with `-R`; `htp -w` edits deliberately,
  and the fill recipe writes a copy under `$ENGAGEMENT`.
- **`.gitignore` backstop repaired.** `*.xml` carried a trailing comment, which
  gitignore does not support — the pattern was the whole line and matched nothing,
  leaving nmap `-oX` output unguarded. The ignore list also described the
  *template's* directory names rather than the ones `mkengagement` creates, so
  `scope/`, `recon/`, `scans/`, `web/`, `screenshots/`, `exploit/` and `notes.md`
  were all unblocked.
- **Pinned + verified tool installs.** The five `curl | sh` installers are gone.
  `install/tool-versions.env` pins each tool's version and the SHA-256 of its
  release asset; `bootstrap.sh` verifies before installing and fails closed.
  `starship` moved to apt, which packages it.
- **Secret scanning in CI** — gitleaks over the working tree and full history.
- **`hethttp` refuses to serve a git work tree** on `0.0.0.0`.
- **`bhce` can take credentials off argv** — `op://…` resolves through 1Password,
  `-` prompts with echo off.

### Fixed

- **`make markdown` announced a skip and then ran anyway.** Each `make` recipe line runs
  in its own shell, so the guard's `exit 0` only ended that line: without `npx` it printed
  "npx not available — skipping markdown" and then ran `npx`, exiting `127`. Collapsed
  into one recipe line, so the skip is a real skip (dotgibson/dotfiles-core#775 — the same
  defect in six other fleet repos). `MD_FILES` was already correct here, including the
  `offensive/companion` exclude that matches the gate's, so only the guard needed fixing.
  An unreadable `MARKDOWNLINT_VERSION` now **fails** rather than silently linting
  unpinned — "same version as CI" is this target's whole claim.
- `.markdownlint.jsonc`'s header claimed this config was "the local check for the README"
  and that "CI here gates this repo's own code, not its Markdown". Both were true when
  written; dotgibson/dotfiles-core#592 made the markdown leg blocking and it covers all 17
  repo-owned files, not just the README.

- **`redup`'s nuclei engine step could never succeed on Kali.** It ran
  `nuclei -update` unconditionally, but Kali patches that flag out of its packaged
  nuclei — apt owns the binary, so self-updating it is not nuclei's job there. Kali's
  `-h` UPDATE section carries only `-update-templates`, `-update-template-dir` and
  `-disable-update-check`. So the step failed on **every** run on the primary target
  platform and tallied a failure, making the summary read red on a completely healthy
  box — the exact miscount the function's own comments exist to prevent. The engine step
  is now probed and the templates step (the daily-moving half) stays unconditional, so a
  `go install`-provided nuclei on non-Kali Debian still self-updates. The probe matches
  `-update`/`-up` as a whole TOKEN: a bare substring grep matches `-update-templates`,
  `-update-template-dir` and `-disable-update-check`, three hits on the very help text
  that proves the flag is absent.
- **Three apt names in `install/offensive-packages.txt` resolved against nothing.**
  Verified against kali-rolling's own binary index, not a local box:
  - `bbot` is packaged in **no** Kali component and never has been (pkg.kali.org 404s) —
    now an UPSTREAM/pipx comment. The old line's "(pipx/upstream if the repo build lags)"
    hedge implied a repo build that does not exist.
  - `snmp-check` is the **binary** name; the package is `snmpcheck`, which ships
    `/usr/bin/snmp-check`. Same package/binary split the file already documents for
    `httpx-toolkit` and `python3-ldapdomaindump`. `hacktheplanet`'s command was always
    right; only the manifest was wrong.
  - `rustscan` is absent from main, contrib and non-free alike — Kali's packaging sits in
    kali-**dev** at 2.4.1 and has not migrated. The line also claimed it "ships in
    kali-linux-default", whose `Depends` does not name it, so both halves were wrong. Now
    an UPSTREAM (cargo) comment.
  `test/check-packages.sh` had been reporting all three for weeks; see the `packages.yml`
  note under Changed for why nobody saw it.
- **Caldera was routed to Docker for nothing.** `install/offensive-packages.txt` carried
  it as `→ UPSTREAM/docker` and `offensive/offensive.zsh` justified the missing probe with
  "Caldera ships no `caldera` binary". Both false: kali-rolling ships `caldera`
  (5.3.0-0kali1) and it installs `/usr/bin/caldera`. Now a plain apt line, noting the
  ~70 MB Python chain and that no `kali-linux-*` metapackage carries it. The decision not
  to add `HAVE_CALDERA` stands, but for the real reason — nothing in `offensive.zsh`
  invokes it, which is `install/tools.lst`'s actual membership rule.
- **The corpus-coverage counts went stale again**, exactly as recorded below for the
  v2.10.0 sync. A later v2.10.1 sync added `entries/blue/smb-enum-5145.md` and projected
  the `smb-enum` pair into both views; no header moved. The version notes in those files
  now point at `companion.lock` for the exact revision instead of hardcoding a commit
  count, which rots the same way the counts do. Actual is **103 red / 102 blue**
  with **19** and **24** blocks projected. Fixed in `hacktheplanet`, `PURPLE-TEAM.md`,
  `OFFENSIVE-METHODOLOGY.md` and — found while verifying, reported by neither audit —
  `CONTRIBUTING.md` and the `Makefile`. `hacktheplanet` also listed `smb-enum-nxc` among
  the entries "covered as richer prose below" while generating a block for it seven
  paragraphs later, so its own accounting summed to 102 rather than 103.
- **`CLAUDE.md` described `--install` as apt-only on Kali.** `_install_apt_absent`
  pipx-installs ROADtools on **both** routes, which `bootstrap.sh` and
  `install/offensive-packages.txt` both state plainly. "Where things are" also documented
  2 of the 4 `install/` manifests; `corpus-commands.lst` and `impacket-binaries.lst` are
  now listed, the latter being the file whose entire purpose is making
  `impacket-petitpotam` fail (#208).
- **`OFFENSIVE-METHODOLOGY.md` dated Caldera's Apache move to "May 2026"**, contradicting
  the manifest's already-corrected 2025-12-19 donation date (#211 landed that fix in the
  manifest only).
- **`hacktheplanet`'s escalation-primitives index restated `certipy-ad find … -vulnerable`
  without `-stdout`**, so a copy-paste wrote to a file instead of the terminal. The
  canonical AD CS section and the corpus entry both carry the flag.

- **The corpus-coverage counts were stale in three files** (found while verifying #212,
  which had reported them as correct). `hacktheplanet` and `PURPLE-TEAM.md` claimed 92 red /
  90 blue entries; the htpx **v2.10.0** sync added 11 of each and the headers were never
  updated — actual is **103 red / 101 blue**. The decomposition went stale with them: the
  cloud/SaaS/CI-CD bucket is 56 (not ~55), C2-egress/Impact is 13 (not ~12), and **7 Linux
  persistence/privesc/credential-access entries had no bucket at all**.
- **Two red entries and their blue pairs are projected nowhere and belong to no category.**
  `bloodhound-collect` and `ldap-recon` are both `Active Directory — discovery`, squarely
  inside the "richer prose here" subject area but absent from its list; their pairs
  `bloodhound-collect-4662` / `ldap-recon-4662` key off event 4662, which is
  `PURPLE-TEAM.md`'s own criterion for projecting. `hacktheplanet`'s claim that an
  unprojected entry is "not a gap in the generator" was therefore false. Both files now name
  the gap instead of implying it cannot exist.
- **`rdp-hijack-tscon` was listed as "covered better below"; it is covered *equally*.** Its
  two commands are byte-identical to the prose ones. Noted rather than silently kept.
- `OFFENSIVE-METHODOLOGY.md`'s "roughly two-thirds of the corpus" replaced with the measured
  figure — 69/103 red (67%) and 76/101 blue (75%).

All three files now carry the same caveat: these counts are hand-maintained, they go stale
on every `companion-sync`, and the corpus is authoritative when they disagree.

- **`kwp` was attributed to the wrong project** (#213). The manifest filed it under
  `PACK (kwp, statsgen, maskgen) → github.com/iphelix/pack`. PACK ships
  statsgen/maskgen/policygen/rulegen and no `kwp` — `kwp` is hashcat's kwprocessor, and
  `hacktheplanet`'s invocation is verbatim kwprocessor. Following the old pointer landed you
  in a repo that does not contain the tool. Split onto its own UPSTREAM line.
- **`exploitdev`'s Linux toolchain was unmanifested** (#212, #213). `gdb`, `nasm` and
  `objdump` are invoked by that reference and appeared nowhere in the package list. Resolved
  by checking a real kali-rolling box rather than guessing: `nasm` (via metasploit-framework)
  and `binutils` are already pulled transitively, so they go in the accounting block, while
  **`gdb` is genuinely absent** — gcc only *suggests* it — so it joins the "Kali does NOT
  ship by default" block, whose stated test it meets exactly.
- **`nc` was named only inside another package's comment** (#212). netcat is the primary
  command of the reverse-shell fold and was listed nowhere. Added as
  **`netcat-traditional`**, not `netcat-openbsd` as the audit suggested: Kali installs
  traditional and points the `nc` alternative at it, and the documented `nc -lvnp` form is a
  traditional idiom — OpenBSD's nc rejects `-p` alongside `-l`, so that variant could have
  flipped the alternative and broken the very line it was meant to support.

- **Four field-reference commands could not run as written** (#213, #212).
  `hacktheplanet` invoked `nmap --script=msrpc-dcom-interface-activation`, which is not a
  script nmap ships — verified against nmap 7.99 on kali-rolling, where the only msrpc NSE
  is `msrpc-enum` (already the line directly above). Dropped rather than replaced: there is
  nothing to replace it with. `exploitdev` invoked `!mona egghunter`, which is not a mona
  command — `egg` is, and `-c` (NtAccessCheckAndAuditAlarm) is one of *its* options; the two
  lines collapse into one. `hacktheplanet` also credited `--dc` to impacket/certipy when it
  is kerbrute's idiom — impacket and certipy use `-dc-ip`, as every impacket line in that
  file already does. The same misattribution in this file's #187 entry is corrected with it.
- **`exploitdev` presented `hexyl` as installed when no fleet layer ships it.** The note
  claimed it was "Kali-only in this stack (not in Core)"; it is in Core, Kali apt (no such
  package exists) and `install/offensive-packages.txt` alike — nowhere. `offensive.zsh`
  probes `HAVE_HEXYL` but nothing installs it, so the bad-char *verification* step silently
  needed a tool the operator did not have. Now says so, with an `xxd` fallback, and points
  at the dotfiles-core#395 deferral.

- **Two `hacktheplanet` commands could not run as written** (#187). `rusthound-ce` was
  invoked with `--dc <ip_address>`; RustHound-CE has no such flag — that is kerbrute's
  idiom (impacket/certipy use `-dc-ip`) — and takes `-i/--ldapip` for the DC IP or `-f/--ldapfqdn` for its
  FQDN. And two pivot lines invoked bare `proxychains`, which is **not a binary on this
  layer's own box**: the manifest ships `proxychains4`, that package installs only
  `/usr/bin/proxychains4`, and its `Provides: proxychains` is a virtual-package relation, so
  `apt-file search '/usr/bin/proxychains$'` matches nothing. The audit that filed this
  guessed the second one was "probably fine … one `command -v` settles it"; it was run, and
  it isn't. Both lines now carry the reasoning inline, since `--dc` **is** right for
  `kerbrute` two folds up and the next reader will otherwise "fix" it back.

- **`cifs-utils` was missing from the manifest** (#187). `hacktheplanet` mounts a share with
  `mount -t cifs` twice — once in the SMB fold, once on SYSVOL inside the GPP-cpassword
  block — and nothing in `offensive-packages.txt` provided `mount.cifs`. `smbclient`
  *browses* a share; mounting one is a separate package. This was the only real gap of the
  six the audit alleged: `samba-common-bin` and `gcc-mingw-w64-i686` were false (`smbclient`
  ships `/usr/bin/rpcclient`; `mingw-w64` provides `i686-w64-mingw32-gcc`), and the rest had
  already landed with #186.

- **The manifest's own accounting claim was false again** (#187). The target-dropped block
  claims it "accounts for every tool the DOCS *and* the COMPANION CORPUS name", and seven
  doc-named tools were unaccounted for. `pspy` joins the block properly — it is genuinely
  target-dropped, and `ippsec` names it in the same breath as linpeas. The other six
  (`macro_pack`, `PowerUpSQL`, and the `Donut`/`sRDI`/`ConfuserEx`/`ScareCrow` loaders from
  `evasion`) get a **stated exclusion** instead of a listing, because they are operator-side
  *payload-build* tooling that runs on Windows: not target-dropped, not in Kali apt, and not
  something a Linux apt list should imply it can install. Either a tool is listed or the
  manifest says in one line why it isn't — which is what makes the claim checkable.

- **`ldapdomaindump` was installed twice and invoked never** (#187). It arrives by apt
  (`python3-ldapdomaindump`) *and* by pipx on the non-Kali route, and `OFFENSIVE-METHODOLOGY.md`
  lists it — but no command anywhere under `offensive/` ran it, making it the only installed
  AD-enum tool with no copy-paste line. It now has one in the AD fold, writing to `loot/ldd`
  to match the methodology table. The manifest records the apt-name/binary-name split, the
  same dual-name trap already documented for impacket and certipy.

  Not acted on from #187: the `bloodhound-python` finding was **already fixed** at HEAD (the
  audit ran against a pre-`b294258` tree — every line number in it is stale by 11–15, and it
  cites `os/kali.conf`, deleted 2026-08-18). The `-M wmi-event` finding is real but worse
  than filed — that NetExec module does not exist in *either* spelling — and lives in
  generated content, so it was fixed upstream in htpx#73 and arrives here on the next
  companion sync.

- **Seven packages, behind eight commands `hacktheplanet` invokes, had no manifest line**
  (#186) — `ftp`, `showmount`, `dig`, `nslookup`, `mysql`, `psql`, `redis-cli` and
  `i686-w64-mingw32-gcc`. The Service-enumeration block states its own rule — *every fold's
  primary command in PATH* — and five folds were not honouring it. `ftp`, `nfs-common` and
  `bind9-dnsutils` join that block; the other four get a **new block of their own**, because
  checking `kali-meta`'s `debian/control` showed the audit's framing was too generous: no
  Kali metapackage names `mariadb-client`, `postgresql-client`, `redis-tools` or
  `mingw-w64`, so those four lines in `hacktheplanet` fail on a **stock** box, not just a
  slim one. `mingw-w64` is the sharpest — `build-essential` gives you native `gcc` only, so
  nothing else on the box covers the cross-compile.
  - Note the DNS name: it is **`bind9-dnsutils`**, not the `dnsutils` the audit proposed.
    `dnsutils` is a transitional binary off the same `bind9` source, gone from trixie and
    back only in sid; the sole Kali metapackage still naming it is `kali-linux-wsl`. Since
    `test/check-packages.sh` resolves every name against kali-rolling, the durable name is
    the only safe one to pin.
  - No `install/tools.lst` change: that file's header restricts it to commands
    `offensive/offensive.zsh` probes or invokes by bare name, and none of these are.
    Adding them would make bootstrap's report cry wolf.
- **`gcc-multilib` was the eighth package, spotted during that pass and deferred** (#186).
  `hacktheplanet:212` runs `gcc -m32` two lines below the `i686-w64-mingw32-gcc` line above,
  and fails for the identical reason: `build-essential`'s `gcc` is native x86-64 with no
  32-bit libs, so rebuilding an old PoC dies on `<bits/libc-header-start.h>`. No Kali
  metapackage names it either, so it joins the *does-not-ship-by-default* block rather than
  the slim-install one.
- **`PrintSpoofer64.exe` and `GodPotato` were the target-dropped block's one blind spot**
  (#186). That block promises to account for *every* tool the docs **and** the corpus name;
  these two arrive from the corpus inside `hacktheplanet`'s `companion:gen
  potato-seimpersonate` block, which is how they slipped it. Two `UPSTREAM →` lines now,
  matching the linpeas/winPEAS treatment.
- **`redup`'s help advertised a step that always no-ops** (#186). Both help strings and
  `aliases.md` promised a refresh of "the go-installed tools", but `go_fast_movers` has
  been `()` since kerbrute was dropped as upstream-frozen. The strings now describe what
  the function does; the block comment still records why the array is empty and how to
  re-populate it. `aliases.md` also gains `katana`, which it had missed since redup started
  driving it.
- **`doggo`, `carapace` and `sesh` never installed on a fresh box.** `mise` lands in
  `~/.local/bin`, which is not on `PATH` during bootstrap, so the `go install`
  fallback's `command -v mise` always missed. A PATH prelude fixes this and the
  related re-install-every-run behaviour of `atuin`.
- **A symlink cycle in the `.zshrc` wiring.** `bootstrap.sh` re-did a link the
  library already makes, bypassing the ELOOP guard in `_blib_seed_zdotdir_rc`.
- **`bootstrap.sh` no longer silently installs nothing** when
  `install/packages.txt` is missing.
- `apt_install`'s per-package retry keeps `--no-install-recommends`.
- The `bootstrap` workflow's path filter omitted `install/**` and `wsl/**`, so
  package-list edits never re-ran the bootstrap test. Filters removed.
- `dotsync` hardcoded `~/dotfiles-Offense`; it now resolves this checkout.
- The offensive tmux binding shipped even when its script was not linked, and
  hardcoded `~/.config` against an XDG-aware bootstrap.
- `@batt_enable` was unconditionally off "because WSL has no battery" — now
  detected, so bare-metal laptops keep the widget.
- `ssh/config` pinned modern-only crypto on `Host *`, which refuses to negotiate
  with the legacy targets an offensive box exists to reach. Scoped to your own
  infrastructure.
- `pseudo-shell.py` proxied through Burp by default, so every request failed
  opaquely when Burp was not running; now opt-in. Its `requests` dependency
  documents a PEP 668-compatible install path.
- `redup` printed "go not installed" for an intentionally empty tool list, and ran
  `searchsploit -u` without the privilege its root-owned checkout needs.

### Added

- **`make view-counts` / `test/check-view-counts.sh`** — a gate on the hand-typed corpus
  counts in `hacktheplanet`, `PURPLE-TEAM.md` and `OFFENSIVE-METHODOLOGY.md`. Two of those
  files already carried a caveat saying the numbers go stale on every `companion-sync`;
  this executes it. It exists because the drift above is a **repeat** — the same fix is
  recorded for the v2.10.0 sync — and nothing could see it: `gen-views.sh --check`
  byte-compares block *contents* and has no opinion on how many blocks exist, and
  markdownlint cannot tell `101` from `102`. It is repo-owned rather than an extension of
  `gen-views.sh` because `offensive/companion/` is a vendored subtree and an edit there is
  lost on the next sync. It checks only what is mechanically derivable (entry totals,
  projected-block counts, and the sums of those); the semantic buckets — 56 cloud/SaaS/
  CI-CD, 13 C2-egress/Impact, 7 Linux, 69/76, the percentages — are deliberately ungated,
  because nothing in `entries/*.md` marks an entry "cloud". Exit 2 means a stale count;
  exit 1 means an anchored sentence was rewritten and needs re-anchoring — two different
  failures, so a maintainer is never told the wrong one.

- **The SMB enum fold and its detection are now entry-backed.** `companion.lock`
  bumps to htpx `b80741f`, which pairs `smb-enum-nxc` with a new `smb-enum-5145` blue
  entry ([htpx#97](https://github.com/dotgibson/htpx/issues/97)), and both sides are
  wrapped in `companion:gen` markers: the nxc commands in `hacktheplanet`'s SMB fold,
  and the detection in `PURPLE-TEAM.md`'s recon section.

  The hacktheplanet block is the notable half. Those five `nxc smb` lines have been
  hand-written since the file existed, and the entry upstream carried only three of them
  — so wrapping them would have silently deleted `--loggedon-users` and the `/24` spray.
  htpx#100 widened the entry to the full fold with its inline comments matched, which
  makes `render_red` reproduce the existing lines **byte for byte**: the diff to
  `hacktheplanet` here is the two marker lines and nothing else. That is the bar for
  putting a marker around prose that was already good — the tempting shortcut, wrap it
  and let the generator win, loses content nobody notices for months.

  This sync also brings `pair_note:`
  ([htpx#98](https://github.com/dotgibson/htpx/pull/98)), which the vendored copy
  predated: an entry carrying `pair: null` must now say why, and upstream CI rejects one
  that does not.

- **ROADtools is now installed by `--install`, on every route** (#231). Entra/M365
  tooling in this layer was entirely Windows-side (AADInternals, TeamFiltration,
  MSOLSpray); the corpus even cited dirkjanm's ROADtools as `device-code-phish`'s
  `source:` while handing you Windows-only PowerShell. `bootstrap.sh` grew an
  `_install_apt_absent` step — a THIRD install category for tools no route can
  apt-install — that pipx-installs `roadrecon` and `roadtx` on the Kali path too, not
  just the portable subset, so the Entra corpus entries finally run from the attacker
  box. `hacktheplanet`'s M365 fold documents the Linux commands and
  `install/offensive-packages.txt` carries the annotation. The corpus entry's own
  `platform:`/`source:` fix lands upstream in dotgibson/htpx.

- **SCCM/MECM is now covered — it was a total blank** (#230). `grep -ri sccm` over the
  repo used to return nothing, despite site-server takeover and Network Access Account
  extraction being mainstream AD attack surface. Added a `SCCM / MECM` fold to
  `hacktheplanet` (discovery -> NAA over the network or from a compromised client -> site
  takeover -> PXE boot-media creds), a `Cred access` row in the methodology map, and
  `sccmhunter` + `pxethiefy` UPSTREAM annotations in `install/offensive-packages.txt`
  (whose corpus-only block widened to admit doc-named operator tooling). sccmhunter is
  documented, not wired into `--install`: it is not on PyPI, its git install carries a
  Python 3.13 floor and an ldap3 fork pin pip drops silently, so a documented manual step
  beats a best-effort loop that fails quietly. Every command verified against upstream.

- **`corpus commands resolve` — a gate for the question nothing asked** (#208). Two entries
  in `coerce-petitpotam` once invoked `impacket-petitpotam` and `dfscoerce`. Neither is a
  real command, both shipped in a released corpus, and a **human reading the file** found
  them — because every existing gate looks somewhere else: `gen-views.sh --check`
  byte-compares the 18 *projected* red blocks (85 of 103 are unprojected), `check-packages.sh`
  reads the manifest and never the corpus, `companion-integrity` checks provenance rather
  than content, and htpx's own CI checks pairing and slots rather than existence.
  `test/check-corpus-commands.sh` resolves the first token of every command line in every
  red entry against the manifest, an `impacket-binaries.lst` roster, and the classifications
  in `install/corpus-commands.lst`. Offline and deterministic, so unlike `packages-check` it
  can be **required**; wired into `make test` and its own workflow.
  - Its `--self-test` rebuilds the pre-v2.8.0 `coerce-petitpotam` at run time and asserts
    the gate still reddens on it — a regression guard for the gate itself, since one that
    quietly stopped catching its own motivating bug would pass forever.
  - `install/corpus-commands.lst` requires a line of prose on every classification, so
    "whatever the allowlist excuses, it says so" is enforced rather than hoped for. It also
    fails on a classification no entry uses any more, so a `companion-sync` that drops an
    entry surfaces its dead excuse.
  - The roster spans **two** packages: `impacket-scripts` (57 wrappers) and
    `python3-impacket` (5 more, including `impacket-secretsdump` and `impacket-wmiexec`).
    A roster built from `impacket-scripts` alone would have failed the two most-used
    commands in the corpus. `packages.yml` gained an advisory step that re-derives it from
    kali-rolling and diffs, so the checked-in copy cannot rot unnoticed.
- **Five tools the corpus invokes and nothing accounted for**, all surfaced by the new gate
  on its first run: `ldap-utils` (`ldapsearch`, a real apt package, now installed), plus
  UPSTREAM entries for `evilginx2`, `MSOLSpray` and `tfc-agent` in a new
  "Corpus-only operator tooling" block. `tfc-agent` also corrects this file's older claim
  that the Terraform Cloud entries are pure REST. The legacy `bloodhound-python` binary is
  now named in the BloodHound block, with the warning that the entry invoking it is wrong
  for a CE stack — that fix routes upstream to htpx.

- **A gate against leaked `RETURN` traps** (#198) — `test/check-return-traps.sh`, wired
  into `make lint` as `make trap-guard` and into CI as the `return-traps` job in
  `checks.yml`. A bash RETURN trap is a **global slot, not a function-scoped one**: armed
  inside a function it survives into the *caller's* frame and fires a second time when the
  caller returns, where the local it cleans up is out of scope and `set -u` makes that
  fatal. In `dotfiles-Debian` that aborted `provision()` after every package had installed
  but before `wire_links` ran — the whole stack on the box, and not one symlink. Nothing
  else can see it: the broken line is valid bash, so shellcheck and `bash -n` both pass it,
  and no CI job in this fleet exercises a real install path (every bootstrap run is
  `--links-only`). Hence a grep. The correct form is
  `trap 'trap - RETURN; rm -rf "$tmp"' RETURN`.

  **This is prevention, not a fix.** #198 reported the bug in this repo's
  `verified_install()`, but that function — and the entire SHA-pinned out-of-band install
  block around it — left in the layer split (`6d641d2`), which moved it to
  `dotfiles-Debian`; the trap went with it. No repo-owned shell here arms a RETURN trap
  today. The guard exists so none ever does again. zsh is out of scope: it has no `RETURN`
  signal at all.

- `Makefile` — the entry point (`make lint`, `test`, `core-sync`, `packages-check`, …).
  Makes `core.lock`'s `make core-lock` instruction true for the first time.
- `scripts/sync-core.sh`, `test/check-core-freshness.sh` and a `freshness` workflow —
  the consumer-side core-sync line, which three files already referenced and none
  provided.
- `test/check-companion-integrity.sh` — tamper detection for the second vendored
  subtree, mirroring `core-integrity`.
- `test/check-packages.sh` + a `packages` workflow resolving every manifest name
  against `kali-rolling`.
- markdownlint in CI, against the `.markdownlint.jsonc` that had been sitting
  unused.
- `SECURITY.md`, `CODEOWNERS`, issue and PR templates, `CONTRIBUTING.md`,
  `.shellcheckrc`, `.editorconfig`, `.gitattributes`.
- `bootstrap.sh --dry-run` and `--no-upgrade`.
- `companion_version` / `companion_tag` in `companion.lock`, for symmetry with
  `core.lock`.

### Changed

- **`packages.yml` now emits `::warning::` annotations** as well as its job summary. It
  stays advisory — Kali is rolling, and a package that vanishes mid-migration must not red
  an unrelated PR — but summary-only proved to be the same as silent: three unresolvable
  apt names sat in the manifest while the job reported them into a page nobody opened and
  exited 0 every week. Annotations surface on the Checks and Files tabs without changing
  any exit code. Its header also claimed you could make the job blocking by dropping a
  `|| true` that does not exist in the file; the real lever is the `exit 0` at the end of
  the resolve step.

- **Five currency annotations corrected** (#211). `adaptixc2`'s said upstream publishes zero
  releases so there is "no tag to judge staleness by" and that it rolls on `main` — both
  false: v1.0/v1.1/v1.2 are tagged, `main` last moved 2026-03-04, and work is on version
  branches. That premise was load-bearing for the fingerprinted-default-profiles warning
  above it. `sliver`'s apt lag is two patches, not "~a patch". `caldera` entered the Apache
  Incubator 2025-12-19, not May 2026. `rusthound-ce`'s "collectors aren't daily-churn"
  reasoning is dead (v2.4.91 → v2.5.2 in seven weeks) — the conclusion survives for a
  mechanical reason instead: cargo, no self-updater, and redup's loop is go-only. And
  `mitm6` finally gets the FROZEN note that `kerbrute` and `havoc` already carried.
- **`hexyl`'s absence from the manifest is now recorded there.** It is not a Kali package at
  all, so listing it would hand `check-packages.sh` an unresolvable name; the deferral to
  dotgibson/dotfiles-core#395 is written down instead, so the packages list and
  `install/tools.lst` agree.

- **Three of the four field references now point at the corpus.** `exploitdev`, `ippsec`
  and `evasion` listed their sibling references but omitted `~/companion` (`htpx`), which
  `hacktheplanet` has always carried. `evasion` was the sharpest case: its
  "Network-filter & egress bypass (C2 channels)" fold is prose-only by design, and the six
  entries holding the actual commands (`dns-tunnel-c2`, `icmp-tunnel-c2`,
  `domain-fronting-cdn`, `https-beacon-sliver`, `mtls-c2-sliver`, `web-service-c2-telegram`)
  live only in the corpus — with no route to them from the doc that needed them most. Its
  footer is also restyled to match the other three (`~/name` + alias, not `offensive/name`).
- **`evasion` opened with bare `vim`.** It told you to run `vim ~/evasion`, bypassing the
  read-only opener that exists so an errant `:w` cannot publish engagement data — the one
  reference of the four that did. Now leads with `evade`, matching `exploitdev`.
- **`hacktheplanet` gained the two commands the corpus had and it did not** (#212).
  The coercion fold described "many vectors" but never showed the MS-DFSNM one, and the
  pivot fold described ligolo-ng in prose with no command line at all. Both are now present,
  so the header's claim that these entries are "covered better below" holds again.

- **The last OS-layer file is gone, and the role wiring is Core's now.** `os/kali.conf`
  carried the `prefix + e` engagement popup as *role* config living in an *OS* overlay
  (`$CONFIG/tmux/os.conf`), because Core had exactly one tmux overlay hook when it was
  written. Vendoring Core **v4.13.1** brings the second hook, so the binding moves to
  **`offensive/offensive.conf`** → `$CONFIG/tmux/role.conf`, and `os/` is deleted
  outright. Two consequences worth stating plainly:
  - `role.conf` is sourced **last** by Core's `tmux.conf`, after Core's own bindings.
    `os.conf` is sourced before them, so a future Core `bind e` could have silently
    taken the key back. That ordering is the actual reason the hook exists.
  - `dotfiles-Debian` and this repo no longer race for `$CONFIG/tmux/os.conf`. Until
    now whichever bootstrap ran last won it; the OS repo owns band 80 alone again.
  The battery and net-speed status probes did **not** move here — they are OS-native and
  `dotfiles-Debian`'s `os/debian.conf` already carries them.
- **`bootstrap.sh` calls `blib_link_role_layer` instead of hand-rolling three links.**
  The block it replaces had already drifted from `dotfiles-Defense`'s copy of the same
  wiring: Defense honoured `BLIB_DRY` when dropping the stale pre-v4 link and this repo
  did not, so `--dry-run` mutated the box here and not there. One shared definition ends
  that class of drift.
- **Templates moved to `$CONFIG/offensive/templates`** (from `$CONFIG/kali/templates`) —
  named for the role rather than the distro, matching Defense's `$CONFIG/defense/`. The
  two shipped docs that quote the path by hand, `offensive/hacktheplanet` and
  `offensive/ippsec`, are updated in the same change. Core deliberately declined a compat
  symlink, since it would preserve a `~/.config/kali/` on a repo no longer called Kali.
- **Bootstrap now cleans up after the old wiring.** A box bootstrapped before this change
  carries `$CONFIG/tmux/os.conf` and `$CONFIG/kali/templates` pointing into this
  checkout; both dangle afterwards. Each is removed **only when it is a symlink resolving
  inside this repo**, so a box also running `dotfiles-Debian` never has that repo's live
  `os.conf` touched, and `--dry-run` only reports.

- **This repo is now a pure Role layer.** It used to be both the OS-native layer for
  Kali *and* the offensive role on top. `dotfiles-Debian` now covers the Debian family
  properly and accepts `ID=kali` as a first-class target, so the OS half moved there and
  what is left here is the role. Concretely:
  - **Removed:** `os/kali.zsh`, `os/kali.gitconfig`, `install/packages.txt`,
    `install/tool-versions.env`, `scripts/update-tool-checksums.sh`, `wsl/`,
    `ssh/config`. Every one of them has an equivalent in `dotfiles-Debian`, whose
    package list carries the Kali tier as `# only:kali` annotations.
  - **`bootstrap.sh` is distro-agnostic and installs nothing by default.** The `ID=kali`
    gate, the apt base install, the `full-upgrade`, the SHA-pinned `verified_install`
    block, the carapace `.deb`, the 1Password repo and the `/etc/wsl.conf` write are all
    gone — they belong to the OS-native layer. What replaces them is a **report**: a
    three-state host-tool probe (on `$PATH` / present-but-unreachable / missing),
    modelled on `dotfiles-Defense`.
  - **`--install` is the new opt-in.** On Kali it apt-installs
    `install/offensive-packages.txt` as before. On any other Debian-family box it
    installs a small **portable subset** via pipx (impacket, certipy-ad, netexec,
    bloodyAD, ldapdomaindump) and go (nuclei, gobuster, ffuf, kerbrute). On anything
    else it refuses and says why rather than guessing at a package manager.
  - **`--no-offensive` and `--no-upgrade` are accepted but inert**, with a note — the
    behaviour they asked for is now the default, so aborting on them would be worse than
    honouring them.
  - **`--links-only` with `--install` is refused**: one wires symlinks only, the other
    installs packages.
- **`install/tools.lst` is new** — the host-tool probe list, and the one place it is
  written. Twin of `dotfiles-Defense`'s. A command belongs there only if
  `offensive/offensive.zsh` probes or invokes it by bare name.
- **`offsync` replaces this repo's half of `dotsync`.** `dotsync` came from
  `os/kali.zsh` and now belongs to the OS-native layer (band 80). `offensive.zsh`
  exports `$DOTFILES_OFFENSE` and binds `offsync` to it — a distinct verb, because
  reusing `dotsync` at band 85 would silently shadow the OS layer's.
- **`test/check-packages.sh` and `make packages-check` now check one manifest**
  (`install/offensive-packages.txt`); `make tool-checksums` is gone with the pins.

- The gating workflows (`lint`, `bootstrap`, `companion`, `routine-filter`) no
  longer use trigger-level path filters: a `paths:`-skipped workflow produces no
  check run, so requiring one would hang every non-matching PR.
- `os/kali.gitconfig` no longer duplicates Core's `init.defaultBranch`, and
  `os/kali.zsh` no longer duplicates Core's `~/.local/bin` PATH prepend.
- `offensive/templates/engagement.md` documents the layout `mkengagement` actually
  creates.

### Known gaps

- **pipx installs different binary names than Kali does.** PyPI's impacket ships
  `secretsdump.py`, not Kali's `impacket-secretsdump` wrapper; `certipy-ad` ships
  `certipy`. `offensive.zsh` probes the Kali names, so those `HAVE_*` flags do not fire
  on a pipx box. The bootstrap's probe recognises both names, so the report is honest;
  teaching the shell layer to resolve both is a separate change.
- **The WSL Git-Credential-Manager note** that lived in `os/kali.gitconfig` (how to
  point `credential.helper` at the Windows host's GCM) did not travel with the file.
  It belongs in `dotfiles-Debian`'s git overlay now that that repo owns WSL.
