# CLAUDE.md — dotfiles-Kali

Project memory for Claude Code, auto-loaded every session. For the shared Core
rules (the load order, the "is it Core?" test, the manifest contract) see
`core/README.md` and `core/CONTRIBUTING.md`.

## What this repo is

`dotfiles-Kali` is the **Role layer** of a **eleven-repo dotfiles system** built on
a three-layer model (Core → OS-native → Role): the OS-native layer for Kali
(Debian-family, `apt`, run under WSL2) **plus** an offensive engagement layer on
top. It is its own lineage — built directly, not stamped from the Fedora template.

## The rule that bites

`core/` is a **vendored `git subtree` copy of [dotfiles-core](https://github.com/dotgibson/dotfiles-core)** — *not*
editable here; changes under `core/` are overwritten on the next sync. Edit shared
Core config **in dotfiles-core**, `make audit`, then `make sync`.

Three things that actually bite on this repo:

- The zsh loader adds an **`offensive` stage** (`… os offensive local`) on top of
  the Core order — keep offensive config in that layer, not in `core/`.
- **Debian renames binaries** — `bat`→`batcat`, `fd-find`→`fdfind`. Core's
  `00-tools.zsh` already resolves both; don't "fix" aliases for it.
- **WSL2 is NAT'd** — a listener/reverse shell isn't LAN-reachable until mirrored
  networking is enabled in the *Windows-side* `%UserProfile%\.wslconfig`
  (`networkingMode=mirrored`), **not** `/etc/wsl.conf`.

Keep all engagement data in `~/engagements` (outside the repo); the repo ships a
paranoid `.gitignore` as backup.

## Where things are

- `offensive/` — engagement scaffolding (the role layer)
- `offensive/hacktheplanet` — CTF/HTB/engagement command cheatsheet (field reference under `OFFENSIVE-METHODOLOGY.md`); folds by section in vim, symlinked to `~/hacktheplanet`, opened with `htp`
- `offensive/exploitdev` — binary-exploitation companion (stack/SEH overflows, egghunters, shellcode, DEP/ASLR, PE backdooring, plus a vulnserver command→bug→technique map as the practice target); same vim-fold UX, symlinked to `~/exploitdev`, opened with `xdev`
- `offensive/evasion` — defense-evasion companion (AV/AMSI/AppLocker bypass, client-side macro access, process injection, egress/C2, advanced AD); symlinked to `~/evasion`, opened with `evade`
- `offensive/ippsec` — **the method**: workflow habits + signature moves from IppSec's HTB catalog (the "always be running recon" loop, shell stabilization, the scripted `cmd.Cmd` pseudo-shell, the unsticking playbook) — the altitude *above* the command refs; same vim-fold UX, symlinked to `~/ippsec`, opened with `ipp`. Reusable starting points in `offensive/templates/`: `pseudo-shell.py`, plus `engagement.md`/`finding.md` scaffolds. Helpers in `offensive/offensive.zsh`: `mkengagement` (dated engagement tree), `eng` (fzf engagement switcher — the shell twin of the `prefix+e` tmux popup), `bhce` (NetExec → BloodHound CE), `nmapsweep`, `ttyup`, `note`, `logshell` (`script(1)` audit-trail recorder), `lhost`, `hethttp` (quick delivery web server on `0.0.0.0`, advertises the reachable callback URL via `lhost`), `cde`, `rocks`, `redup` (manual, opt-in refresh of the fast-moving offensive tools — nuclei/searchsploit; attacker box only, never mid-engagement)
- `offensive/tmux/tmux-eng.sh` — fuzzy engagement-session switcher (the offensive twin of Core's `tmux-sesh.sh`), invoked by the `prefix + e` popup in `os/kali.conf`
- `PURPLE-TEAM.md` — defensive mirror of `hacktheplanet`: Splunk/Sentinel detections + Windows event-ID reference per attack (from TrustedSec's Actionable Purple Teaming, BH USA 2023)
- `offensive/companion` — **a vendored `git subtree` of [dotgibson/htpx](https://github.com/dotgibson/htpx)** (provenance in `companion.lock`): the structured, ATT&CK-tagged, red↔blue-paired corpus (`entries/red|blue/*.md`) browsed with `htpx` (fzf: pick → preview attack beside its detection → fill `{{slots}}` → `clip`); dir symlinked to `~/companion`. **Same rule as `core/`: do not hand-edit the vendored tree** — it's overwritten on the next sync. Edit upstream in htpx, then run `scripts/sync-companion.sh` (pulls htpx `main` + bumps `companion.lock`; or do the `git subtree pull --prefix=offensive/companion <htpx> main --squash` + lock bump by hand). It's the **source of truth** for the paired slice; `gen-views.sh` generates the marked blocks in `hacktheplanet`/`PURPLE-TEAM.md` from the entries and `.github/workflows/companion.yml` drift-gates them (`hacktheplanet`/`PURPLE-TEAM.md` stay canonical for everything *outside* the markers)
- `install/offensive-packages.txt` — offensive tooling; `install/packages.txt` — base
- `os/kali.zsh`, `os/kali.conf`, `os/kali.gitconfig` — OS overlays
- `OFFENSIVE-METHODOLOGY.md` — the engagement playbook
- `bootstrap.sh` — symlinks Core + OS + offensive files into place
- `core/` — vendored Core (read-only here; edit upstream in dotfiles-core)
