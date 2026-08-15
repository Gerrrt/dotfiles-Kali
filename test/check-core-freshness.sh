#!/usr/bin/env bash
# test/check-core-freshness.sh
# ──────────────────────────────────────────────────────────────────────────────
# Has the vendored core/ fallen behind upstream dotfiles-core?
#
# The sibling of test/check-companion-freshness.sh, and the file THREE places in
# this repo already referenced before it existed:
#   • scripts/sync-companion.sh          ("same idiom as test/check-core-freshness.sh")
#   • test/check-companion-freshness.sh  ("mirrors test/check-core-freshness.sh")
#   • .github/workflows/companion-freshness.yml ("mirrors this repo's core-freshness watcher")
#
# Core staleness IS watched centrally — dotfiles-core runs fleet-drift.yml weekly
# across every consumer, and sync-fanout.yml opens a core.lock-bump PR here on each
# release. This is the consumer-side belt to that braces: it answers the question
# from inside this repo, with no dotfiles-core checkout and no fleet credentials, so
# `make core-check` works on a plane.
#
# INTEGRITY vs STALENESS are different questions, deliberately kept apart (the same
# split core-integrity.sh documents upstream): a tree can be perfectly current AND
# hand-edited, or pristine BUT ten releases behind. core-integrity.yml answers the
# first; this answers the second.
#
# Exit codes (identical contract to check-companion-freshness.sh, so the two
# workflows can share one branching shape):
#   0  current, or skipped (no vendored core/, or upstream unreachable)
#   1  hard failure (malformed core.lock)
#   2  BEHIND — upstream has moved on; the nudge to run scripts/sync-core.sh
#
# Overrides: CORE_UPSTREAM (remote/URL/local clone), CORE_BRANCH (ref to compare).
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

PREFIX="core"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
LOCK="$REPO_ROOT/core.lock"
DEFAULT_REPO="dotgibson/dotfiles-core"
# `set -e` is deliberately off here (the exit code IS the result), so guard the cd
# explicitly — continuing in the wrong directory would read the wrong core.lock.
cd -- "$REPO_ROOT" || exit 1

if [[ -r "$REPO_ROOT/core/lib/ux.sh" ]]; then
  # shellcheck source=core/lib/ux.sh
  source "$REPO_ROOT/core/lib/ux.sh"
fi
say() { printf '%s::%s %s\n' "${UX_BLU:-}" "${UX_RST:-}" "$*"; }
ok() { printf '%s%s%s %s\n' "${UX_GRN:-}" "${UX_OK:-+}" "${UX_RST:-}" "$*"; }
warn() { printf '%s%s%s %s\n' "${UX_YEL:-}" "${UX_WARN:-!}" "${UX_RST:-}" "$*" >&2; }
die() { printf '%s%s%s %s\n' "${UX_RED:-}" "${UX_ERR:-x}" "${UX_RST:-}" "core-freshness: $*" >&2; exit 1; }

[[ -d "$REPO_ROOT/$PREFIX" ]] || { say "no $PREFIX/ vendored here — skipping."; exit 0; }
# Present-but-unlocked is a hard failure, not a skip: a vendored tree with no
# provenance is precisely the state this watcher exists to make impossible.
[[ -f "$LOCK" ]] || die "$PREFIX/ is vendored but $LOCK is missing."

lock_field() { sed -n -E "s/^$1=//p" "$LOCK" | head -n1; }
sha="$(lock_field core_sha)"
version="$(lock_field core_version)"
tag="$(lock_field core_tag)"
branch="${CORE_BRANCH:-$(lock_field core_branch)}"
[[ -n "$sha" ]] || die "core_sha missing/empty in $LOCK"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "core_sha is not a 40-hex commit: $sha"
[[ -n "$branch" ]] || branch=main

upstream="${CORE_UPSTREAM:-https://github.com/$DEFAULT_REPO.git}"
case "$branch" in
  refs/*) lsref="$branch" ;;
  *) lsref="refs/heads/$branch" ;;
esac

say "vendored $PREFIX at : $sha  (v${version:-?}, ${tag:-no tag})"
say "upstream           : $upstream $branch"

# --  end-of-options so a ref that looks like a flag can't be injected, and
# GIT_TERMINAL_PROMPT=0 so a private/renamed repo fails fast instead of hanging on a
# credential prompt. Same idiom as check-companion-freshness.sh.
tip="$(GIT_TERMINAL_PROMPT=0 git ls-remote -- "$upstream" "$lsref" 2>/dev/null | awk 'NR==1{print $1}')"
if [[ -z "$tip" ]]; then
  say "could not read $branch from $upstream — skipping (network/permissions)."
  exit 0
fi

say "upstream tip       : $tip"

if [[ "$tip" == "$sha" ]]; then
  ok "current — vendored $PREFIX matches $DEFAULT_REPO@$branch."
  exit 0
fi

warn "BEHIND — upstream $branch has moved past the vendored commit."
warn "  vendored : $sha"
warn "  upstream : $tip"
warn ""
warn "  Pull it, then re-run the gates:"
warn "    scripts/sync-core.sh     # or: make core-sync"
warn "    make lint && make test"
exit 2
