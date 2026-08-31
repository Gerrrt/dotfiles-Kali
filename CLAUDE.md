# CLAUDE.md — dotfiles-Offense

Project memory for Claude Code, auto-loaded every session. For the shared Core
rules (the load order, the "is it Core?" test, the manifest contract) see
`core/README.md` and `core/CONTRIBUTING.md`.

## What this repo is

`dotfiles-Offense` is the **offensive (red) Role layer** of an **eleven-repo dotfiles
system** built on a three-layer model (Core → OS-native → Role). It is the mirror of
`dotfiles-Defense`: engagement scaffolding and attacker tooling, stacked on whatever
OS-native layer the box already runs.

It used to be both layers at once — the OS-native layer for Kali *and* the offensive
role on top. That fusion was defensible while Kali was the fleet's only Debian-family
target; `dotfiles-Debian` now covers the family properly and accepts `ID=kali` as a
first-class target, so the OS half moved there: the apt base list, the SHA-pinned
out-of-band installs, the WSL bootstrap, and the zsh/git/ssh overlays.

**This repo is distro-agnostic and installs nothing by default.** `./bootstrap.sh`
wires symlinks and reports which offensive tools the box has; `--install` is the
opt-in.

## The rule that bites

`core/` is a **vendored copy of [dotfiles-core](https://github.com/dotgibson/dotfiles-core)** — *not*
editable here; changes under `core/` are overwritten on the next sync. Edit shared
Core config **in dotfiles-core**, `make audit`, then `make sync` there.

It arrives here **by fan-out only**: a dotfiles-core release opens a `core.lock`-bump PR
in this repo automatically. There is no local pull any more — `make core-sync` reports
how far behind you are and writes nothing (dotfiles-core#676: a vendored `core/` is a
filtered subset of upstream, which `git subtree pull` cannot produce). It is also no
longer a whole copy of that repo: it carries `core.manifest` + `core.vendor`, so the
authoring tooling (`scripts/audit-core.sh`, `test-core.sh`, `CHANGELOG.md`, `assets/`)
is not here. `offensive/companion` still pulls — see below; that asymmetry is deliberate.

Three things that actually bite on this repo:

- The zsh loader adds an **`offensive` stage** (`… os offensive local`) on top of
  the Core order — band 85, linked as `85-offensive.zsh`. Keep offensive config in
  that layer, not in `core/`.
- **Don't reintroduce an OS layer here.** There is no `os/` directory any more. A
  package manager, a clipboard backend, a path prepend or an `ID=` gate is a sign the
  change belongs in `dotfiles-Debian`, which covers Kali.
- **The three role destinations are Core's to decide, not this repo's.**
  `blib_link_role_layer` (v4.13.1+) links `offensive/offensive.zsh` → band 85,
  `offensive/offensive.conf` → `$CONFIG/tmux/role.conf`, and `offensive/templates/` →
  `$CONFIG/offensive/templates`. Don't hand-roll them again — the block this replaced
  had already drifted from Defense's copy of the same three links. `role.conf` is
  sourced **last** by Core's `tmux.conf`, which is why the `prefix + e` binding lives
  there rather than in an OS overlay: anything sourced earlier can have its key taken
  back by a later `bind`.
- **`--install` has two routes and a third category, and they are not equivalent.** On
  Kali it apt-installs `install/offensive-packages.txt`. On any other Debian-family box it
  installs a small **portable subset** via pipx and go — and pipx's names differ from
  Kali's (`secretsdump.py` not `impacket-secretsdump`, `certipy` not `certipy-ad`), so
  those `HAVE_*` flags will not fire there. The bootstrap's probe knows both names; the
  shell layer does not, yet.
  **The third category runs on BOTH routes**: `_install_apt_absent` (`bootstrap.sh`)
  pipx-installs ROADtools (`roadrecon`, `roadtx`) on Kali too, because apt cannot supply
  it anywhere — so `--install` on Kali is *not* apt-only, which is what this bullet used
  to imply. `install/offensive-packages.txt` says the same thing more bluntly: ROADtools
  is "the ONE upstream tool this file names that `--install` REALLY INSTALLS".

**WSL2 is NAT'd** — a listener/reverse shell isn't LAN-reachable until mirrored
networking is enabled in the *Windows-side* `%UserProfile%\.wslconfig`
(`networkingMode=mirrored`), **not** `/etc/wsl.conf`. That still bites operationally,
but the WSL config itself now lives in `dotfiles-Debian/wsl/`.

Keep all engagement data in `~/engagements` (outside the repo); the repo ships a
paranoid `.gitignore` as backup.

## Where things are

- `offensive/` — engagement scaffolding (the role layer)
- `offensive/hacktheplanet` — CTF/HTB/engagement command cheatsheet (field reference under `OFFENSIVE-METHODOLOGY.md`); folds by section in vim, symlinked to `~/hacktheplanet`, opened with `htp`
- `offensive/exploitdev` — binary-exploitation companion (stack/SEH overflows, egghunters, shellcode, DEP/ASLR, PE backdooring, plus a vulnserver command→bug→technique map as the practice target); same vim-fold UX, symlinked to `~/exploitdev`, opened with `xdev`
- `offensive/evasion` — defense-evasion companion (AV/AMSI/AppLocker bypass, client-side macro access, process injection, egress/C2, advanced AD); symlinked to `~/evasion`, opened with `evade`
- `offensive/ippsec` — **the method**: workflow habits + signature moves from IppSec's HTB catalog (the "always be running recon" loop, shell stabilization, the scripted `cmd.Cmd` pseudo-shell, the unsticking playbook) — the altitude *above* the command refs; same vim-fold UX, symlinked to `~/ippsec`, opened with `ipp`. Reusable starting points in `offensive/templates/`: `pseudo-shell.py`, plus `engagement.md`/`finding.md` scaffolds. Helpers in `offensive/offensive.zsh`: `mkengagement` (dated engagement tree), `eng` (fzf engagement switcher — the shell twin of the `prefix+e` tmux popup), `bhce` (NetExec → BloodHound CE), `nmapsweep`, `ttyup`, `note`, `logshell` (`script(1)` audit-trail recorder), `lhost`, `hethttp` (quick delivery web server on `0.0.0.0`, advertises the reachable callback URL via `lhost`), `cde`, `rocks`, `redup` (manual, opt-in refresh of the fast-moving offensive tools — nuclei/katana/searchsploit; attacker box only, never mid-engagement)
- `offensive/offensive.conf` — the role layer's tmux bits (the `prefix + e` engagement popup), linked to `~/.config/tmux/role.conf` and sourced last by Core
- `offensive/tmux/tmux-eng.sh` — fuzzy engagement-session switcher (the offensive twin of Core's `tmux-sesh.sh`), invoked by the `prefix + e` popup in `offensive/offensive.conf`
- `PURPLE-TEAM.md` — defensive mirror of `hacktheplanet`: Splunk/Sentinel detections + Windows event-ID reference per attack (from TrustedSec's Actionable Purple Teaming, BH USA 2023)
- `offensive/companion` — **a vendored `git subtree` of [dotgibson/htpx](https://github.com/dotgibson/htpx)** (provenance in `companion.lock`): the structured, ATT&CK-tagged, red↔blue-paired corpus (`entries/red|blue/*.md`) browsed with `htpx` (fzf: pick → preview attack beside its detection → fill `{{slots}}` → `clip`); dir symlinked to `~/companion`. **Same rule as `core/`: do not hand-edit the vendored tree** — it's overwritten on the next sync. Edit upstream in htpx, then run `scripts/sync-companion.sh` (pulls htpx `main` + bumps `companion.lock`; or do the `git subtree pull --prefix=offensive/companion <htpx> main --squash` + lock bump by hand). It's the **source of truth** for the paired slice; `gen-views.sh` generates the marked blocks in `hacktheplanet`/`PURPLE-TEAM.md` from the entries and `.github/workflows/companion.yml` drift-gates them (`hacktheplanet`/`PURPLE-TEAM.md` stay canonical for everything *outside* the markers)
- `install/offensive-packages.txt` — the apt list `--install` uses **on Kali only**
- `install/corpus-commands.lst` — the classifier `test/check-corpus-commands.sh` reads for
  every red-corpus command the apt manifest cannot account for on its own (renamed
  binaries, deliberately-absent tools, assumed-present commands)
- `install/impacket-binaries.lst` — every `impacket-*` command Kali puts on PATH. Its
  whole purpose is to make an invented binary **fail**: it is why `impacket-petitpotam`
  is rejected (#208). The corpus-commands gate must stay offline, so it reads this
  checked-in roster rather than asking apt; `packages.yml` keeps the roster honest
- `install/tools.lst` — the host-tool probe list: what `bootstrap.sh` reports on. A
  command belongs here only if the offensive **role layer** probes or invokes it by bare
  name — usually `offensive/offensive.zsh`, but `tmux` is there for `offensive.conf` and
  `offensive/tmux/tmux-eng.sh`. A tool the cheatsheets merely mention does not belong
- `OFFENSIVE-METHODOLOGY.md` — the engagement playbook
- `aliases.md` — the role layer's helper/alias reference (the shell twin of the four
  field references; documents `htp`/`xdev`/`evade`/`ipp`/`htpx` and the `offensive.zsh`
  helpers, including why the openers are read-only)
- `bootstrap.sh` — symlinks Core + the offensive role layer; probes host tools; `--install` is opt-in
- `core/` — vendored Core (read-only here; edit upstream in dotfiles-core)
