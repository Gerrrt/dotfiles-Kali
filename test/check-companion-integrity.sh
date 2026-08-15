#!/usr/bin/env bash
# test/check-companion-integrity.sh
# ──────────────────────────────────────────────────────────────────────────────
# COMPANION INTEGRITY — is the vendored offensive/companion/ PRISTINE, or was it
# hand-edited?
#
# This repo carries TWO vendored subtrees, and until now only one of them was
# guarded. `core/` has core-integrity.yml (the reusable tree-SHA check from
# dotfiles-core); `offensive/companion/` had freshness (is it behind upstream?) and
# view-drift (do the generated blocks match the entries?) but NOTHING asserting the
# vendored tree still equals what companion.lock claims. A hand-edit there is the
# same silent drift the core-guard exists to prevent: it works until the next
# `scripts/sync-companion.sh` clobbers it, and never reaches htpx.
#
# HOW — the same content-addressed trick core-integrity.sh uses, and for the same
# reason: a vendored subtree is a copy of upstream's WHOLE tree at one commit, so
# the git tree object of `HEAD:offensive/companion` here must byte-equal
# `<companion_sha>^{tree}` in htpx. Edit any vendored file and the hash diverges.
# One rev-parse each side, O(1), no file walk.
#
# REPORTER, not mutator — it never writes to either repo.
#
# Exit codes (mirroring test/check-companion-freshness.sh's contract):
#   0  pristine, or skipped (no vendored tree / upstream unreachable)
#   1  hard failure (malformed lock, or the upstream fetch failed outright)
#   2  TAMPERED — the vendored tree no longer matches its recorded commit
#
# Usage:
#   test/check-companion-integrity.sh
#   COMPANION_UPSTREAM=/path/to/local/htpx test/check-companion-integrity.sh
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PREFIX="offensive/companion"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
LOCK="$REPO_ROOT/companion.lock"
cd -- "$REPO_ROOT"

# Core's bash UX palette when it's vendored (it is), plain text otherwise — same
# degradation as check-companion-freshness.sh so the two read alike in a job log.
if [[ -r "$REPO_ROOT/core/lib/ux.sh" ]]; then
  # shellcheck source=core/lib/ux.sh
  source "$REPO_ROOT/core/lib/ux.sh"
fi
say() { printf '%s::%s %s\n' "${UX_BLU:-}" "${UX_RST:-}" "$*"; }
ok() { printf '%s%s%s %s\n' "${UX_GRN:-}" "${UX_OK:-+}" "${UX_RST:-}" "$*"; }
bad() { printf '%s%s%s %s\n' "${UX_RED:-}" "${UX_ERR:-x}" "${UX_RST:-}" "$*" >&2; }
die() { bad "companion-integrity: $*"; exit 1; }

[[ -d "$REPO_ROOT/$PREFIX" ]] || { say "no $PREFIX/ vendored here — skipping."; exit 0; }
[[ -f "$LOCK" ]] || die "$PREFIX/ is vendored but $LOCK is missing — cannot verify."

lock_field() { sed -n -E "s/^$1=//p" "$LOCK" | head -n1; }
repo="$(lock_field companion_repo)"
sha="$(lock_field companion_sha)"
[[ -n "$repo" ]] || die "companion_repo missing from $LOCK"
[[ -n "$sha" ]] || die "companion_sha missing from $LOCK"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "companion_sha is not a 40-hex commit: $sha"

# The vendored tree object. Present in any checkout, including a depth-1 clone —
# this reads the COMMITTED tree, so an uncommitted local edit is invisible here by
# design (that is the pre-commit guard's job, not CI's).
vendored="$(git rev-parse --verify --quiet "HEAD:$PREFIX" 2>/dev/null)" ||
  die "could not read HEAD:$PREFIX"

say "vendored $PREFIX tree : $vendored"
say "companion.lock pins   : $sha ($repo)"

# We need htpx's object database to resolve <sha>^{tree}. Fetch just that commit
# into a throwaway store rather than cloning the whole repo.
upstream="${COMPANION_UPSTREAM:-https://github.com/$repo.git}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git init --quiet --bare "$tmp/odb"
if ! GIT_TERMINAL_PROMPT=0 git -C "$tmp/odb" fetch --quiet --depth=1 "$upstream" "$sha" 2>/dev/null; then
  # A server that refuses to serve an arbitrary sha (uploadpack.allowReachableSHA1InWant
  # off) is a capability gap, not a tamper signal — fall back to a full fetch before
  # giving up, and SKIP rather than fail if even that can't reach upstream.
  if ! GIT_TERMINAL_PROMPT=0 git -C "$tmp/odb" fetch --quiet "$upstream" '+refs/heads/*:refs/heads/*' 2>/dev/null; then
    say "could not fetch $upstream — skipping (network/permissions, not a tamper signal)."
    exit 0
  fi
fi

expected="$(git -C "$tmp/odb" rev-parse --verify --quiet "${sha}^{tree}" 2>/dev/null)" || {
  bad "UNVERIFIABLE — $sha is not in $repo's history (rewritten or phantom sha)."
  exit 2
}

if [[ "$vendored" == "$expected" ]]; then
  ok "pristine — $PREFIX matches $repo@${sha:0:12}"
  exit 0
fi

bad "TAMPERED — $PREFIX has been edited since it was vendored."
bad "  vendored tree : $vendored"
bad "  expected tree : $expected  (from $repo@${sha:0:12})"
bad ""
bad "  offensive/companion/ is a git-subtree copy of $repo and is OVERWRITTEN on the"
bad "  next scripts/sync-companion.sh. Fix it upstream in htpx, then re-sync."
exit 2
