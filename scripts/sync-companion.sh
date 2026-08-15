#!/usr/bin/env bash
# scripts/sync-companion.sh — pull the latest companion from upstream htpx and
# refresh companion.lock. The consumer-side half of the vendoring contract.
# ──────────────────────────────────────────────────────────────────────────────
# offensive/companion/ is a vendored `git subtree` of dotgibson/htpx (provenance in
# companion.lock). Upstream is the source of truth; this is the one command that
# re-pulls htpx `main` into the prefix AND records the new git-subtree-split sha in
# companion.lock, so the lock can never drift from what's actually vendored. It is
# the convenience wrapper the lock's own header points at — nothing it does is
# magic, just the documented `git subtree pull --squash` + the sha bump in one step.
#
#   scripts/sync-companion.sh                  # pull companion_branch (main) from the lock's URL
#   scripts/sync-companion.sh <remote-or-url>  # pull from a specific remote / URL / local clone
#   scripts/sync-companion.sh --ref vX.Y.Z     # pull an EXACT tag/branch instead of companion_branch
#   scripts/sync-companion.sh --check          # report whether upstream is ahead; touch nothing
#
# --ref exists for a REPRODUCIBLE backfill of a specific htpx release: `git subtree pull`
# (and --check's `git ls-remote`) resolve a tag or branch NAME, so pass a release tag —
# NOT a raw commit sha (ls-remote lists refs, it can't look up a bare sha). A bare run
# always pulls companion_branch's TIP, so backfilling an OLD release tag would silently
# vendor CURRENT main instead of that tag's tree. htpx's sync-fanout workflow passes the
# released tag via --ref so the fan-out is exact (G10).
#
# A bare run leaves you with TWO things to do before it's a finished change:
#   1. eyeball the diff under offensive/companion/, and
#   2. run offensive/companion/gen-views.sh --check — an upstream content change can
#      shift the generated blocks in hacktheplanet / PURPLE-TEAM.md, which this
#      script does NOT touch (that's gen-views.sh's job). Fix + commit both together.
#
# Pre-reqs the script enforces: a clean working tree (git subtree pull refuses to
# run otherwise) and a companion.lock it can read the repo/branch from. The prefix
# (offensive/companion) is fixed — it's where the subtree was added — not read from
# the lock.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PREFIX="offensive/companion"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
LOCK="$REPO_ROOT/companion.lock"
cd -- "$REPO_ROOT"

die() { echo "sync-companion: $*" >&2; exit 1; }

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
    -*) die "unknown option: $1" ;;
    *) [[ -z "$REMOTE_ARG" ]] || die "only one remote/URL may be given"; REMOTE_ARG="$1" ;;
  esac
  shift
done

[[ -f "$LOCK" ]] || die "$LOCK not found — is the companion subtree vendored?"

# Pull the provenance out of the lock (the same fields gen-views/CI rely on).
lock_field() { sed -n -E "s/^$1=//p" "$LOCK" | head -n1; }
repo="$(lock_field companion_repo)"
branch="$(lock_field companion_branch)"
old_sha="$(lock_field companion_sha)"
[[ -n "$repo" ]]   || die "companion_repo missing from $LOCK"
[[ -n "$branch" ]] || die "companion_branch missing from $LOCK"
# The sha rewrite below REPLACES an existing companion_sha= line (awk) — it does not
# insert one. So a lock with no companion_sha would let the pull succeed yet leave
# the lock silently unchanged. Require the line up front so that can't happen.
[[ -n "$old_sha" ]] || die "companion_sha missing/empty in $LOCK — add a 'companion_sha=' line before syncing."

# The ref to pull: an explicit --ref (a release tag, for a reproducible backfill of an
# EXACT htpx version) wins over companion_branch (the default rolling `main`). git subtree
# and ls-remote resolve a tag/branch NAME; passing a tag is what lets an OLD-tag fan-out
# vendor THAT tag's tree instead of main's tip (G10).
REF="${REF_OPT:-$branch}"

# Remote precedence: explicit arg → a git remote literally named in the lock →
# the GitHub HTTPS URL derived from companion_repo. The arg lets you sync from a
# fork, an ssh remote, or a local htpx clone without editing the lock.
if [[ -n "$REMOTE_ARG" ]]; then
  remote="$REMOTE_ARG"
elif git remote get-url "$repo" >/dev/null 2>&1; then
  remote="$repo"
else
  remote="https://github.com/$repo.git"
fi

echo "sync-companion: prefix=$PREFIX  remote=$remote  ref=$REF"
echo "sync-companion: locked at  $old_sha"

# --check: peek at upstream without mutating the tree or the lock. Fetch the tip
# and compare; report ahead / up-to-date. Exit 0 either way (informational) unless
# the fetch itself fails.
if [[ "$CHECK" == 1 ]]; then
  # Resolve the ls-remote pattern. For the DEFAULT branch, anchor to refs/heads/<branch>
  # so a same-named tag can't match (a bare name is a ref PATTERN). For an explicit --ref
  # (which may be a tag OR a branch), ls-remote it bare — matches refs/tags/<ref> or
  # refs/heads/<ref>; we only report ahead/current, so either is fine. GIT_TERMINAL_PROMPT=0
  # so it never blocks on a credential prompt — same idiom as test/check-core-freshness.sh.
  if [[ -n "$REF_OPT" ]]; then
    lsref="$REF"
  else
    case "$branch" in
      refs/*) lsref="$branch" ;;
      *) lsref="refs/heads/$branch" ;;
    esac
  fi
  upstream_sha="$(GIT_TERMINAL_PROMPT=0 git ls-remote "$remote" "$lsref" 2>/dev/null | awk 'NR==1{print $1}')"
  [[ -n "$upstream_sha" ]] || die "could not read $REF from $remote"
  echo "sync-companion: upstream ${REF} tip is $upstream_sha"
  if [[ "$upstream_sha" == "$old_sha" ]]; then
    echo "sync-companion: up to date — nothing to pull."
  else
    echo "sync-companion: upstream is AHEAD of the lock — run without --check to pull."
  fi
  exit 0
fi

# A subtree pull rewrites tracked files and makes a merge commit, so the tree must
# be clean first — fail early with a clear message rather than letting git do it.
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "working tree not clean — commit or stash first (git subtree pull needs a clean tree)."
fi

before="$(git rev-parse HEAD)"

echo "sync-companion: git subtree pull --prefix=$PREFIX $remote $REF --squash"
git subtree pull --prefix="$PREFIX" "$remote" "$REF" --squash

after="$(git rev-parse HEAD)"
if [[ "$before" == "$after" ]]; then
  echo "sync-companion: already up to date — no new commits, lock unchanged."
  exit 0
fi

# Pull the new split sha from the squash commit's `git-subtree-split:` trailer —
# the SAME value the lock records, read straight back out of the commit git just
# wrote (don't recompute it; `git subtree split` would synthesize a different sha).
new_sha="$(git log --format='%b' "$before..$after" \
            | sed -n -E 's/^[[:space:]]*git-subtree-split:[[:space:]]*([0-9a-f]+).*/\1/p' \
            | head -n1)"
[[ -n "$new_sha" ]] || die "pulled new commits but found no git-subtree-split trailer — bump companion_sha in $LOCK by hand."

# companion_version comes from the tree we just vendored, so it can never disagree
# with what is on disk. companion_tag needs upstream's tag objects, so it is
# best-effort: a tagless fetch leaves the previous value rather than lying.
new_version="$(sed -n -E 's/^##[[:space:]]*\[?v?([0-9]+\.[0-9]+\.[0-9]+)\]?.*/\1/p' \
  "$REPO_ROOT/$PREFIX/CHANGELOG.md" 2>/dev/null | head -n1)"
[[ -n "$new_version" ]] || new_version="$(lock_field companion_version)"

new_tag=""
tagtmp="$(mktemp -d)"
trap 'rm -rf "$tagtmp"' EXIT
if git init --quiet --bare "$tagtmp/odb" &&
  GIT_TERMINAL_PROMPT=0 git -C "$tagtmp/odb" fetch --quiet --tags "$remote" "$REF" 2>/dev/null; then
  new_tag="$(git -C "$tagtmp/odb" describe --tags "$new_sha" 2>/dev/null || true)"
fi
[[ -n "$new_tag" ]] || new_tag="$(lock_field companion_tag)"

# Rewrite only the recorded fields; leave the header + repo/branch untouched. These
# REPLACE existing lines rather than inserting, which is why the guard above requires
# companion_sha to be present before the pull starts.
set_field() { # set_field <key> <value>
  local key="$1" val="$2" t
  t="$(mktemp)"
  awk -v k="$key" -v v="$val" '$0 ~ "^" k "=" { print k "=" v; next } { print }' "$LOCK" >"$t"
  mv -- "$t" "$LOCK"
}
set_field companion_sha "$new_sha"
set_field companion_version "$new_version"
set_field companion_tag "$new_tag"

echo "sync-companion: companion.lock  $old_sha -> $new_sha  (v$new_version, $new_tag)"
cat <<EOF

sync-companion: pulled. Next:
  1. review the diff:   git diff $before -- $PREFIX
  2. drift-check views: offensive/companion/gen-views.sh --check
     (regenerate + commit if it reports drift: offensive/companion/gen-views.sh)
  3. commit companion.lock together with the subtree pull.
EOF
