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
#
# Env:
#   COMPANION_PREFLIGHT=0    skip the companion marker pre-flight (see below). The
#                            escape hatch for tagging while dotfiles-Offense is
#                            unreachable; you then own fixing its markers by hand.
#   COMPANION_PREFLIGHT_URL  override the repo the pre-flight reads (default:
#                            dotfiles-Offense). Useful for a fork or a local test.
#
# The pre-flight (--push only, and only when a tag is really about to be cut) reads
# dotfiles-Offense's flat views and refuses to tag when a `companion:gen` marker there
# names an entry id this corpus no longer has. Without it that mismatch surfaces only
# AFTER the tag and Release are published, as a fan-out that quietly opens no PR.
# dotgibson/htpx#106.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

PUSH=0
RELEASE=0
# Companion pre-flight (see the block above `git tag -a`). On by default because the
# failure it prevents is silent and post-tag. COMPANION_PREFLIGHT=0 is the escape hatch
# for tagging while Offense is unreachable — it is deliberately an env var and not a
# flag, so it cannot be set absent-mindedly in a runbook one-liner.
PREFLIGHT="${COMPANION_PREFLIGHT:-1}"
PREFLIGHT_URL="${COMPANION_PREFLIGHT_URL:-https://github.com/dotgibson/dotfiles-Offense.git}"
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

# ── Companion marker pre-flight — the LAST gate before the tag exists ─────────
# Nothing in this repo can see dotfiles-Offense's `companion:gen` markers, and the
# fan-out that would notice runs AFTER this script. sync-fanout.yml re-vendors the
# corpus into Offense and runs its gen-views.sh BEFORE it commits; that script hard-
# fails on a marker naming an entry id that no longer exists. By then the tag and the
# GitHub Release are already published, and the sync simply never opens a PR — a
# release that looks clean here and silently did not fan out. See dotgibson/htpx#106,
# and #103 for the rename that made it concrete.
#
# So the check moves in front of the tag. Offense is PUBLIC and this is a read, so no
# token is involved — the cross-repo WRITE stays sync-fanout's job.
#
# Placement is deliberate: below the --push and idempotency guards, so a dry-run and a
# re-push of an already-tagged version never touch the network, and this only runs when
# a tag is genuinely about to be created.
#
# What blocks: gen-views exit 2, the STRUCTURAL failures (a marker naming a missing id,
# a duplicate id, a mismatched or unterminated marker region). Exit 1 is content DRIFT,
# which is normal and expected here — Offense's flat views legitimately lag until the
# fan-out PR merges, so blocking on it would block every release.
if ((PREFLIGHT)); then
  echo "auto-tag: companion marker pre-flight against $PREFLIGHT_URL"
  pf_dir="$(mktemp -d)"
  trap 'rm -rf "$pf_dir"' EXIT
  if ! git clone --depth 1 --quiet "$PREFLIGHT_URL" "$pf_dir/offense" 2>/dev/null; then
    echo "auto-tag: could not clone $PREFLIGHT_URL for the companion pre-flight." >&2
    echo "auto-tag: REFUSING to tag $tag — an unverifiable pre-flight is not a passing" >&2
    echo "auto-tag: one; a stale marker there aborts the fan-out after this tag is" >&2
    echo "auto-tag: published. Re-run when reachable, or set COMPANION_PREFLIGHT=0 to" >&2
    echo "auto-tag: tag anyway and fix Offense by hand." >&2
    exit 1
  fi
  # gen-views SKIPS a target that is not on disk and still exits 0, which is right for a
  # standalone checkout but would make this gate pass while checking nothing. Require the
  # flat views to actually be there.
  pf_targets=""
  pf_missing=0
  for t in PURPLE-TEAM.md offensive/hacktheplanet; do
    if [[ -f "$pf_dir/offense/$t" ]]; then
      pf_targets+="$pf_dir/offense/$t "
    else
      echo "auto-tag: $t is missing from $PREFLIGHT_URL — the companion contract moved." >&2
      pf_missing=1
    fi
  done
  if ((pf_missing)); then
    echo "auto-tag: REFUSING to tag $tag — cannot verify markers that are not there." >&2
    exit 1
  fi
  pf_rc=0
  COMPANION_TARGETS="$pf_targets" "$REPO_ROOT/gen-views.sh" --check || pf_rc=$?
  case "$pf_rc" in
    0) echo "auto-tag: pre-flight clean — every companion marker resolves." ;;
    1) echo "auto-tag: pre-flight OK — view drift only, which the fan-out PR carries." ;;
    2)
      echo "auto-tag: REFUSING to tag $tag — a companion:gen marker in dotfiles-Offense" >&2
      echo "auto-tag: names an entry id this corpus does not have (gen-views exit 2)." >&2
      echo "auto-tag: Tagging now would publish $tag and a GitHub Release, and THEN the" >&2
      echo "auto-tag: fan-out would abort without opening a sync PR." >&2
      echo "auto-tag: Fix: update the markers in dotfiles-Offense (same push as its" >&2
      echo "auto-tag: companion sync), then re-run this." >&2
      exit 1
      ;;
    *)
      echo "auto-tag: pre-flight gen-views exited $pf_rc, which is not a code it defines." >&2
      echo "auto-tag: REFUSING to tag $tag rather than guess what that means." >&2
      exit 1
      ;;
  esac
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
