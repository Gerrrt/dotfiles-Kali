#!/usr/bin/env bash
# scripts/sync-core.sh — report how this repo's vendored core/ compares with upstream
# dotfiles-core. REPORT ONLY: it no longer pulls, and it never writes core.lock.
# ──────────────────────────────────────────────────────────────────────────────
# THE PULL IS RETIRED (dotfiles-core#676). This used to be the fleet's ONE sanctioned
# second writer into core/: a `git subtree pull --squash` that then stamped all four
# core.lock fields. VENDORING.md sanctioned it — unlike the three retired `make core-lock`
# generators — precisely because it wrote Core's format from WHAT IT ACTUALLY PULLED
# (core_sha from the squash commit's git-subtree-split trailer, core_version from the tree
# now on disk), so the lock could not describe a commit its own core/ did not contain.
#
# A filtered vendor removes exactly that property. Core stopped vendoring its whole tree:
# core/ is now `core.manifest` ∪ `core.vendor`, roughly two thirds of it. A subtree pull
# MERGES the whole upstream tree and has no way to apply that filter, so "what it actually
# pulled" is, by construction, no longer what a vendored core/ should contain. The first
# pull after this repo's lock moved to a filtering commit would land every upstream file
# against an expectation of the subset, and core-integrity would report TAMPERED —
# correctly, and with no hand-edit anywhere.
#
# Teaching it to filter was the other option and is worse: it would make this repo a second
# PRODUCER of Core's format, which is what the sanction was never extended to. Two
# implementations of one filter is the failure dotfiles-core#556 exists to prevent — a
# producer computing a different subset passes its own assertion and is reported TAMPERED
# by an unrelated command later. Upstream now has exactly one producer,
# core_vendor_materialize in scripts/lib/core-vendor.sh.
#
# WHAT REPLACES IT: the fan-out, like every other repo. A dotfiles-core release opens a
# core.lock-bump PR here automatically (sync-fanout.yml); merge it. In practice that is
# already how Core arrives — every one of the last ten core.lock writes in this repo came
# from the fan-out, not from this script.
#
#   scripts/sync-core.sh                  # report: is core/ behind upstream?
#   scripts/sync-core.sh --check          # same thing; kept so existing callers still work
#   scripts/sync-core.sh <remote-or-url>  # compare against a specific remote / URL / clone
#   scripts/sync-core.sh --ref vX.Y.Z     # compare against an EXACT tag instead of core_ref
#
# Exit: 0 = reported (whether current or behind). 2 = usage/precondition error. It never
# writes, so there is nothing to review and nothing to commit.
#
# The companion subtree is UNAFFECTED — scripts/sync-companion.sh still pulls, because htpx
# vendors its whole tree and has no allowlist. Do not "fix" that one to match this.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PREFIX="core"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
LOCK="$REPO_ROOT/core.lock"
DEFAULT_REPO="dotgibson/dotfiles-core"
cd -- "$REPO_ROOT"

die() { echo "sync-core: $*" >&2; exit 1; }

REMOTE_ARG=""
REF_OPT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    # Accepted and ignored: the pull is gone, so every run is what --check used to mean.
    # Kept rather than rejected because the Makefile, CONTRIBUTING.md and
    # check-core-freshness.sh's own nudge have all pointed at it.
    --check) ;;
    --ref)
      shift
      [[ $# -gt 0 ]] || die "--ref needs a value (a branch or tag)"
      case "$1" in -*) die "--ref needs a value, got another option: $1" ;; esac
      REF_OPT="$1" ;;
    --ref=*)
      REF_OPT="${1#--ref=}"
      [[ -n "$REF_OPT" ]] || die "--ref= needs a non-empty value (a branch or tag)" ;;
    # Terminated by the PATTERN, not a line number: this slice has now been wrong twice
    # (it printed code past the header, then went stale again when the header was rewritten
    # for the pull's retirement). `$d` drops the `set -euo` line the range ends on. Same
    # idiom dotfiles-core's core-integrity.sh uses, and for the same reason.
    -h | --help) sed -n '2,/^set -euo/p' "$0" | sed '$d;s/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) [[ -z "$REMOTE_ARG" ]] || die "only one remote/URL may be given"; REMOTE_ARG="$1" ;;
  esac
  shift
done

[[ -f "$LOCK" ]] || die "$LOCK not found — is the core subtree vendored?"
[[ -d "$REPO_ROOT/$PREFIX" ]] || die "$PREFIX/ not present — nothing to sync."

lock_field() { sed -n -E "s/^$1=//p" "$LOCK" | head -n1; }
branch="$(lock_field core_ref)"
[[ -n "$branch" ]] || die "core_ref missing/empty in $LOCK"
old_sha="$(lock_field core_sha)"
# Nothing below rewrites the lock any more (the pull is retired), so this guard is now
# purely about reporting: core_sha is what the freshness comparison and the "locked at"
# line are built from, and an empty one would report a drift verdict about nothing.
[[ -n "$old_sha" ]] || die "core_sha missing/empty in $LOCK — the lock is malformed; the fan-out writes it."

REF="${REF_OPT:-$branch}"

# Remote precedence: explicit arg → a git remote literally named dotfiles-core →
# the GitHub HTTPS URL. The arg lets you sync from a local clone without editing the lock.
if [[ -n "$REMOTE_ARG" ]]; then
  remote="$REMOTE_ARG"
elif git remote get-url "$DEFAULT_REPO" >/dev/null 2>&1; then
  remote="$DEFAULT_REPO"
else
  remote="https://github.com/$DEFAULT_REPO.git"
fi

echo "sync-core: prefix=$PREFIX  remote=$remote  ref=$REF"
echo "sync-core: locked at  $old_sha"

# ALWAYS the report, whether or not --check was passed. --check used to be the read-only
# mode and the bare run pulled; the pull is gone, so the two collapse. The flag is kept
# rather than rejected because test/check-core-freshness.sh's nudge, the Makefile and
# CONTRIBUTING.md have all pointed at it, and breaking those to make a point about an
# option name helps nobody.
#
# DELEGATED to test/check-core-freshness.sh rather than re-implemented here.
#
# This block used to resolve the ref itself, with `refs/heads/<core_ref>` as the
# default case — and core_ref is a pinned SHA after every fleet sync, so it
# matched nothing. Two copies of the same wrong assumption is what made that bug
# survive review, so there is now exactly one resolver and this calls it.
#
# Its contract: 0 current / 2 behind / 1 hard failure. Translate to this script's
# voice and always exit 0 — this is informational, and a "behind" result is the
# expected answer most of the time, not an error.
checker="$REPO_ROOT/test/check-core-freshness.sh"
[[ -x "$checker" ]] || die "$checker not found — cannot report freshness."
rc=0
CORE_UPSTREAM="$remote" CORE_BRANCH="${REF_OPT:-$branch}" "$checker" || rc=$?
case "$rc" in
  0) echo "sync-core: up to date — the vendored core/ matches upstream." ;;
  2) echo "sync-core: upstream is AHEAD of the lock." ;;
  *) die "freshness check failed (exit $rc) — see above." ;;
esac

# Say what to do about it, every time, including when up to date — someone reaching for
# this script is asking "how do I move Core?", and the answer changed.
cat <<EOF

sync-core: this script no longer pulls. Core arrives here by FAN-OUT:
  a dotfiles-core release opens a core.lock-bump PR in this repo automatically
  (sync-fanout.yml). Merge it, then: make lint && make test

  Why: a vendored core/ is a FILTERED subset of upstream since dotfiles-core#676
  (core.manifest + core.vendor). 'git subtree pull' merges the whole tree and cannot
  apply that filter, so pulling would land every upstream file against an expectation
  of the subset and core-integrity would report TAMPERED. See the header of this file.

  To pull anyway you would have to bypass this deliberately — don't. If the fan-out PR
  has not arrived, the fix is upstream (dotfiles-core: make sync), not here.
EOF
exit 0
