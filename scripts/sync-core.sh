#!/usr/bin/env bash
# scripts/sync-core.sh — pull the latest Core from upstream dotfiles-core and
# refresh core.lock. The consumer-side half of the vendoring contract.
# ──────────────────────────────────────────────────────────────────────────────
# core/ is a vendored `git subtree` of dotgibson/dotfiles-core (provenance in
# core.lock). Upstream is the source of truth. Until now this side had NO sync
# tool at all: the documented route was a hand-typed `git subtree pull` followed by
# hand-editing four fields in core.lock — and core.lock's own header points at
# `make core-lock`, a target that exists in NEITHER this repo nor core/Makefile.
# That is the gap this closes, and it is the direct twin of sync-companion.sh.
#
#   scripts/sync-core.sh                  # pull core_branch (main) from the lock's URL
#   scripts/sync-core.sh <remote-or-url>  # pull from a specific remote / URL / local clone
#   scripts/sync-core.sh --ref vX.Y.Z     # pull an EXACT tag instead of core_branch
#   scripts/sync-core.sh --check          # report whether upstream is ahead; touch nothing
#
# --ref exists for a REPRODUCIBLE pin to a released Core: a bare run always pulls
# core_branch's TIP, so asking for an old tag without --ref would silently vendor
# current main instead. Note the fleet's own release strategy prefers pinning a
# released tag (RELEASE-STRATEGY.md) — this repo currently tracks main's tip, which
# is why core.lock reads v4.9.3-56-g44a44fc rather than a clean v4.9.3.
#
# WHAT IT WRITES: all four core.lock fields, from what was actually pulled —
#   core_sha      the git-subtree-split trailer of the squash commit git just made
#   core_version  core/core.version at that tree
#   core_branch   the ref that was pulled
#   core_tag      `git describe` of core_sha, resolved against upstream
# It does NOT commit. Review the diff and commit core.lock together with the pull.
#
# Pre-reqs it enforces: a clean working tree (git subtree pull refuses otherwise)
# and a readable core.lock. The prefix (core) is fixed — it is where the subtree was
# added — not read from the lock.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PREFIX="core"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
LOCK="$REPO_ROOT/core.lock"
DEFAULT_REPO="dotgibson/dotfiles-core"
cd -- "$REPO_ROOT"

die() { echo "sync-core: $*" >&2; exit 1; }

CHECK=0
REMOTE_ARG=""
REF_OPT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK=1 ;;
    --ref)
      shift
      [[ $# -gt 0 ]] || die "--ref needs a value (a branch or tag)"
      case "$1" in -*) die "--ref needs a value, got another option: $1" ;; esac
      REF_OPT="$1" ;;
    --ref=*)
      REF_OPT="${1#--ref=}"
      [[ -n "$REF_OPT" ]] || die "--ref= needs a non-empty value (a branch or tag)" ;;
    -h | --help) sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) [[ -z "$REMOTE_ARG" ]] || die "only one remote/URL may be given"; REMOTE_ARG="$1" ;;
  esac
  shift
done

[[ -f "$LOCK" ]] || die "$LOCK not found — is the core subtree vendored?"
[[ -d "$REPO_ROOT/$PREFIX" ]] || die "$PREFIX/ not present — nothing to sync."

lock_field() { sed -n -E "s/^$1=//p" "$LOCK" | head -n1; }
branch="$(lock_field core_branch)"
old_sha="$(lock_field core_sha)"
[[ -n "$branch" ]] || die "core_branch missing from $LOCK"
# The rewrites below REPLACE existing lines rather than inserting, so a lock missing
# core_sha would let the pull succeed and leave the lock silently stale. Same guard
# sync-companion.sh carries, for the same reason.
[[ -n "$old_sha" ]] || die "core_sha missing/empty in $LOCK — add a 'core_sha=' line before syncing."

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

if ((CHECK)); then
  # DELEGATED to test/check-core-freshness.sh rather than re-implemented here.
  #
  # This block used to resolve the ref itself, with `refs/heads/<core_branch>` as the
  # default case — and core_branch is a pinned SHA after every fleet sync, so it
  # matched nothing. Two copies of the same wrong assumption is what made that bug
  # survive review, so there is now exactly one resolver and this calls it.
  #
  # Its contract: 0 current / 2 behind / 1 hard failure. Translate to this script's
  # voice and always exit 0 — --check is informational, and a "behind" result is the
  # expected answer most of the time, not an error.
  checker="$REPO_ROOT/test/check-core-freshness.sh"
  [[ -x "$checker" ]] || die "$checker not found — cannot run --check."
  rc=0
  CORE_UPSTREAM="$remote" CORE_BRANCH="${REF_OPT:-$branch}" "$checker" || rc=$?
  case "$rc" in
    0) echo "sync-core: up to date — nothing to pull." ;;
    2) echo "sync-core: upstream is AHEAD of the lock — run without --check to pull." ;;
    *) die "freshness check failed (exit $rc) — see above." ;;
  esac
  exit 0
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  die "working tree not clean — commit or stash first (git subtree pull needs a clean tree)."
fi

before="$(git rev-parse HEAD)"

# A subtree pull writes into core/, which the core-guard pre-commit hook refuses.
# That hook is exactly right for a hand-edit and exactly wrong here: this IS the
# sanctioned write. Same escape hatch sync-core.sh uses on the dotfiles-core side.
export DOTFILES_ALLOW_CORE_EDIT=1

echo "sync-core: git subtree pull --prefix=$PREFIX $remote $REF --squash"
git subtree pull --prefix="$PREFIX" "$remote" "$REF" --squash

after="$(git rev-parse HEAD)"
if [[ "$before" == "$after" ]]; then
  echo "sync-core: already up to date — no new commits, lock unchanged."
  exit 0
fi

# Read the new sha out of the squash commit's trailer — the SAME value the lock
# records. Do NOT recompute it: `git subtree split` synthesizes a different sha.
new_sha="$(git log --format='%b' "$before..$after" |
  sed -n -E 's/^[[:space:]]*git-subtree-split:[[:space:]]*([0-9a-f]+).*/\1/p' |
  head -n1)"
[[ -n "$new_sha" ]] || die "pulled new commits but found no git-subtree-split trailer — bump core_sha in $LOCK by hand."

# core_version comes from the tree we just vendored, so it can never disagree with
# what is on disk. core_tag needs upstream's tag objects, so it is best-effort: a
# shallow or tagless fetch just leaves the previous value rather than lying.
new_version="$(sed -n -E 's/^[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' "$REPO_ROOT/$PREFIX/core.version" 2>/dev/null | head -n1)"
[[ -n "$new_version" ]] || new_version="$(lock_field core_version)"

new_tag=""
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if git init --quiet --bare "$tmp/odb" &&
  GIT_TERMINAL_PROMPT=0 git -C "$tmp/odb" fetch --quiet --tags "$remote" "$REF" 2>/dev/null; then
  new_tag="$(git -C "$tmp/odb" describe --tags "$new_sha" 2>/dev/null || true)"
fi
[[ -n "$new_tag" ]] || new_tag="$(lock_field core_tag)"

set_field() { # set_field <key> <value> — replace in place, never insert
  local key="$1" val="$2" t
  t="$(mktemp)"
  awk -v k="$key" -v v="$val" '$0 ~ "^" k "=" { print k "=" v; next } { print }' "$LOCK" >"$t"
  mv -- "$t" "$LOCK"
}
set_field core_version "$new_version"
set_field core_sha "$new_sha"
set_field core_branch "$REF"
set_field core_tag "$new_tag"

echo "sync-core: core.lock  $old_sha -> $new_sha  (v$new_version, $new_tag)"
cat <<EOF

sync-core: pulled. Next:
  1. review the diff:   git diff $before -- $PREFIX
  2. re-run the gates:  make lint && make test
  3. commit core.lock together with the subtree pull.
EOF
