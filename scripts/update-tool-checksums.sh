#!/usr/bin/env bash
# scripts/update-tool-checksums.sh
# ──────────────────────────────────────────────────────────────────────────────
# Recompute the pinned SHA-256 of every release ASSET bootstrap.sh downloads, and
# write it back into install/tool-versions.env. Run this AFTER bumping a *_VERSION
# there: bootstrap.sh's verified_install checks each download against its *_SHA256
# and FAILS CLOSED on a mismatch — so a version bump is only complete once its
# checksum is refreshed.
#
# Deliberately the consumer-side twin of core/scripts/update-tool-checksums.sh:
# same shape, same contract, same "review the diff before committing" discipline.
# It downloads the exact asset URL bootstrap.sh uses (Linux x86_64), hashes it,
# and rewrites the matching KEY= line in place.
#
# CROSS-CHECK before committing. This file is the trust anchor for everything
# bootstrap installs out of band, and hashing whatever the CDN served you only
# proves the download was self-consistent. Where upstream publishes a checksum
# sidecar, --verify fetches it and asserts the two agree:
#
#   scripts/update-tool-checksums.sh              # refresh the pins
#   scripts/update-tool-checksums.sh --verify     # refresh + assert vs upstream sidecars
#   scripts/update-tool-checksums.sh --check      # report drift only, write nothing
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/install/tool-versions.env"

die() { echo "update-tool-checksums: $*" >&2; exit 1; }

VERIFY=0 CHECK=0
while [[ $# -gt 0 ]]; do case "$1" in
  --verify) VERIFY=1 ;;
  --check) CHECK=1 ;;
  -h | --help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "unknown option: $1" ;;
esac; shift; done

[[ -r "$ENV_FILE" ]] || die "$ENV_FILE not found"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Read a KEY=value (first match) without sourcing the file.
ver() { sed -n "s/^$1=//p" "$ENV_FILE" | head -n1; }

# Replace KEY=... in place, or append when the key isn't present yet.
set_key() {
  local key="$1" val="$2"
  if grep -qE "^${key}=" "$ENV_FILE"; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
    rm -f "$ENV_FILE.bak"
  else
    printf '%s=%s\n' "$key" "$val" >>"$ENV_FILE"
  fi
}

sha_of() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  else
    shasum -a 256 "$file" | cut -d' ' -f1
  fi
}

# <env-prefix>|<asset URL>|<upstream sidecar URL, or empty when none is published>
# Keep this list in lockstep with the OUT_OF_BAND asset URLs in bootstrap.sh.
assets=(
  "ATUIN|https://github.com/atuinsh/atuin/releases/download/v$(ver ATUIN_VERSION)/atuin-x86_64-unknown-linux-gnu.tar.gz|"
  "MISE|https://github.com/jdx/mise/releases/download/v$(ver MISE_VERSION)/mise-v$(ver MISE_VERSION)-linux-x64.tar.gz|"
  "UV|https://github.com/astral-sh/uv/releases/download/$(ver UV_VERSION)/uv-x86_64-unknown-linux-gnu.tar.gz|https://github.com/astral-sh/uv/releases/download/$(ver UV_VERSION)/uv-x86_64-unknown-linux-gnu.tar.gz.sha256"
  "TY|https://github.com/astral-sh/ty/releases/download/$(ver TY_VERSION)/ty-x86_64-unknown-linux-gnu.tar.gz|https://github.com/astral-sh/ty/releases/download/$(ver TY_VERSION)/ty-x86_64-unknown-linux-gnu.tar.gz.sha256"
)

rc=0
for entry in "${assets[@]}"; do
  IFS='|' read -r key url sidecar <<<"$entry"
  printf '%-6s %s\n' "$key" "$url"

  curl -fsSL -o "$tmp/asset" "$url" || { echo "   DOWNLOAD FAILED" >&2; rc=1; continue; }
  got="$(sha_of "$tmp/asset")"

  if ((VERIFY)) && [[ -n "$sidecar" ]]; then
    up="$(curl -fsSL "$sidecar" 2>/dev/null | tr -s ' ' | cut -d' ' -f1)"
    if [[ -z "$up" ]]; then
      echo "   sidecar unavailable — could not cross-check" >&2
    elif [[ "$up" != "$got" ]]; then
      echo "   MISMATCH vs upstream sidecar: $up" >&2
      rc=1
      continue
    else
      echo "   cross-checked against upstream sidecar ✓"
    fi
  fi

  old="$(ver "${key}_SHA256")"
  if [[ "$old" == "$got" ]]; then
    echo "   unchanged  $got"
  elif ((CHECK)); then
    echo "   DRIFT      recorded=$old actual=$got" >&2
    rc=1
  else
    set_key "${key}_SHA256" "$got"
    echo "   updated    $got"
  fi
done

((CHECK)) && { ((rc == 0)) && echo "all pins current."; exit "$rc"; }
((rc == 0)) || die "one or more assets could not be pinned — see above."
echo
echo "Pins refreshed in install/tool-versions.env — review the diff before committing."
