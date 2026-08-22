---
description: Scout the offensive tooling ecosystem for newer/renamed/EOL tools worth tracking (report-first, never installs)
argument-hint: "[tool, category, or theme — optional, e.g. bloodhound, c2, ad, recon]"
allowed-tools: Task, Read, Grep, Glob, WebSearch, WebFetch
---

# /tool-scout

Surface **offensive tooling the operator should know about** — new or renamed tools,
successors to tools the repo lists, upstream projects that went EOL/archived, and
tools that gained their own updater and should join `redup`. The chore no script can
do, because it needs live research and taste. The red mirror of dotfiles-core's
`/tool-scout` (which scouts the modern-CLI stack).

The goal is a **reviewable proposal, not an install**. This is authorized
security-tooling maintenance for the operator's own pentest environment — it reports
on tool availability/currency; it never writes exploits and never runs an offensive
tool.

Focus for this run: **$ARGUMENTS** (empty = the whole offensive stack).

Delegate the web research to the `tool-scout` subagent (it has WebSearch/WebFetch
and its own context) and relay its ranked proposal.

## Establish the baseline first

Before researching, read what this repo already tracks so you don't "discover"
something already listed:

- `install/offensive-packages.txt` — the offensive inventory. **Read the annotations
  carefully**: the `# UPSTREAM` go-install / curl-installer list (tools not in apt or
  that move faster than the repo — e.g. `kerbrute`, `katana`, `sliver`, `havoc`,
  `caldera`), and the rename/EOL notes (e.g. "netexec — successor to CrackMapExec
  (CME archived 2023)", "bloodhound-ce-python vs the LEGACY bloodhound.py",
  "certipy-ad ESC1–ESC17"). These annotations are hand-maintained prose — a prime
  place for drift.
- `offensive/offensive.zsh` — the `HAVE_*`-guarded tool set, and **`redup`'s updater
  list** (the fast-movers it refreshes: `nuclei` engine+templates, `searchsploit`,
  and go-installed apt-absent tools like `kerbrute`). Note `redup` is **manual,
  opt-in, attacker-box-only, never mid-engagement** — respect that framing.
- `install/packages.txt` — the base CLI stack (for context on what's OS-native vs
  offensive).

## What to research

1. **Successors & renames.** For the listed tools, has a successor overtaken one (the
   way `netexec`/`nxc` succeeded CrackMapExec, or `bloodhound-ce` succeeded legacy
   BloodHound)? Has an upstream renamed its binary or package?
2. **EOL / archived.** Is any listed upstream archived, unmaintained (no release in
   ~1–2 years), or superseded? Flag it with the current alternative.
3. **`redup` candidates.** Does any listed fast-mover now ship its own updater (like
   `nuclei -update`) and belong in `redup`'s refresh set? Conversely, is a `redup`
   tool now stably apt-packaged (so Core's `up` covers it)?
4. **Stale annotations.** Are the `install/offensive-packages.txt` notes still true —
   is "CME archived 2023" / "bloodhound.py is LEGACY" / a version claim current?
5. **New categories.** A genuinely useful offensive tool in a category the repo has no
   equivalent for, that fits a Kali/WSL2 engagement workflow.

For each candidate, verify it is real and current (check the actual project repo and
its latest release — do not trust a single blog post), and note its install path on
Kali/Debian (apt vs `go install` vs upstream installer) — this decides adoption cost.

## How to report

A ranked shortlist, each with:

- **What it is** and what it replaces / renames / supersedes (or the stale annotation
  it corrects).
- **Why it matters** to this stack (or why it's a skip).
- **Adoption cost** — apt vs `go install` vs upstream installer; whether it's a
  `redup` candidate; whether an `offensive-packages.txt` annotation needs updating.
- **Recommendation** — track / adopt / skip, with a one-line rationale.

Lead with your single strongest finding. "The offensive inventory is current and the
annotations still hold — nothing to change this cycle" is a valid, useful result.

## Engagement-safety guardrails

- **Report only. Never install, run, or update any offensive tool** — adoption and
  `redup` runs are a human, attacker-box, never-mid-engagement decision.
- Propose changes to `install/offensive-packages.txt`, `offensive/offensive.zsh`
  (`redup`), or the docs only as text in the report; do not edit unless explicitly
  asked.
