#!/usr/bin/env bash
# test/check-view-counts.sh
# ──────────────────────────────────────────────────────────────────────────────
# VIEW COUNTS — do the flat views still state the corpus's REAL sizes?
#
# `offensive/hacktheplanet`, `PURPLE-TEAM.md` and `OFFENSIVE-METHODOLOGY.md` each open
# with a paragraph explaining how much of the companion corpus they project and how much
# they deliberately do not. Those paragraphs quote NUMBERS — 106 red, 105 blue, 19
# projected, 24 projected, 211 overall — and every one is hand-typed. Two of the three
# files say so about themselves: "These counts are hand-maintained and go stale on every
# companion-sync. If they disagree with `ls offensive/companion/entries/blue | wc -l`,
# this file is wrong, not the corpus." This gate is that sentence, executed.
#
# THEY HAD GONE STALE, TWICE. CHANGELOG's v2.10.0 entry records fixing exactly this; the
# v2.10.1 sync broke it again (dotgibson/dotfiles-Offense#261, #262). Nothing noticed,
# because nothing looked:
#
#   gen-views.sh --check     byte-compares the CONTENT of each generated block against its
#                            entry. It has no opinion on how many blocks exist, and none at
#                            all on the hand-authored prose around them.
#   companion-freshness      is the vendored subtree behind htpx? A count in a sentence is
#                            not a subtree.
#   companion-integrity      tree SHA vs companion.lock. Provenance, not prose.
#   check-corpus-commands    do the corpus's COMMANDS resolve? Never reads the views.
#   markdownlint             style. `101` and `102` lint identically.
#
# WHY THIS GATE IS REPO-OWNED AND LIVES HERE. The numbers describe the vendored corpus,
# but the SENTENCES are this repo's own hand-authored prose — hacktheplanet and
# PURPLE-TEAM.md are repo-owned files. offensive/companion/ is a git-subtree copy of
# dotgibson/htpx, overwritten by scripts/sync-companion.sh, so gen-views.sh cannot be
# extended to do this: an edit there is lost on the next sync. The gate belongs on this
# side of the boundary because the thing that goes stale is on this side.
#
# WHAT IT CANNOT CHECK — deliberately, and this is not a backlog. Every remaining figure in
# those paragraphs is a SEMANTIC CLASSIFICATION of an entry's content, not a property of
# the tree: 59 cloud/SaaS/CI-CD red, 13 C2-egress/Impact, 7 Linux post-ex, 71 blue entries
# with no Windows event ID, 72 red corpus-only, 79 blue corpus-only, 151 combined, and the
# 68%/75% shares. Nothing in entries/*.md marks an entry "cloud"; a human read the corpus
# and assigned those buckets. Re-implementing that judgement in grep would be wrong more
# often than the prose is. Percentages are ungated for a second reason: which way to round
# a share that lands on .5 is an editorial call, and a gate that overrules it is a
# nuisance. Those
# slots appear as `-` in the claim table below, so the blind spots are reviewable source
# rather than an omission. The ONE exact relation that IS free — the combined numerator
# must equal the sum of the two stated numerators — is checked as tier 2.
#
# MATCHING STRATEGY, and it is the fragile part; three decisions:
#
#   1. Match a FLATTENED copy. All these sentences wrap mid-clause and two live inside a
#      markdown blockquote, so every line carries `> `. Strip the quote markers, fold
#      newlines to spaces, squeeze runs. A reflow, an added word or a `gq` pass then costs
#      nothing. That is the biggest fragility reduction available to a prose check.
#   2. ASCII-ONLY anchors that never cross an em dash. These sentences contain U+2014;
#      under LC_ALL=C that is three bytes and `.` is one, so any pattern spanning one is a
#      byte-width trap. Every anchor below stops short of the dashes.
#   3. POSITIONAL digit slots. One ERE per claim; its [0-9]+ runs are compared left to
#      right against a table, with `-` for a slot the gate cannot derive.
#
# THE ANCHOR IS THE COUPLING, and rewriting a sentence WILL break it. That is a different
# failure from a stale number and gets a different exit code and a different message, so a
# maintainer is never told "the count is wrong" when the real answer is "re-anchor me".
#
# REPORTER, not mutator — it never writes to the tree.
#
# Exit codes:
#   0  every derivable number in the prose matches the tree, or a graceful skip
#   1  the gate could not do its job: not a work tree, no corpus, a broken gen/end marker
#      pairing, or an anchor that no longer matches exactly once (the prose was rewritten)
#   2  DRIFT — the prose states a number the tree contradicts. This is the signal.
#
# Usage:
#   test/check-view-counts.sh        # or: make view-counts
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
# `set -e` is deliberately off (the exit code IS the result), so guard the cd explicitly.
cd -- "$REPO_ROOT" || exit 1

# Every anchor is pure ASCII and never spans one of the em dashes in these sentences, so
# byte-wise matching is both correct and locale-proof. Pin it rather than inherit it.
export LC_ALL=C

if [[ -r "$REPO_ROOT/core/lib/ux.sh" ]]; then
  # shellcheck source=core/lib/ux.sh
  source "$REPO_ROOT/core/lib/ux.sh"
fi
say()  { printf '%s::%s %s\n' "${UX_BLU:-}" "${UX_RST:-}" "$*"; }
ok()   { printf '%s%s%s %s\n' "${UX_GRN:-}" "${UX_OK:-+}"   "${UX_RST:-}" "$*"; }
skip() { printf '%s%s%s %s\n' "${UX_YEL:-}" "${UX_INFO:--}" "${UX_RST:-}" "$*"; exit 0; }
bad()  { printf '%s%s%s %s\n' "${UX_RED:-}" "${UX_ERR:-x}"  "${UX_RST:-}" "$*" >&2; }
die()  { bad "view-counts: $*"; exit 1; }

RED_DIR="offensive/companion/entries/red"
BLUE_DIR="offensive/companion/entries/blue"
HTP="offensive/hacktheplanet"
PT="PURPLE-TEAM.md"
OM="OFFENSIVE-METHODOLOGY.md"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || skip "view-counts: not a git work tree — skipping."
[[ -d "$RED_DIR" && -d "$BLUE_DIR" ]] \
  || skip "view-counts: no companion corpus vendored here — skipping."
for f in "$HTP" "$PT" "$OM"; do
  [[ -r "$f" ]] || die "$f is missing — cannot verify its counts."
done

# ── the mechanically-derivable numbers ───────────────────────────────────────
# git ls-files, not ls: only TRACKED files count, so an untracked scratch note in
# entries/ cannot move the number, and the count is exactly what CI sees. -z plus a
# NUL tally survives a filename with whitespace.
count_tracked() { git ls-files -z -- "$1" | tr -dc '\0' | wc -c; }
count_markers() { grep -cE "$2" -- "$1" || :; }

red_total="$(count_tracked "$RED_DIR/*.md")"
blue_total="$(count_tracked "$BLUE_DIR/*.md")"
((red_total > 0 && blue_total > 0)) \
  || die "the corpus directories are present but hold no tracked *.md entries."

# A projected entry is one generated block. Assert gen/end pairing before trusting either —
# an unbalanced marker means the parser's premise is broken, which is exit 1 (a gate
# problem) and not exit 2 (a prose problem).
red_gen="$(count_markers  "$HTP" '^# companion:gen ')"
red_end="$(count_markers  "$HTP" '^# companion:end ')"
blue_gen="$(count_markers "$PT"  '^<!-- companion:gen ')"
blue_end="$(count_markers "$PT"  '^<!-- companion:end ')"
((red_gen  == red_end))  || die "$HTP has $red_gen gen markers but $red_end end markers."
((blue_gen == blue_end)) || die "$PT has $blue_gen gen markers but $blue_end end markers."

red_projected="$red_gen"
blue_projected="$blue_gen"
blue_unprojected=$(( blue_total - blue_projected ))
corpus_total=$(( red_total + blue_total ))

say "corpus          : ${red_total} red / ${blue_total} blue  (${corpus_total} overall)"
say "projected       : ${red_projected} into ${HTP} / ${blue_projected} into ${PT}"
say "blue unprojected: ${blue_unprojected}"

# ── claim table ──────────────────────────────────────────────────────────────
flatten() { sed -E 's/^[[:space:]]*>+[[:space:]]?//' "$1" | tr '\n' ' ' | tr -s '[:space:]' ' '; }

drift=0
unanchored=0
VC_LAST=()   # digits captured by the last successful check(), for the tier-2 relations

# check <file> <label> <anchor-ERE> <slot…>
#   Each slot is `N:where-N-comes-from`, or `-` for a figure the gate cannot derive.
#   The anchor must match EXACTLY ONCE in the flattened file; its [0-9]+ runs are paired
#   with the slots left to right.
check() {
  local file="$1" label="$2" anchor="$3"; shift 3
  local -a want=("$@") got=()
  local flat hit n i exp src
  VC_LAST=()

  flat="$(flatten "$file")"
  n="$(grep -oE -- "$anchor" <<<"$flat" | grep -c .)"
  if ((n != 1)); then
    bad "view-counts: $file — the anchor for \"$label\" matched $n times, need exactly 1."
    bad "    anchor: $anchor"
    bad "    The sentence was rewritten or removed. This is a GATE problem, not a stale"
    bad "    count: restore the phrasing, or re-anchor it in test/check-view-counts.sh."
    unanchored=1
    return
  fi

  hit="$(grep -oE -- "$anchor" <<<"$flat")"
  mapfile -t got < <(grep -oE '[0-9]+' <<<"$hit")
  if ((${#got[@]} != ${#want[@]})); then
    bad "view-counts: $file — \"$label\" has ${#got[@]} numbers, the table expects ${#want[@]}."
    bad "    matched: $hit"
    unanchored=1
    return
  fi
  VC_LAST=("${got[@]}")

  for i in "${!want[@]}"; do
    [[ "${want[i]}" == - ]] && continue
    exp="${want[i]%%:*}"; src="${want[i]#*:}"
    if [[ "${got[i]}" != "$exp" ]]; then
      bad "view-counts: $file — stale count in \"$label\""
      bad "    sentence : $hit"
      bad "    number $((i + 1)) of that sentence says ${got[i]}, the tree says ${exp}"
      bad "    source   : $src"
      drift=1
    fi
  done
}

# 1 — hacktheplanet's projection paragraph.
#     "…19 of its 106 red entries are (24 of 105 blue in PURPLE-TEAM.md)."
check "$HTP" "hacktheplanet projection paragraph" \
  '[0-9]+ of its [0-9]+ red entries are \([0-9]+ of [0-9]+ blue in PURPLE-TEAM\.md\)' \
  "${red_projected}:generated blocks in ${HTP} (grep -c '^# companion:gen ')" \
  "${red_total}:git ls-files ${RED_DIR}/*.md" \
  "${blue_projected}:generated blocks in ${PT} (grep -c '^<!-- companion:gen ')" \
  "${blue_total}:git ls-files ${BLUE_DIR}/*.md"

# 2 — PURPLE-TEAM.md's scope note.
#     "…only 24 of the companion's 105 blue entries project here. The other 81 mostly…"
check "$PT" "PURPLE-TEAM scope note" \
  "only [0-9]+ of the companion's [0-9]+ blue entries project here\. The other [0-9]+ mostly" \
  "${blue_projected}:generated blocks in ${PT} (grep -c '^<!-- companion:gen ')" \
  "${blue_total}:git ls-files ${BLUE_DIR}/*.md" \
  "${blue_unprojected}:blue_total - blue_projected = ${blue_total} - ${blue_projected}"

# 3 — the same unprojected figure, restated one paragraph later. It can drift on its own,
#     so it gets its own claim. The 71 beside it is semantic (see the header) — slot `-`.
check "$PT" "PURPLE-TEAM no-event-ID breakdown" \
  'Of those [0-9]+, \*\*[0-9]+\*\* genuinely carry no Windows event ID' \
  "${blue_unprojected}:blue_total - blue_projected = ${blue_total} - ${blue_projected}" \
  -

# 4 — OFFENSIVE-METHODOLOGY.md's corpus-share sentence. Only the two DENOMINATORS are
#     derivable; the numerators (72, 79) and the percentages are semantic.
om_shares=()
check "$OM" "OFFENSIVE-METHODOLOGY corpus share" \
  '\*\*[0-9]+ of the [0-9]+ red entries \([0-9]+%\) and [0-9]+ of the [0-9]+ blue \([0-9]+%\)\*\*' \
  - \
  "${red_total}:git ls-files ${RED_DIR}/*.md" \
  - \
  - \
  "${blue_total}:git ls-files ${BLUE_DIR}/*.md" \
  -
om_shares=("${VC_LAST[@]}")

# 5 — "…151 of 211 overall…". The numerator is the sum of the two semantic numerators
#     above (tier 2); the denominator is the whole corpus and is derivable.
om_overall=()
check "$OM" "OFFENSIVE-METHODOLOGY overall total" \
  '[0-9]+ of [0-9]+ overall' \
  - \
  "${corpus_total}:red_total + blue_total = ${red_total} + ${blue_total}"
om_overall=("${VC_LAST[@]}")

# ── tier 2: internal consistency ─────────────────────────────────────────────
# The gate does not know whether 72, 79 and 151 are RIGHT — they are editorial buckets.
# It does know they must SUM, so a half-update (76 corrected, 145 forgotten) is caught.
# No rounding is involved, which is exactly why the percentages next to them are not here.
if ((${#om_shares[@]} == 6 && ${#om_overall[@]} == 2)); then
  sum=$(( om_shares[0] + om_shares[3] ))
  if (( om_overall[0] != sum )); then
    bad "view-counts: $OM — the combined figure does not add up"
    bad "    says ${om_overall[0]} of ${om_overall[1]} overall, but ${om_shares[0]} red + ${om_shares[3]} blue = ${sum}"
    bad "    (All three are semantic buckets the gate cannot derive — but they must sum.)"
    drift=1
  fi
fi

# ── result ───────────────────────────────────────────────────────────────────
if ((unanchored)); then
  bad ""
  bad "  Nothing above is a claim that a NUMBER is wrong — the gate could not find the"
  bad "  sentence it measures. Fix the anchor in test/check-view-counts.sh alongside the"
  bad "  rewrite; a prose gate whose anchors silently rot is worse than no gate."
  exit 1
fi

if ((drift)); then
  bad ""
  bad "  These counts are hand-typed prose about a VENDORED corpus, and they go stale on"
  bad "  every scripts/sync-companion.sh. The tree is right and the sentence is wrong:"
  bad "  edit the repo-owned view files, never offensive/companion/ (a subtree copy of"
  bad "  dotgibson/htpx, overwritten on the next sync)."
  bad ""
  bad "  Cross-check the SEMANTIC figures by hand while you are in there — the gate does"
  bad "  not know them: 59 cloud/SaaS/CI-CD, 13 C2-egress/Impact, 7 Linux, 71 no-event-ID,"
  bad "  79 blue corpus-only, and the 68%/75% shares."
  bad ""
  bad "  The ${red_projected} entries currently projected into ${HTP}:"
  grep -oE '^# companion:gen .*' "$HTP" | sed 's/^# companion:gen /      /' >&2
  exit 2
fi

ok "view-counts: ${red_total} red / ${blue_total} blue, ${red_projected} + ${blue_projected} projected — all 5 prose claims match"
