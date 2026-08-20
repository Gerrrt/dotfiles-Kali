#!/usr/bin/env bash
# scripts/auto-tag.sh — cut htpx's next release tag from the top CHANGELOG version.
# ──────────────────────────────────────────────────────────────────────────────
# htpx is the SOURCE OF TRUTH for the red<->blue paired corpus; dotfiles-Offense
# vendors it at offensive/companion/ via git subtree. A release here is the trigger
# for the fan-out (sync-fanout.yml) that re-syncs that subtree into Offense.
#
# CHANGELOG.md is the version source: the FIRST `## [vX.Y.Z]` heading is the
# intended current release. When no `vX.Y.Z` git tag matches that version yet, this
# script creates the annotated tag and (with --release) publishes a GitHub Release
# whose body is the CHANGELOG section for that version. It is a NO-OP when the tag
# already exists — pushing main again never double-tags or re-releases.
#
# Robustness (learned from dotfiles-core/scripts/auto-tag.sh's fragility notes):
#   - detect the top version with `grep -m1 | grep -oE` (stops at the first heading,
#     no `| head` under pipefail — the SIGPIPE on early close races the pipe status
#     and can mask a real error); the Release BODY is then carved with a single awk
#     pass over the same file;
#   - `gh release create --verify-tag` so a Release is never cut against a tag that
#     isn't actually on origin;
#   - an existing Release is an idempotent no-op, but a real `create` failure exits
#     non-zero (fail loud — never green-with-no-Release);
#   - --release with gh missing is a HARD FAILURE (never green-with-no-Release): on a
#     GitHub runner gh is always present, so its absence is a real misconfiguration.
#
# Usage:
#   ./scripts/auto-tag.sh                 # print the version + whether it's new; touch nothing
#   ./scripts/auto-tag.sh --push          # create + push the tag if it's new
#   ./scripts/auto-tag.sh --push --release # …and publish a GitHub Release from the CHANGELOG
#
# Flags:
#   --push       create the annotated tag and push it to origin (default: print only)
#   --release    also publish a GitHub Release (needs --push and gh + GH_TOKEN)
#   -h, --help   show this help and exit
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

PUSH=0
RELEASE=0
usage() {
  cat <<'EOF'
usage: auto-tag.sh [--push] [--release]

Cut htpx's next release tag from the top vX.Y.Z heading in CHANGELOG.md. No-op when
that tag already exists. Without --push it only prints whether the version is new.

  --push       create the annotated tag and push it to origin (default: print only)
  --release    also publish a GitHub Release from the CHANGELOG (needs --push + gh)
  -h, --help   show this help and exit
EOF
}
while (($#)); do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --push) PUSH=1 ;;
    --release) RELEASE=1 ;;
    *) echo "auto-tag: unknown option '$1'" >&2; exit 2 ;;
  esac
  shift
done
# A Release needs the tag on origin — releasing implies pushing.
if ((RELEASE && !PUSH)); then
  echo "auto-tag: --release requires --push (cannot release a tag that isn't pushed)" >&2
  exit 2
fi

[[ -f "$CHANGELOG" ]] || { echo "auto-tag: $CHANGELOG not found" >&2; exit 1; }

# Top version = the FIRST `## [vX.Y.Z]` / `## [X.Y.Z]` heading in the CHANGELOG.
# grep -m1 stops at the first match (no `| head` to race pipefail); grep -oE extracts
# just the digits. Portable (no gawk-only match() capture array — the runner's awk may
# be mawk). An [Unreleased] heading carries no digits, so it yields nothing.
version="$(grep -m1 -oE '^##[[:space:]]+\[v?[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" \
            | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"

# Conservative SemVer parse: bail cleanly if the top heading is [Unreleased] or junk
# (a maintainer hasn't promoted a version yet — nothing to tag, and that's fine).
if [[ -z "$version" ]] || ! printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "auto-tag: no concrete vX.Y.Z heading at the top of the CHANGELOG — nothing to tag"
  exit 0
fi
tag="v$version"
echo "auto-tag: top CHANGELOG version is $tag"

# Idempotency: if the tag already exists (locally or fetched), this run is a no-op.
if git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
  echo "auto-tag: tag $tag already exists — nothing to do"
  exit 0
fi

if ((!PUSH)); then
  echo "auto-tag: $tag is NEW (dry-run; pass --push to cut it)"
  exit 0
fi

# Annotated tag (carries tagger/date; gh --verify-tag + git describe expect it). A CI
# tagger identity so the object is well-formed when no user.* is configured.
git -C "$REPO_ROOT" config user.name "${GIT_AUTHOR_NAME:-htpx auto-tag}"
git -C "$REPO_ROOT" config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
if ! git -C "$REPO_ROOT" tag -a "$tag" -m "$tag"; then
  echo "auto-tag: 'git tag -a $tag' failed" >&2
  exit 1
fi
if ! git -C "$REPO_ROOT" push origin "$tag"; then
  echo "auto-tag: push failed — re-push manually: git push origin $tag" >&2
  exit 1
fi
echo "auto-tag: tagged + pushed $tag"

((RELEASE)) || { echo "auto-tag: --release not requested — tag stands"; exit 0; }

if ! command -v gh >/dev/null 2>&1; then
  echo "auto-tag: --release requested but gh is not installed — tag $tag is pushed," >&2
  echo "auto-tag: but no Release was created. Install gh + set GH_TOKEN, or re-run" >&2
  echo "auto-tag: without --release. Failing loud (never green-with-no-Release)." >&2
  exit 1
fi

# Release body = the CHANGELOG block under '## [vX.Y.Z]' up to the next '## [' heading,
# heading dropped and leading/trailing blanks trimmed. Single awk pass; the version is
# anchored to avoid matching a longer version that shares a prefix.
body="$(mktemp)"
awk -v ver="$version" '
  $0 ~ "^##[[:space:]]+\\[v?" ver "\\]" { f = 1; next }
  f && /^##[[:space:]]+\[/ { exit }
  f && NF { p = 1 }
  f && p { buf[++n] = $0 }
  END { while (n > 0 && buf[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print buf[i] }
' "$CHANGELOG" >"$body"
[[ -s "$body" ]] || printf 'Release %s\n' "$tag" >"$body"

if (cd "$REPO_ROOT" && gh release view "$tag" >/dev/null 2>&1); then
  echo "auto-tag: GitHub Release $tag already exists — nothing to do"
elif (cd "$REPO_ROOT" && gh release create "$tag" --verify-tag --title "$tag" --notes-file "$body"); then
  echo "auto-tag: published GitHub Release $tag"
else
  echo "auto-tag: 'gh release create $tag' failed (tag is pushed; create the Release manually)" >&2
  rm -f "$body"
  exit 1
fi
rm -f "$body"
