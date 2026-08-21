#!/usr/bin/env bash
# test/check-return-traps.sh
# ──────────────────────────────────────────────────────────────────────────────
# RETURN-TRAP DISCIPLINE — does any repo-owned bash arm a RETURN trap that fails to
# disarm itself?
#
# A bash RETURN trap is a GLOBAL slot, not a function-scoped one. Arm one inside a
# function and it stays armed in the CALLER's frame, firing a SECOND time when the
# caller returns — by which point the local it was cleaning up is out of scope, and
# `set -u` turns that into a fatal error. The canonical shape:
#
#     f()   { local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN; …; }
#     outer() { f; …; }          # ← aborts HERE, on outer's return, not on f's
#
# That is issue #198 (and dotgibson/dotfiles-Debian#2, the same bug in the sibling
# repo): bootstrap.sh's verified_install() leaked exactly this trap, so provision()
# blew up on return AFTER installing everything but BEFORE wire_links ran — a box
# carrying the whole stack and not one symlink, wearing the costume of a near-complete
# run. #198's instance is gone from this repo: 6d641d2 moved the entire SHA-pinned
# out-of-band install block to dotfiles-Debian and took verified_install with it. This
# gate exists so it cannot come back.
#
# WHY A GREP, of all things. The broken line is VALID BASH: shellcheck passes it and so
# does `bash -n`. And no gate anywhere in this fleet executes a real install path — every
# bootstrap CI job runs --links-only — so nothing observes the abort either. A textual
# check is the only thing that sees this class of bug at all.
#
# When it DOES surface at runtime, the reported line number is a decoy: bash attributes a
# RETURN trap to the last nested function DEFINITION executed in that frame, not to the
# trap line. Debian's abort blamed `_add_vendor_repo`, which had nothing to do with it.
# Don't chase the number — grep for the trap.
#
# THE FIX, in one line: make the trap body disarm first.
#
#     trap 'trap - RETURN; rm -rf "$tmp"' RETURN
#
# Cleanup on every exit path is unchanged, and a RETURN trap does not perturb the
# function's return status (`return 7` still surfaces as 7).
#
# SCOPE — bash only, repo-owned only. zsh has no RETURN signal at all (`trap 'x' RETURN`
# → "undefined signal"), so the .zsh layer cannot carry this bug and is not scanned. The
# two vendored subtrees (core/, offensive/companion/) are gated by their upstreams; a
# finding there is fixed there, not here. Same pathspec as the Makefile's $(SH_FILES).
#
# REPORTER, not mutator — it never writes to the tree.
#
# Exit codes (this repo's check-script convention — see test/check-routine-filter.sh):
#   0  clean, or a graceful skip (not a git work tree / no repo-owned bash)
#   1  a leaked RETURN trap — fix it, this is a bug and not a nudge
#
# Usage:
#   test/check-return-traps.sh        # or: make trap-guard
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
cd -- "$REPO_ROOT" || exit 1

# Core's bash UX palette when it's vendored (it is), plain text otherwise — the same
# degradation the sibling check scripts use, so they all read alike in a job log.
if [[ -r "$REPO_ROOT/core/lib/ux.sh" ]]; then
  # shellcheck source=core/lib/ux.sh
  source "$REPO_ROOT/core/lib/ux.sh"
fi
ok()   { printf '%s%s%s %s\n' "${UX_GRN:-}" "${UX_OK:-+}"   "${UX_RST:-}" "$*"; }
skip() { printf '%s%s%s %s\n' "${UX_YEL:-}" "${UX_INFO:--}" "${UX_RST:-}" "$*"; exit 0; }
bad()  { printf '%s%s%s %s\n' "${UX_RED:-}" "${UX_ERR:-x}"  "${UX_RST:-}" "$*" >&2; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || skip "check-return-traps: not a git work tree — skipping."

# Repo-owned bash only, mirroring the Makefile's SH_FILES pathspec exactly. Read with -z
# so a path containing whitespace survives the round trip.
files=()
while IFS= read -r -d '' f; do files+=("$f"); done < <(
  git ls-files -z '*.sh' ':!:core/**' ':!:offensive/companion/**'
)
((${#files[@]})) || skip "check-return-traps: no repo-owned bash to scan."

# Two deliberate looseness decisions, each of which a tighter pattern got wrong:
#
#   RETURN is matched as a SIGNAL TOKEN — followed by whitespace, `;` or end-of-line — NOT
#   merely as the last word on the line. Anchoring it to $ waves through
#       trap '…' RETURN  # note      and      trap '…' RETURN EXIT
#   and both of those leak in precisely the same way.
#
#   `trap` is matched as a WORD anywhere on the line, not anchored to the start of it.
#   Anchoring waved through the one-line function body, which is where this is most
#   likely to hide in the first place:
#       cleanup() { trap 'rm -rf "$t"' RETURN; }
#
# Then two filters. Whole-line comments are dropped, because this very file quotes the
# broken form to explain it and would otherwise flag itself. And a body that starts by
# disarming the slot is the fix, not the bug.
#
# -H so the file:line: prefix is present even when exactly one file is scanned; the
# comment filter reads that prefix.
hits="$(
  grep -HnE "(^|[[:space:]]|;)trap[[:space:]].*[[:space:]]RETURN([[:space:]]|;|$)" -- "${files[@]}" \
    | grep -vE '^[^:]*:[0-9]+:[[:space:]]*#' \
    | grep -v 'trap - RETURN'
)"

if [[ -n "$hits" ]]; then
  bad "check-return-traps: RETURN trap armed without disarming itself"
  printf '%s\n' "$hits" | sed 's/^/    /' >&2
  # shellcheck disable=SC2016  # the backticks below are literal prose inside the advice
  # text — `set -u` and `bash -n` are being NAMED, not run. Single quotes are deliberate:
  # the block also prints a $tmp that must survive to the reader verbatim.
  {
    printf '\n    A RETURN trap is a GLOBAL slot: this one survives into the CALLER'\''s\n'
    printf '    frame and fires again on ITS return, where the local it cleans up is\n'
    printf '    gone and `set -u` makes that fatal. Disarm first, and keep it first:\n\n'
    printf "        trap 'trap - RETURN; rm -rf \"\$tmp\"' RETURN\n\n"
    printf '    Background: issue #198, dotgibson/dotfiles-Debian#2, and the header of\n'
    printf '    this script. shellcheck and `bash -n` both pass the broken form.\n'
  } >&2
  exit 1
fi

ok "check-return-traps: ${#files[@]} repo-owned bash files — every RETURN trap disarms itself"
