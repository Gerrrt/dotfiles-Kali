---
description: Draft the next htpx release's CHANGELOG entry from Conventional Commits (report-first)
argument-hint: "[from-ref — optional, defaults to the last release tag]"
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git describe:*)
---

# /release-notes

Draft the `CHANGELOG.md` entry for the next tag from its Conventional Commits — the
report-first preview a maintainer curates into `[Unreleased]` before cutting the
release. Complements `/release-readiness` (which decides *whether* to release and
*what version*); this drafts *what goes in it*.

Range for this run: **$ARGUMENTS** (empty = since the last release tag; otherwise
`$ARGUMENTS..HEAD`).

## How to draft

1. **Resolve the range.** Last release → `HEAD`:
   `git describe --tags --abbrev=0` gives the last `vX.Y.Z`; then
   `git log <last-tag>..HEAD --no-merges --format='%s%n%b'`. (htpx has no git-cliff —
   draft straight from the log; the grouping is your job.)
2. **Group by Conventional-Commit type into Keep-a-Changelog sections**, in this
   order, skipping any that are empty:
   - `feat:` → **Added** (or **Changed** if it modifies existing behavior)
   - `fix:` → **Fixed**
   - a removed/renamed entry or field, or `feat!`/`BREAKING CHANGE:` → **Removed** /
     **Changed**, and call it out as **breaking**
   - `docs`/`chore`/`ci`/`refactor` → usually omit from user-facing notes unless they
     change something an operator would notice (fold the rest into a one-line
     "Internal" note or drop them).
   Corpus entries deserve special care: a new red↔blue pair is **Added**; an ATT&CK
   retag or detection fix is **Fixed/Changed** — name the entry `id`s.

## How to report

- **A ready-to-curate block** — a `## [vX.Y.Z] - <today>` heading (use the version
  `/release-readiness` recommends, or `vX.Y.Z` as a placeholder) with the grouped
  bullets, in Keep-a-Changelog style, ready to paste under `[Unreleased]`.
- **An editorial pass** — which bullets are user-facing vs internal plumbing, anything
  that reads as a **breaking change** (surface it loudly — it drives the major bump),
  and a suggested one-line **release headline**.

`CHANGELOG.md` prose is hand-curated (the *rationale* for a change, not its commit
subject), so treat the generated bullets as **raw material** — a scaffold to curate,
not a drop-in. Report only — do **not** edit `CHANGELOG.md` or cut a tag.
