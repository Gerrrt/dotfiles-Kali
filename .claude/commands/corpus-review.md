---
description: Judgment review of the htpx red↔blue corpus — ATT&CK correctness, pairing fidelity, coverage holes, detection quality (report-first)
argument-hint: "[tactic, platform, or detection-backend — optional, e.g. credential_access, aws, kql-entra-signin]"
allowed-tools: Read, Grep, Glob, WebSearch, WebFetch, Bash(git ls-files:*), Bash(git log:*)
---

# /corpus-review

Review the **quality and coverage** of the paired red↔blue corpus in
`entries/red/` and `entries/blue/` — the judgment half of the corpus gate.
`.github/workflows/ci.yml` already *enforces* the mechanical half on every change,
so this routine does **not** re-check what CI already proves. It reviews what an
awk script cannot: are the ATT&CK tags **correct**, does a blue entry actually
**detect** the red technique it's paired with, and is the coverage honest.

The goal is a **reviewable report, not edits** — like every routine in this fleet,
report-first: propose, rank, and link; change nothing.

Focus for this run: **$ARGUMENTS** (empty = the whole corpus).

## Establish what CI already proves (do NOT re-litigate)

`ci.yml` mechanically enforces, on every push/PR, all of the following — treat them
as given and never report them as findings:

- **Bidirectional pairing integrity** — every entry with a non-`null` `pair:`
  resolves to a mate whose `pair:` points back. A broken pair is already a red X.
- **`{{slot}}` vocabulary conformance** — every `{{slot}}` used in any red entry is
  handled by the `htpx` browser script.
- **View drift** — `gen-views.sh --check` guarantees the generated blocks in the
  flat views match their entries.
- **Shell lint** — shellcheck + `bash -n` on the scripts.

CI green means the corpus is structurally sound and internally consistent. It does
**not** mean the entries are *correct security content*. That's this routine's job.

## What to review (the judgment CI can't do)

Read the entries first: `git ls-files 'entries/red/*.md' 'entries/blue/*.md'`. Each
red entry carries `attack: {tactic, techniques}`, `platform`, `pair`; each blue
entry carries `attack: {tactic, techniques}`, `detection`, `event_ids`, `pair`.

1. **ATT&CK validity.** For each `attack.tactic` (a `TA00xx` ID) and each
   `attack.techniques` entry (`Txxxx[.xxx]`), verify against **live MITRE ATT&CK**
   (attack.mitre.org) that the ID exists and is not **deprecated or renamed** — the
   framework moves and sub-techniques get renumbered. Don't trust memory. Flag
   invalid, deprecated, or superseded IDs with the current replacement.
2. **Red↔blue semantic fidelity — the highest-value dimension.** CI proves the
   `pair:` link exists; it cannot prove the blue entry actually detects the red
   one. For each pair, read both bodies: does the blue detection query/event set
   genuinely fire on the red technique's real telemetry? Flag pairs where the
   detection keys on an artifact the attack doesn't produce, misses the technique's
   actual signal, or is a generic catch-all masquerading as a targeted detection.
3. **Tactic ↔ technique coherence**, and **red-vs-blue `attack` agreement** within a
   pair (a red entry tagged `T1558.003` paired with a blue entry tagged `T1550.002`
   is a real mismatch — decide which is right).
4. **Coverage holes.** Which ATT&CK tactics or platforms (on-prem AD, Entra/M365,
   AWS, GCP, K8s, Okta, GWS, CI/CD, SaaS) are thin (one fragile pair) or absent
   relative to what the corpus claims to cover? Rank by how central the gap is, not
   by raw ATT&CK breadth. **`pair: null` is legitimate for a recon entry** (e.g.
   `entries/red/smb-enum-nxc.md`) — never flag an intentionally-unpaired recon entry
   as a missing pair.
5. **Detection quality / duplication.** Is a blue detection too broad (alert
   fatigue) or too brittle (trivially evaded)? Are two entries near-duplicates that
   should merge? Is a `source:` provenance stale or a claim unsupported?

## How to report

A ranked shortlist, most-valuable first. For each finding:

- **The entry/entries or gap** — exact path(s) under `entries/`, or the uncovered
  tactic/technique (with its verified ATT&CK ID).
- **Why it matters** — the concrete problem: *deprecated technique ID X → now Y*,
  *blue entry Z doesn't actually detect its paired attack*, *tactic W has no
  coverage*, *these two entries duplicate*.
- **The proposed change** — retag to this ID, tighten this detection, author a pair
  for this technique, merge these two. Concrete enough to act on, but **do not make
  the edit**.
- **Confidence** — high / needs-a-human-look, one line of rationale.

Lead with your single strongest finding. "The corpus is well-tagged, pairings are
faithful, and coverage matches the claim — no material gaps this cycle" is a valid,
useful result; say so plainly rather than manufacturing findings.

## If a finding is adopted

htpx is the **source of truth** for the corpus. A fix is an edit to `entries/`
here, then `./gen-views.sh` to refresh any local views and `ci.yml` to gate it; the
change fans out to `dotfiles-Offense`'s `offensive/companion/` via the existing
`auto-tag.yml` → `sync-fanout.yml` release path. Never hand-edit the vendored copy
in Offense. Propose only — do not edit entries unless asked.
