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

say "vendored $PREFIX at : $sha  (v${version:-?}, ${tag:-no tag})"

# ── what does core_branch actually hold? ──────────────────────────────────────
# NOT always a branch name, despite the field name. Three shapes occur in practice:
#
#   a 40-hex SHA  — the NORMAL state after a fleet sync. sync-fanout.yml pins each
#                   PR to the exact released commit (CORE_BRANCH=<sha>) so core.lock
#                   records a frozen version rather than "whatever main was".
#   a tag         — `scripts/sync-core.sh --ref v4.11.0` records the ref it pulled.
#   a branch name — a plain `sync-core.sh` run tracking main's tip.
#
# The first version of this script assumed the third and built `refs/heads/<value>`
# unconditionally. Against a pinned SHA that matches nothing, ls-remote came back
# empty, and the empty result was treated as "upstream unreachable → skip, exit 0".
# So the watcher reported success while checking nothing — in the state it is in
# most of the time. Resolve all three shapes, and never let "no such ref" masquerade
# as "no network".
GLR() { GIT_TERMINAL_PROMPT=0 git ls-remote "$@" 2>/dev/null; }

# Connectivity probe FIRST, so a genuine network/permissions failure is
# distinguishable from a ref that legitimately does not exist upstream.
if ! GLR --exit-code -- "$upstream" HEAD >/dev/null; then
  say "could not reach $upstream — skipping (network/permissions)."
  exit 0
fi

if [[ "$branch" =~ ^[0-9a-f]{40}$ ]]; then
  # PINNED to a released commit. "Behind" is not about a branch tip at all — the
  # question is whether a NEWER RELEASE exists, which is what the fleet vendors.
  mode="pinned to a released commit"
  newest_tag="$(GLR --tags --refs -- "$upstream" 'v*' |
    sed -n 's#.*refs/tags/##p' | sort -V | tail -n1)"
  if [[ -n "$newest_tag" ]]; then
    # Peel the annotated tag to its commit (^{}); fall back to the raw object for a
    # lightweight tag, which has no peeled line.
    cmp_sha="$(GLR --tags -- "$upstream" "refs/tags/$newest_tag^{}" | awk 'NR==1{print $1}')"
    [[ -n "$cmp_sha" ]] || cmp_sha="$(GLR --tags -- "$upstream" "refs/tags/$newest_tag" | awk 'NR==1{print $1}')"
    cmp_name="$newest_tag"
  else
    # No release tags at all — fall back to the default branch tip.
    cmp_sha="$(GLR -- "$upstream" HEAD | awk 'NR==1{print $1}')"
    cmp_name="HEAD (no v* tags found)"
  fi
else
  # A NAME: try a branch, then a tag. A name that resolves to neither means the lock
  # points at something that no longer exists upstream — a hard failure, not a skip.
  mode="tracking $branch"
  cmp_sha="$(GLR -- "$upstream" "refs/heads/$branch" | awk 'NR==1{print $1}')"
  cmp_name="$branch"
  if [[ -z "$cmp_sha" ]]; then
    cmp_sha="$(GLR --tags -- "$upstream" "refs/tags/$branch^{}" | awk 'NR==1{print $1}')"
    [[ -n "$cmp_sha" ]] || cmp_sha="$(GLR --tags -- "$upstream" "refs/tags/$branch" | awk 'NR==1{print $1}')"
  fi
  [[ -n "$cmp_sha" ]] || die "core_branch '$branch' resolves to no branch OR tag in $upstream — core.lock points at something that does not exist."
fi

say "upstream           : $upstream ($mode)"
say "compared against   : $cmp_name = ${cmp_sha:-<unresolved>}"

[[ -n "$cmp_sha" ]] || die "could not resolve $cmp_name in $upstream despite reaching it."

if [[ "$cmp_sha" == "$sha" ]]; then
  ok "current — vendored $PREFIX matches $DEFAULT_REPO@$cmp_name."
  exit 0
fi

warn "BEHIND — $DEFAULT_REPO@$cmp_name is not what is vendored here."
warn "  vendored : $sha  (${tag:-no tag})"
warn "  upstream : $cmp_sha  ($cmp_name)"
warn ""
warn "  Pull it, then re-run the gates:"
warn "    scripts/sync-core.sh     # or: make core-sync"
warn "    make lint && make test"
warn "  If a core.lock-bump PR from the fleet sync is already open, merge that instead."
exit 2
