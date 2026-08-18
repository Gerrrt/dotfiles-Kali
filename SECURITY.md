# Security Policy

`dotfiles-Offense` is a **public** repository that ships offensive tooling
configuration. It contains no exploit code, no payloads, and no engagement data —
but it does configure tools that reach the network, and it installs software on
whatever machine runs `bootstrap.sh`. That makes it worth a disclosure path of its
own.

dotfiles-core's `SECURITY.md` explicitly puts this layer **out of its scope** and
directs layer-specific reports here.

## Reporting a vulnerability

Please use GitHub's **[private vulnerability
reporting](https://github.com/dotgibson/dotfiles-Offense/security/advisories/new)** —
it opens a private advisory thread visible only to the maintainers.

Do **not** open a public issue for anything in the "in scope" list below.

If private reporting is unavailable to you, email the maintainer address in
`README.md` and put `SECURITY` in the subject.

Expect an acknowledgement within a week. This is a personal project maintained in
spare time, so there is no formal SLA and no bounty.

## In scope

Things that would genuinely compromise a machine running these dotfiles:

- **Supply chain in `bootstrap.sh`** — an unverified download, a writable path used
  before verification, a step that can be induced to run attacker-controlled code.
  `--install` is the only path that fetches anything: apt on Kali, and pipx/go
  elsewhere, both of which verify against PyPI hashes and the Go checksum database.
  A step that bypasses either is a valid report.
- **Privilege escalation through the install path** — anything that widens what
  `sudo` is used for, a `sudo` invocation on an attacker-influenced path, or a
  world-writable artifact left behind.
- **Symlink handling** — `bootstrap.sh` and `core/lib/bootstrap-lib.sh` create links
  in `$HOME`. A path traversal, an unintended clobber, or a symlink cycle is in
  scope.
- **Engagement-data leakage** — anything that could route client data into the
  repository. The helpers in `offensive/offensive.zsh` refuse to write inside a git
  work tree without `$ENGAGEMENT`, and `.gitignore` is the backstop; a bypass of
  either is a valid report and is treated as high severity.
- **Secrets in history or in the tree** — despite the gitleaks gate in
  `.github/workflows/checks.yml`.
- **CI/workflow issues** — script injection into a workflow, an over-permissioned
  `GITHUB_TOKEN`, a mutable action reference that should be pinned.

## Out of scope

- **The offensive tools themselves.** `nmap`, `nxc`/NetExec, `impacket`, `sliver`,
  Metasploit and friends are third-party software. Report vulnerabilities in them to
  their own projects; this repo only lists and configures them.
- **"This repo enables attacks."** That is the stated purpose: it is tooling for
  **authorized** engagements under written rules of engagement. See
  `OFFENSIVE-METHODOLOGY.md`.
- **The vendored subtrees.** `core/` is a copy of
  [dotfiles-core](https://github.com/dotgibson/dotfiles-core) and
  `offensive/companion/` is a copy of [htpx](https://github.com/dotgibson/htpx).
  Report against those repositories — a fix here would be overwritten on the next
  sync. If you are unsure which layer owns the bug, report it here and it will be
  routed.
- Findings from an automated scanner with no demonstrated impact on a machine
  running these dotfiles.

## Supported versions

Only the tip of the default branch. This is a rolling configuration repository:
tags exist to record what was vendored at a point in time, not to designate a
maintained release line. Fixes land on `main`.
