---
description: Go/no-go readiness check before cutting an htpx release — recommends the next version
argument-hint: "[target version X.Y.Z — optional]"
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git describe:*)
---

# /release-readiness

Answer ONE question: **is htpx ready to cut a release right now, and if so, what
version?** This is the go/no-go gate in front of htpx's release flow — it reports,
it never releases.

Target for this run: **$ARGUMENTS** (empty = infer the next version from the
unreleased work).

## How htpx releases (so the recommendation is actionable)

htpx is Keep-a-Changelog + SemVer. To cut a release you move the `[Unreleased]`
entries under a new `## [vX.Y.Z] - YYYY-MM-DD` heading and push to `main`:
`auto-tag.yml` reads the **top version heading in `CHANGELOG.md`**, tags `vX.Y.Z`,
and publishes a Release; `sync-fanout.yml` then opens a `companion.lock`-bump PR
against `dotfiles-Offense`. So **the version you recommend is literally the heading the
maintainer writes** — get it right.

## The readiness checklist (gather, then judge)

1. **Is there unreleased work worth shipping?** Read `CHANGELOG.md`'s `[Unreleased]`
   section and the Conventional Commits since the last release:
   `git describe --tags --abbrev=0` for the last `vX.Y.Z`, then
   `git log <last-tag>..HEAD --oneline`. If `[Unreleased]` is empty or only trivial
   (a lone `chore`/`ci` with no corpus or tooling change), the verdict is
   "hold — nothing to ship yet."
2. **Version coherence + the SemVer bump.** Cross-check the last `vX.Y.Z` tag against
   the `CHANGELOG.md` headings, then propose the next version from the unreleased
   content:
   - a **breaking** change (a removed/renamed entry `id`, a changed `{{slot}}`
     vocabulary, a removed field, or an explicit `feat!`/`BREAKING CHANGE`) → **major**
   - a `feat` (new entries, a new routine, new tooling) → **minor**
   - only `fix`/`chore`/`docs`/`ci` (tag corrections, prose) → **patch**
3. **Green tree before you ship (maintainer pre-flight).** htpx ships the red↔blue
   corpus, so a release should go out green — but this routine runs sandboxed with no
   GitHub-API / `gh` / web access, so it **cannot** read CI status or the issue
   tracker. Surface these as **confirmations the maintainer must tick**, not checks
   you performed: (a) `ci.yml` is green on `main` (pairing + `{{slot}}` + view-drift +
   shell lint), and (b) no open `corpus-review` issue flags something that ought to
   ride or block the release.
4. **Downstream awareness.** A release **fans out to `dotfiles-Offense`** (its
   `offensive/companion/` + `companion.lock`) via `sync-fanout.yml`. Surface that as
   context — it's not a blocker, but the maintainer should expect the Offense PR.

## How to report

A one-line **verdict** up top — **READY to cut vX.Y.Z** or **HOLD** — then:

- **What would ship** — the grouped highlights from `[Unreleased]` + the commits (the
  release's story).
- **Proposed version + why** — the SemVer bump the unreleased content implies, with the
  single commit/entry that drives it (esp. anything breaking).
- **Blockers / pre-flight** — anything that must be true first (red `ci.yml`, an
  unaddressed `corpus-review` finding), each with the one thing that clears it.
- **Next step** — literally: write `## [vX.Y.Z] - <today>` under `[Unreleased]` in
  `CHANGELOG.md`, move the entries under it, and push to `main` (auto-tag does the
  rest) — when READY; or the specific blocker to clear when HOLD.

Report only — do **not** edit `CHANGELOG.md`, run `auto-tag.sh`, or cut a tag. The
maintainer drives the release from here.
