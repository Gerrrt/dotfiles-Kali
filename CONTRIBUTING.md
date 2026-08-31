# Contributing to dotfiles-Offense

The README's three rules in full, plus how to actually run the gates.

## 1. Which layer owns the change?

This repo stacks **three** layers, and most mistakes here are "right change, wrong
layer". The test:

| If it…                                              | It belongs in                                                                                    |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| is identical on every machine                       | **Core** — [dotfiles-core](https://github.com/dotgibson/dotfiles-core), *not here*               |
| changes with the OS (apt, paths, clipboard, WSL)    | **[dotfiles-Debian](https://github.com/dotgibson/dotfiles-Debian)**, *not here* — it covers Kali |
| changes with the operator (engagements, tradecraft) | `offensive/`                                                                                     |
| is a paired red↔blue attack/detection entry         | **htpx** — [dotgibson/htpx](https://github.com/dotgibson/htpx), *not here*                       |

## 2. Never hand-edit a vendored subtree

`core/` and `offensive/companion/` are `git subtree` copies. **They are overwritten
on the next sync**, so an edit there is silent drift: it works until someone syncs,
and it never reaches the source of truth.

Three things enforce this, and you will meet all of them:

- a local `pre-commit` hook (installed by `bootstrap.sh`, or `make hooks`)
- `core-integrity` and `companion-integrity` in CI, comparing the vendored tree
  hash against `core.lock` / `companion.lock`
- `companion` in CI, asserting the generated blocks in `PURPLE-TEAM.md` and
  `hacktheplanet` still match the entries they came from

The two subtrees update differently, and the asymmetry is deliberate.

**`core/` arrives by fan-out.** A `dotfiles-core` release opens a `core.lock`-bump PR
here automatically (`sync-fanout.yml`). Merge it, then:

```bash
make lint && make test
```

There is no local pull. `make core-sync` reports how far behind you are and explains
this; it writes nothing. The reason is `dotfiles-core#676`: a vendored `core/` is a
**filtered subset** of upstream (`core.manifest` + `core.vendor`), and `git subtree pull`
merges the *whole* tree, so pulling would land files `core/` is not supposed to carry and
`core-integrity` would report `TAMPERED` with no hand-edit anywhere. This repo was the
fleet's one sanctioned second writer into `core/`; that sanction rested on the pull
stamping the lock from *what it actually pulled*, which a filtered vendor makes
impossible.

**`offensive/companion/` still pulls**, because htpx vendors its whole tree and has no
allowlist:

```bash
make companion-sync
make lint && make test
```

It stamps `companion.lock` from the squash commit's `git-subtree-split` trailer. Commit
the lock together with the pull.

## 3. Engagement data never enters this repo

It lives in `~/engagements`, outside any git tree. Everything else is a backstop:

- The helpers that write engagement data (`note`, `logshell`, `bhce`, `nmapsweep`)
  refuse to run inside a git work tree unless `$ENGAGEMENT` is set.
- `hethttp` refuses to serve a git work tree on `0.0.0.0`.
- The four field references open **read-only** (`htp -w` to actually edit one) —
  they are tracked files, and their "target fill" recipe writes a copy under
  `$ENGAGEMENT`, never the buffer.
- `.gitignore` blocks the directory names `mkengagement` creates, plus the usual
  artifact types.
- `gitleaks` scans the working tree **and** full history in CI.

If you add a helper that writes files, resolve its root with `_eng_writeroot`.

## Running the gates

```bash
make            # list every target
make lint       # shellcheck + bash -n / zsh -n + markdownlint + trap discipline
make test       # routine-filter classifier + companion view drift + corpus commands
make bootstrap-dry
```

`make lint` skips a linter that isn't installed rather than failing; CI installs
pinned, SHA-256-verified copies from `core/scripts/tool-versions.env`, so CI is the
authority. `make packages-check` needs apt and is advisory — the authoritative run
is the `packages` workflow, in a `kali-rolling` container.

`make corpus-commands` answers a question no other gate asks: *does every command the
red corpus tells an operator to run actually exist?* `gen-views.sh --check` byte-compares
the 19 **projected** entries; 84 of 103 are unprojected and were read by nothing. That is
how `impacket-petitpotam` and `dfscoerce` shipped — neither is a real command, and a human
found them. It resolves each command against `install/offensive-packages.txt`, the
`impacket-binaries.lst` roster, and the classifications in `install/corpus-commands.lst`,
where every excuse must carry its reasoning in prose. It is offline, so unlike
`packages-check` it can be required. **When it reddens on a `companion-sync` PR the fix is
usually upstream in htpx, not here** — see rule 2. That is [#208][i208].

`make trap-guard` is the one leg with no upstream equivalent. It refuses a bash
`trap … RETURN` whose body does not start by disarming the slot, because a RETURN
trap is *global*, not function-scoped: armed inside a function it survives into the
caller's frame and fires again on that frame's return, where the local it cleans up
no longer exists and `set -u` kills the run. That is [#198][i198], and the broken
form is valid bash — shellcheck and `bash -n` both pass it. Write it as
`trap 'trap - RETURN; rm -rf "$tmp"' RETURN`. The gate runs in CI too, as the
`return-traps` job in `checks.yml`.

[i198]: https://github.com/dotgibson/dotfiles-Offense/issues/198
[i208]: https://github.com/dotgibson/dotfiles-Offense/issues/208

## Touching `bootstrap.sh`

It is idempotent and must stay that way.

```bash
./bootstrap.sh --dry-run       # full plan, changes nothing
./bootstrap.sh --links-only    # then run it twice — no new *.pre-dotfiles.* files
```

This repo installs nothing by default — your OS-native layer owns packages, and
`dotfiles-Debian` covers Kali. `./bootstrap.sh --install` is the opt-in: apt from
`install/offensive-packages.txt` on Kali, and a small pipx/go subset on any other
Debian-family box. A tool the shell layer probes also belongs in
`install/tools.lst`, which is what the host-tool report reads. `curl | sh` is not an
option here; pipx and go verify their own downloads, which is why those two are the
only non-apt routes.

## What `main` enforces

`main` is covered by a ruleset, so the gates are not advisory:

- **No direct pushes.** Every change lands through a PR (0 approvals required —
  this is a single-maintainer repo, and GitHub will not let you approve your own).
- **11 required checks**, all of which run on *every* PR: shell lint, actionlint,
  the bootstrap test (`links-only` + `lint`), core-integrity, companion integrity,
  companion view drift, corpus command resolution, gitleaks, markdownlint, and the
  routine-filer classifier.
- **Branches must be up to date** before merging, so a PR opened before a gate
  existed cannot merge on stale checks.
- Force pushes and deletion of `main` are blocked.

Two checks are deliberately *not* required. `package names resolve` is advisory —
Kali is rolling and a package can vanish mid-migration, so it reports to the job
summary rather than failing. CodeQL is GitHub-managed and may not run on every
change, and a required check that never starts blocks a PR forever.

Merge commits stay enabled alongside squash and rebase: a `git subtree` pull carries the
`git-subtree-split` trailer that `scripts/sync-companion.sh` reads back, and squashing
would collapse it away. (`scripts/sync-core.sh` no longer reads it — it no longer pulls —
but the companion still does, so the setting stays.)

## Commits

[Conventional Commits](https://www.conventionalcommits.org/) —
`type(scope): summary`, e.g. `fix(offensive): refuse to write notes inside a repo`.
Add a line to `CHANGELOG.md` under `[Unreleased]` for anything user-visible.
