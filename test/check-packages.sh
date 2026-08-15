#!/usr/bin/env bash
# test/check-packages.sh
# ──────────────────────────────────────────────────────────────────────────────
# Does every package name in install/*.txt still RESOLVE on Kali?
#
# bootstrap.sh's apt_install is deliberately forgiving: a bulk install that fails
# retries package-by-package and prints "skipped (unavailable on this box?)" for
# each casualty. That resilience is right for a live box — one dead name should not
# sink a 109-package install — but it means a typo, a Debian rename, or a dropped
# package is INVISIBLE. The run is still green, the operator still gets a shell, and
# the tool they were counting on simply is not there. Renames are not hypothetical
# here: install/offensive-packages.txt's own comments record freerdp2-x11 →
# freerdp3-x11 → freerdp-x11 across three years.
#
# This turns that into a gate. It resolves every name against the apt indices and
# reports the ones apt cannot see. It installs NOTHING.
#
# RUN IT WHERE THE ANSWER IS TRUE. Availability is a property of the apt sources on
# the box, so a `kali-last-snapshot` host and `kali-rolling` CI disagree by design.
# The authoritative run is the workflow (.github/workflows/packages.yml) inside a
# kali-rolling container; locally this is a smoke test against whatever you track,
# which is why an unresolvable name prints the suite it was checked against.
#
# Exit codes:
#   0  every name resolved (or a clean skip: no apt on this host)
#   1  usage/environment failure
#   2  one or more names did not resolve — the drift signal
#
# Usage:
#   test/check-packages.sh                 # both manifests
#   test/check-packages.sh install/packages.txt
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
# `set -e` is deliberately off here (the exit code IS the result), so guard the cd
# explicitly — continuing in the wrong directory would read the wrong manifests.
cd -- "$REPO_ROOT" || exit 1

if [[ -r "$REPO_ROOT/core/lib/ux.sh" ]]; then
  # shellcheck source=core/lib/ux.sh
  source "$REPO_ROOT/core/lib/ux.sh"
fi
say() { printf '%s::%s %s\n' "${UX_BLU:-}" "${UX_RST:-}" "$*"; }
ok() { printf '%s%s%s %s\n' "${UX_GRN:-}" "${UX_OK:-+}" "${UX_RST:-}" "$*"; }
bad() { printf '%s%s%s %s\n' "${UX_YEL:-}" "${UX_WARN:-!}" "${UX_RST:-}" "$*" >&2; }

command -v apt-cache >/dev/null 2>&1 || {
  say "no apt-cache on this host — skipping (run the packages workflow instead)."
  exit 0
}

# Reuse Core's parser rather than re-implementing the comment/whitespace rules:
# it is the SAME function bootstrap.sh feeds apt, so this checks exactly the names
# that would really be installed, including the inline-comment stripping.
# shellcheck source=core/lib/bootstrap-lib.sh
source "$REPO_ROOT/core/lib/bootstrap-lib.sh"

manifests=("$@")
((${#manifests[@]})) || manifests=(install/packages.txt install/offensive-packages.txt)

# Name the suite so a local run's answer is interpretable. `apt-cache policy`'s FIRST
# release line is the dpkg status pseudo-release (a=now), which is not a suite —
# skip it and take the first real archive.
suite="$(apt-cache policy 2>/dev/null |
  sed -n 's/.*[[:space:],]a=\([^,]*\).*/\1/p' | grep -v '^now$' | head -1)"
say "apt suite in view: ${suite:-unknown}"

total=0
missing=()
for m in "${manifests[@]}"; do
  [[ -f "$m" ]] || { bad "manifest not found: $m"; exit 1; }
  mapfile -t pkgs < <(blib_read_pkgs "$m")
  say "$m — ${#pkgs[@]} names"
  total=$((total + ${#pkgs[@]}))
  for p in "${pkgs[@]}"; do
    # `apt-cache show` succeeds for a real binary package. A virtual package (one
    # only ever provided by others) shows nothing but IS installable, so fall back to
    # policy's Candidate line before calling it missing.
    if apt-cache show "$p" >/dev/null 2>&1; then continue; fi
    if apt-cache policy "$p" 2>/dev/null | grep -q 'Candidate: [^(]'; then continue; fi
    missing+=("$m:$p")
  done
done

echo
if ((${#missing[@]} == 0)); then
  ok "all $total package names resolve against ${suite:-this suite}."
  exit 0
fi

bad "${#missing[@]} of $total package names do NOT resolve against ${suite:-this suite}:"
for e in "${missing[@]}"; do
  printf '    %-34s (%s)\n' "${e#*:}" "${e%%:*}" >&2
done
cat >&2 <<'EOF'

Each of these is one of:
  • a rename       — find the new name and update the manifest
  • a drop         — remove it, or move it to an UPSTREAM comment with install notes
  • a typo         — fix it
  • suite drift    — real on rolling, absent on the snapshot you happen to track
EOF
exit 2
