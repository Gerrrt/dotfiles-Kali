# Changelog

All notable changes to this repo's own layers — the OS overlays (`os/`,
`install/`), the offensive role layer (`offensive/`), `bootstrap.sh`, and the
tooling around the two vendored subtrees.

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
- `dotsync` hardcoded `~/dotfiles-Kali`; it now resolves this checkout.
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

- The gating workflows (`lint`, `bootstrap`, `companion`, `routine-filter`) no
  longer use trigger-level path filters: a `paths:`-skipped workflow produces no
  check run, so requiring one would hang every non-matching PR.
- `os/kali.gitconfig` no longer duplicates Core's `init.defaultBranch`, and
  `os/kali.zsh` no longer duplicates Core's `~/.local/bin` PATH prepend.
- `offensive/templates/engagement.md` documents the layout `mkengagement` actually
  creates.
