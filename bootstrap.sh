#!/usr/bin/env bash
# dotfiles-Kali/bootstrap.sh
# Provision a Kali (Debian-family, apt) box — built for WSL2 — and wire dotfiles.
# Idempotent. Stacks three layers: vendored Core + apt OS-native + OFFENSIVE role.
# The shared symlink/loader/login-shell scaffold lives in core/lib/bootstrap-lib.sh.
#
# >>>USAGE
#   ./bootstrap.sh                 # full: apt base + offensive tools + symlinks
#   ./bootstrap.sh --dry-run       # print the whole plan, change nothing
#   ./bootstrap.sh --links-only    # just (re)create symlinks (no apt)
#   ./bootstrap.sh --no-offensive  # base + symlinks, skip the heavy tool install
#   ./bootstrap.sh --no-upgrade    # skip the apt full-upgrade (still installs)
#   ./bootstrap.sh --only zsh,nvim # link ONLY these Core module groups
#   ./bootstrap.sh --skip tmux     # link everything EXCEPT these groups
#
# Module groups (for --only/--skip): zsh nvim tmux git prompt tools — Core wiring
# only; the offensive role layer is separate (governed by --no-offensive).
# <<<USAGE
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
LINKS_ONLY=0
DO_OFFENSIVE=1
DO_UPGRADE=1
DRY=0
# --only/--skip are validated by the shared lib (blib_select), sourced AFTER this
# loop — capture the raw values now and apply them below.
ONLY_RAW="" SKIP_RAW="" ONLY_SEEN=0 SKIP_SEEN=0

# Print the usage block above, between its markers. Extracted by MARKER, not by a
# line range: the old `sed -n '2,14p'` silently truncated (or leaked) the moment
# anything was added to the header, which is exactly what happened when the flag
# list grew. Strips the leading '# ' so the output reads as help, not as source.
usage() { sed -n '/^# >>>USAGE$/,/^# <<<USAGE$/p' "$0" | sed '1d;$d;s/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do case "$1" in
  --links-only) LINKS_ONLY=1 ;;
  --no-offensive) DO_OFFENSIVE=0 ;;
  --no-upgrade) DO_UPGRADE=0 ;;
  --dry-run | -n) DRY=1 ;;
  --only) [[ $# -ge 2 ]] || { echo "--only requires module names, e.g. --only zsh,nvim" >&2; exit 1; }; ONLY_RAW="$2"; ONLY_SEEN=1; shift ;;
  --only=*) ONLY_RAW="${1#*=}"; ONLY_SEEN=1 ;;
  --skip) [[ $# -ge 2 ]] || { echo "--skip requires module names, e.g. --skip tmux" >&2; exit 1; }; SKIP_RAW="$2"; SKIP_SEEN=1; shift ;;
  --skip=*) SKIP_RAW="${1#*=}"; SKIP_SEEN=1 ;;
  -h | --help) usage; exit 0 ;;
  *) echo "unknown arg: $1" >&2; usage >&2; exit 1 ;;
esac; shift; done

# BLIB_DRY is the shared lib's own dry-run switch (core/lib/bootstrap-lib.sh): every
# mutating helper — blib_link / blib_seed / blib_write_zshrc_loader /
# blib_set_login_shell — then PRINTS what it would do and touches nothing. The
# apparatus was already vendored here and simply had no flag wired to it.
((DRY)) && export BLIB_DRY=1

# ── PATH prelude ──────────────────────────────────────────────────────────────
# bootstrap runs in BASH, before any of the zsh layer exists, so the user-local
# bindirs the installers below write into are NOT on PATH yet — os/kali.zsh and
# core/zsh/00-tools.zsh only prepend them for the interactive shell. Without this
# every later `command -v <tool>` is blind to what an earlier step just installed:
# mise landed in ~/.local/bin, `command -v mise` still said no, the go-install
# fallback never fired, and doggo/carapace/sesh were silently skipped on EVERY
# fresh box. Same blindness re-ran the atuin installer (a possible source build)
# on every invocation. Prepend the three bindirs once, here, and the presence
# checks below all tell the truth.
#   ~/.local/bin — mise, uv, ty, and our GOBIN for the go installs
#   ~/.cargo/bin — yazi, viddy, ast-grep
#   ~/.atuin/bin — atuin's installer hardcodes this prefix (ATUIN_BIN)
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.atuin/bin:$PATH"

# ── core/ subtree present? (inline: can't source a lib out of core/ before this) ─
# Validate the SPECIFIC paths we depend on (zsh modules + the two libs sourced
# next) so a missing/partial subtree fails HERE with a precise message, not later
# with a cryptic `source: No such file`.
for _req in core/zsh/loader.zsh core/lib/ux.sh core/lib/bootstrap-lib.sh; do
  if [[ ! -e "$DOTFILES/$_req" ]]; then
    echo "core/ subtree missing or incomplete (need $_req). One-time, run:" >&2
    echo "  git subtree add  --prefix=core <dotfiles-core remote> main --squash   # first time" >&2
    echo "  git subtree pull --prefix=core <dotfiles-core remote> main --squash   # to update" >&2
    exit 1
  fi
done
unset _req

# Shared bash UX palette + provisioning scaffold (vendored under core/lib).
# shellcheck source=core/lib/ux.sh
source "$DOTFILES/core/lib/ux.sh"
# shellcheck source=core/lib/bootstrap-lib.sh
source "$DOTFILES/core/lib/bootstrap-lib.sh"

# Apply any --only/--skip module selection now the validator (blib_select) exists;
# it aborts on a malformed selector or an unknown group.
if ((ONLY_SEEN)); then blib_select --only "$ONLY_RAW"; fi
if ((SKIP_SEEN)); then blib_select --skip "$SKIP_RAW"; fi

# ── sanity: confirm this is Kali ──────────────────────────────────────────────
if ! grep -qE '^ID=kali' /etc/os-release 2>/dev/null; then
  echo "This bootstrap targets Kali Linux (expects ID=kali in /etc/os-release)." >&2
  exit 1
fi

IS_WSL=0
if blib_is_wsl; then IS_WSL=1; fi

apt_install() { # resilient: bulk first, then per-package (apt aborts on one bad name)
  local -a pkgs=("$@")
  if sudo apt-get install -y --no-install-recommends "${pkgs[@]}"; then return 0; fi
  blib_say "bulk install hit a snag — retrying package-by-package"
  local p
  for p in "${pkgs[@]}"; do
    # Keep --no-install-recommends on the retry too: without it the fallback path
    # quietly pulls a much larger dependency set than the bulk path would have,
    # so WHICH path ran changed what ended up on the box.
    sudo apt-get install -y --no-install-recommends "$p" ||
      echo "   skipped (unavailable on this box?): $p"
  done
}

# ── pinned + verified installs ────────────────────────────────────────────────
# The tools that aren't in apt used to arrive as `curl … | sh`: unpinned, unverified,
# and run as the invoking user. install/tool-versions.env now pins each one's version
# AND the SHA-256 of its release asset; this fetches that exact asset, verifies it,
# and unpacks the binary into ~/.local/bin. Nothing is piped into a shell.
#
# The pins are Linux x86_64. OUT_OF_BAND_TOOLS is also what --dry-run reports, so
# keep it in step with the verified_install calls in provision().
OUT_OF_BAND_TOOLS=(atuin mise uv ty yazi viddy ast-grep doggo carapace sesh op)
TOOL_PINS="$DOTFILES/install/tool-versions.env"
if [[ -r "$TOOL_PINS" ]]; then
  # shellcheck source=install/tool-versions.env
  source "$TOOL_PINS"
else
  echo "warning: $TOOL_PINS missing — the pinned tool installs will be skipped" >&2
fi
# Default every pin to empty so a missing/partial pin file degrades to "skip this
# tool" rather than tripping `set -u` and aborting the whole bootstrap.
: "${ATUIN_VERSION:=}" "${ATUIN_SHA256:=}"
: "${MISE_VERSION:=}" "${MISE_SHA256:=}"
: "${UV_VERSION:=}" "${UV_SHA256:=}"
: "${TY_VERSION:=}" "${TY_SHA256:=}"

# verified_install <binary> <asset-url> <sha256>
# Idempotent (a binary already on PATH is a no-op — the PATH prelude above is what
# makes that check honest), non-fatal, and FAIL-CLOSED: a missing pin, a failed
# download, or a hash mismatch skips the tool loudly rather than installing it.
verified_install() {
  local bin="$1" url="$2" want="$3"
  command -v "$bin" >/dev/null 2>&1 && return 0

  local arch; arch="$(uname -m)"
  if [[ "$arch" != x86_64 ]]; then
    echo "   $bin: no pinned asset for $arch — install it by hand" >&2
    return 0
  fi
  if [[ -z "$want" || ! "$want" =~ ^[0-9a-f]{64}$ ]]; then
    echo "   $bin: no valid SHA-256 pin in install/tool-versions.env — SKIPPED" >&2
    return 0
  fi

  blib_say "$bin (pinned release asset, sha256-verified)"
  local tmp; tmp="$(mktemp -d)" || return 0
  # Clean up on every exit path, including the early returns below.
  trap 'rm -rf "$tmp"' RETURN

  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tmp/asset" "$url"; then
    echo "   $bin: download failed ($url) — SKIPPED" >&2
    return 0
  fi
  if ! printf '%s  %s\n' "$want" "$tmp/asset" | sha256sum -c - >/dev/null 2>&1; then
    echo "   $bin: SHA-256 MISMATCH — refusing to install." >&2
    echo "     expected $want" >&2
    echo "     actual   $(sha256sum "$tmp/asset" | cut -d' ' -f1)" >&2
    echo "     If you just bumped the version, run scripts/update-tool-checksums.sh." >&2
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  # Every pinned asset is a tarball containing the binary somewhere inside; find it
  # by name rather than assuming a layout (atuin nests under a versioned dir, uv/ty
  # under a target-triple dir, mise under bin/).
  if ! tar -xzf "$tmp/asset" -C "$tmp" 2>/dev/null; then
    echo "   $bin: could not unpack the asset — SKIPPED" >&2
    return 0
  fi
  local found
  found="$(find "$tmp" -type f -name "$bin" -perm -u+x -print -quit 2>/dev/null)"
  if [[ -z "$found" ]]; then
    echo "   $bin: no '$bin' executable inside the asset — SKIPPED" >&2
    return 0
  fi
  install -m 0755 "$found" "$HOME/.local/bin/$bin"
  blib_ok "$bin → ~/.local/bin/$bin"
}

_dotfiles_go_install() { # <import-path@version> <binary-name>
  # go install drops binaries in ~/go/bin, which the shell layer does NOT put on
  # PATH (it prefixes ~/.local/bin and ~/.cargo/bin) — so pin GOBIN to ~/.local/bin
  # or the tool would still read as "missing" after bootstrap.
  [ "$#" -ge 2 ] || return 0
  if command -v "$2" >/dev/null 2>&1; then return 0; fi
  local gobin="$HOME/.local/bin"
  mkdir -p "$gobin" 2>/dev/null || true
  if command -v go >/dev/null 2>&1; then
    GOBIN="$gobin" go install "$1" >/dev/null 2>&1 ||
      echo "   $2: go install failed — retry later: GOBIN=$gobin go install $1"
  elif command -v mise >/dev/null 2>&1; then
    GOBIN="$gobin" mise exec go@latest -- go install "$1" >/dev/null 2>&1 ||
      echo "   $2: go install failed — retry later: GOBIN=$gobin go install $1"
  else
    echo "   $2: needs Go — install later with: GOBIN=$gobin go install $1"
  fi
  return 0
}

provision() {
  export DEBIAN_FRONTEND=noninteractive

  # The base list is not optional — bootstrap without it installs NOTHING and still
  # exits 0, which reads as success. (The offensive list below IS optional, hence the
  # -f test there rather than here.) blib_read_pkgs does no existence check of its own.
  local base_list="$DOTFILES/install/packages.txt"
  [[ -f "$base_list" ]] || {
    echo "missing $base_list — the base package list is required" >&2
    exit 1
  }

  local -a base=() off=()
  mapfile -t base < <(blib_read_pkgs "$base_list")
  if ((DO_OFFENSIVE)) && [[ -f "$DOTFILES/install/offensive-packages.txt" ]]; then
    mapfile -t off < <(blib_read_pkgs "$DOTFILES/install/offensive-packages.txt")
  fi

  if ((DRY)); then
    blib_say "(dry run) would apt update$( ((DO_UPGRADE)) && printf ' + full-upgrade')"
    blib_say "(dry run) would install ${#base[@]} base packages (install/packages.txt)"
    if ((${#off[@]})); then
      blib_say "(dry run) would install ${#off[@]} offensive packages (install/offensive-packages.txt)"
    else
      blib_say "(dry run) would skip the offensive tool stack"
    fi
    blib_say "(dry run) would ensure the out-of-band tools: $(printf '%s ' "${OUT_OF_BAND_TOOLS[@]}")"
    ((IS_WSL)) && blib_say "(dry run) would write /etc/wsl.conf"
    return 0
  fi

  # One password prompt up front, then keep the timestamp warm. Without this the
  # first sudo can land many minutes into an otherwise unattended run — long after
  # the operator walked away — and block on a prompt nobody is watching.
  if [[ -n "${BLIB_SU-sudo}" ]] && command -v sudo >/dev/null 2>&1; then
    sudo -v || { echo "sudo is required for the package install" >&2; exit 1; }
  fi

  if ((DO_UPGRADE)); then
    blib_say "apt update + full-upgrade"
    sudo apt-get update
    sudo apt-get full-upgrade -y
  else
    blib_say "apt update (skipping full-upgrade: --no-upgrade)"
    sudo apt-get update
  fi

  blib_say "apt base CLI stack (install/packages.txt)"
  apt_install "${base[@]}"
  blib_ok "base packages requested: ${#base[@]}"

  if ((${#off[@]})); then
    blib_say "offensive tool stack (install/offensive-packages.txt) — heavy, go get coffee"
    apt_install "${off[@]}"
    blib_ok "offensive packages requested: ${#off[@]}"
  else
    blib_say "skipping offensive tool install (--no-offensive)"
  fi

  # ── pinned + verified out-of-band tools ─────────────────────────────────────
  # Not in apt, so they come from upstream — but as VERIFIED release assets, not
  # `curl … | sh`. See install/tool-versions.env for the pins and the rationale.
  # Each is HAVE_*-guarded in the shell, so a failure here degrades, never aborts.
  verified_install atuin \
    "https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/atuin-x86_64-unknown-linux-gnu.tar.gz" \
    "$ATUIN_SHA256"
  verified_install mise \
    "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64.tar.gz" \
    "$MISE_SHA256"
  verified_install uv \
    "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
    "$UV_SHA256"

  # The cargo/go builds below need no pin file: cargo verifies against the registry
  # checksums in each crate's Cargo.lock (--locked), and `go install` verifies against
  # the module checksum database. Both are stronger than a hash we maintain by hand.
  if ! command -v yazi >/dev/null && [[ ! -x "$HOME/.cargo/bin/yazi" ]] && command -v cargo >/dev/null; then
    # yazi-fm/yazi-cli can't be installed directly from crates.io (their build.rs panics);
    # upstream requires the yazi-build orchestrator, which pulls in both binaries.
    blib_say "yazi (cargo build from source — several minutes, output below)"
    cargo install --force yazi-build || true
  fi
  # viddy (watch replacement; Core aliases watch->viddy, HAVE_VIDDY-guarded) is a Rust
  # CLI, not in Debian/Kali apt — build from source via cargo.
  if ! command -v viddy >/dev/null && [[ ! -x "$HOME/.cargo/bin/viddy" ]] && command -v cargo >/dev/null; then
    blib_say "viddy (cargo — watch replacement; not in apt)"
    cargo install --locked viddy >/dev/null 2>&1 || true
  fi
  # ast-grep (AST-aware structural search/rewrite; Core gates it on HAVE_ASTGREP) is a Rust
  # CLI not in Debian/Kali apt — build from source via cargo, like viddy. Its git-diff
  # companion difftastic IS packaged (see install/packages.txt).
  # Check the default cargo bindir too, not just PATH: ~/.cargo/bin isn't on PATH during
  # a fresh bootstrap (os/kali.zsh adds it), so a bare `command -v` would recompile every run.
  if ! command -v ast-grep >/dev/null && [[ ! -x "$HOME/.cargo/bin/ast-grep" ]] && command -v cargo >/dev/null; then
    blib_say "ast-grep (cargo — structural search; not in apt)"
    cargo install --locked ast-grep >/dev/null 2>&1 || true
  fi
  # ty — Astral's type checker. Prefer `uv tool install` (uv verifies its own
  # downloads and keeps ty upgradable in place); fall back to the pinned release
  # asset when uv didn't make it onto the box.
  if ! command -v ty >/dev/null 2>&1; then
    if command -v uv >/dev/null 2>&1; then
      blib_say "ty (via uv tool install)"
      uv tool install ty || true
    else
      verified_install ty \
        "https://github.com/astral-sh/ty/releases/download/${TY_VERSION}/ty-x86_64-unknown-linux-gnu.tar.gz" \
        "$TY_SHA256"
    fi
  fi

  # The remaining core-doctor tools that aren't reliably in apt: doggo/sesh are go
  # binaries; carapace is an upstream .deb (see below — it CANNOT be go-installed);
  # op is 1Password's signed apt repo. All presence-guarded and best-effort
  # ('|| true') — they're HAVE_*-guarded in the shell, so a failure here never aborts
  # bootstrap (and never trips set -e).
  command -v doggo >/dev/null 2>&1 || { blib_say "doggo (go install)"; _dotfiles_go_install github.com/mr-karan/doggo/cmd/doggo@latest doggo; }
  command -v sesh >/dev/null 2>&1 || { blib_say "sesh (go install — /v2 module path)"; _dotfiles_go_install github.com/joshmedeski/sesh/v2@latest sesh; }

  # carapace: upstream's official .deb, NOT `go install`.
  #
  # This line used to read `_dotfiles_go_install .../carapace-bin/cmd/carapace@latest`.
  # That cannot work, and not for any version — two independent blockers, both properties
  # of how the module is built rather than a break to wait out (core/PORTING-MATRIX.md's
  # carapace footnote carries the full story and the evidence — numbered ²⁷ there, and it
  # lands in this vendored copy with the next Core sync; until then see
  # dotgibson/dotfiles-core#468):
  #   1. Its go.mod carries `replace` directives (spf13/pflag → carapace-pflag,
  #      kevinburke/ssh_config → carapace-sh/ssh_config), and `go install pkg@version`
  #      refuses any module that does, because a replace would make the build differ from
  #      building it as the main module.
  #   2. The generated sources (pkg/{actions,conditions}/*_generated.go) are not committed;
  #      cmd/carapace/main.go's `go:generate` lines produce them. So even a plain
  #      `go build` on a clone fails until generation has run.
  # Checked across the whole tag history: 184 of 184 tags (v0.0.3 2020-08-31 → v1.7.3
  # 2026-06-30) carry a `replace`, and 0 commit the generated sources. So pinning an older
  # @version does NOT help — that is the tempting next move, and it fails identically.
  # The old call therefore failed on EVERY bootstrap, invisibly: _dotfiles_go_install sends
  # the explanation to /dev/null, so the run just never produced a carapace and the only
  # trace was one terse "go install failed" line among many.
  #
  # Upstream publishes an official .deb per release, which lands in /usr/bin. Notes on the
  # shape below, in the order they will trip you up:
  #   • `dpkg --print-architecture` is used rather than `uname -m` because Debian's arch
  #     names (amd64/arm64) are exactly upstream's asset names — no mapping table needed.
  #     The op block below already uses it for the same reason. Debian i386 is NOT upstream's
  #     "386", so anything outside amd64/arm64 is refused rather than guessed at.
  #   • `apt-get install` wants a PATH, not a URL, so this downloads first. An absolute path
  #     is treated as a local file (the leading `./` is only needed for RELATIVE paths).
  #     Prefer this over `dpkg -i`, which does not resolve dependencies.
  #   • Upstream signs nothing (no `signs:` stanza in its .goreleaser.yml), which apt does
  #     not mind for a local .deb — no --allow-unauthenticated needed. dotfiles-openSUSE has
  #     to pass two extra flags for the same artifact because zypper is stricter here.
  #
  # Be exact about what this does and does not buy: installing a downloaded .deb does NOT
  # add a repo, so NOTHING upgrades carapace afterwards. Not `apt upgrade`, not maint, and
  # not a later bootstrap either — the `command -v carapace` guard skips the whole block
  # once the binary exists. Upstream ships no apt repo and Debian does not package it, so
  # there is no upgrade source to point at; updating is a deliberate manual step, and
  # `carapace --version` is how you would know you are behind. That is the real cost, and it
  # is still the right route: `go install` cannot work at all, so the choice is a
  # manually-updated binary or no carapace.
  #
  # Resolve the newest asset for THIS arch with grep/cut (no jq dependency) rather than
  # pinning a version that would rot. Mirrors dotfiles-Fedora and dotfiles-openSUSE — port
  # fixes across all three. A future change wanting a real trust anchor would pin the version
  # and verify a SHA-256 recorded in THIS tree; upstream's own checksums.txt is unsigned and
  # same-origin, so it catches corruption, not compromise.
  if ! command -v carapace >/dev/null 2>&1; then
    blib_say "carapace (upstream .deb — go install is impossible, see above)"
    local _cara_arch _cara_url _cara_tmp
    _cara_arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
    case "$_cara_arch" in
    amd64 | arm64) ;;
    *) _cara_arch="" ;;
    esac
    if [[ -z "$_cara_arch" ]]; then
      echo "   carapace: no upstream .deb for $(dpkg --print-architecture 2>/dev/null) — skipping; see github.com/carapace-sh/carapace-bin/releases"
    else
      _cara_url="$(curl -fsSL --max-time 30 \
        https://api.github.com/repos/carapace-sh/carapace-bin/releases/latest 2>/dev/null |
        grep -o "\"browser_download_url\": *\"[^\"]*linux_${_cara_arch}\.deb\"" |
        cut -d'"' -f4 | head -1)" || true
      if [[ -n "$_cara_url" ]]; then
        # mktemp is checked, and the cleanup is guarded, because this block is supposed to
        # be best-effort and `set -e` is on. A bare `_cara_tmp="$(mktemp -d)"` aborts the
        # WHOLE bootstrap the moment mktemp fails (unwritable TMPDIR, full disk) — an
        # assignment takes the exit status of its command substitution — and a bare
        # `rm -rf "$_cara_tmp"` on an empty var exits non-zero too. Testing mktemp inside
        # `if !` suspends `set -e` for it; the `if [[ -n ]]` cleanup can't fail the run the
        # way `[[ -n … ]] && rm …` would when the test is false.
        _cara_tmp=""
        if ! _cara_tmp="$(mktemp -d 2>/dev/null)"; then
          echo "   carapace: could not create a temp dir (unwritable TMPDIR? disk full?) — skipping; asset was $_cara_url"
        elif curl -fsSL --max-time 180 -o "$_cara_tmp/carapace.deb" "$_cara_url"; then
          sudo apt-get install -y "$_cara_tmp/carapace.deb" >/dev/null ||
            echo "   carapace: .deb install failed — retry later: curl -fsSLO $_cara_url && sudo apt-get install -y ./${_cara_url##*/}"
        else
          echo "   carapace: download failed (offline?) — retry later: $_cara_url"
        fi
        if [[ -n "$_cara_tmp" ]]; then rm -rf "$_cara_tmp"; fi
      else
        echo "   carapace: could not resolve the latest linux_${_cara_arch} .deb (offline? API rate-limited?) — see github.com/carapace-sh/carapace-bin/releases"
      fi
    fi
  fi

  # op — 1Password CLI, from 1Password's official signed apt repo. Whole block is
  # guarded on `command -v op` and each step is best-effort so it can't abort bootstrap.
  if ! command -v op >/dev/null 2>&1; then
    blib_say "op (1Password CLI — official signed apt repo)"
    sudo mkdir -p /usr/share/keyrings
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
    # The repo file is written before `apt-get update`; if update OR install fails,
    # a stale entry would wedge every future `apt-get update`. Roll it back on failure.
    if ! (sudo apt-get update && sudo apt-get install -y 1password-cli); then
      sudo rm -f /etc/apt/sources.list.d/1password.list /usr/share/keyrings/1password-archive-keyring.gpg
      echo "   op install failed — repo entry rolled back; see developer.1password.com/docs/cli/get-started"
    fi
  fi

  if ((IS_WSL)); then
    blib_say "installing /etc/wsl.conf (systemd + default user + interop)"
    local user
    user="$(id -un)"
    sed "s/__WSL_USER__/$user/" "$DOTFILES/wsl/wsl.conf" | sudo tee /etc/wsl.conf >/dev/null
    blib_ok "wsl.conf written. From Windows: 'wsl.exe --shutdown', then reopen Kali."
    blib_say "NOTE: reverse-shell reachability needs mirrored networking — see wsl/windows.wslconfig.example"
  fi
}

wire_links() {
  # Shared Core surface + the Kali OS overlays, both from core/lib/bootstrap-lib.sh.
  blib_link_core "$DOTFILES" "$CONFIG"
  blib_link_os_layer "$DOTFILES" "$CONFIG" kali

  # ── OFFENSIVE role layer (unique to this repo) ──────────────────────────────
  blib_say "symlinking OFFENSIVE role layer"
  # v4: link the offensive stage as the numbered fragment 85-offensive.zsh (role band
  # 85-94). The loader globs $ZSH_CFG/NN-*.zsh, so an unnumbered offensive.zsh would never
  # load; band 85 sorts after the OS layer (80-os.zsh) and before host-local (99-local.zsh),
  # preserving the old `… os offensive local` order. Drop any stale pre-v4 unnumbered link.
  [[ -L "$CONFIG/zsh/offensive.zsh" ]] && rm -f "$CONFIG/zsh/offensive.zsh"
  blib_link "$DOTFILES/offensive/offensive.zsh" "$CONFIG/zsh/85-offensive.zsh"
  [[ -d "$DOTFILES/offensive/templates" ]] && blib_link "$DOTFILES/offensive/templates" "$CONFIG/kali/templates"
  # The `prefix + e` engagement-session popup (os/kali.conf). It CANNOT live under
  # $CONFIG/tmux/scripts — that path is a whole-dir symlink to core/tmux/scripts (Core-
  # owned, no offensive script) — so link it a level up, beside tmux.conf, and the
  # binding points there. Gated on `blib_want tmux` so `--skip tmux` / `--only …` behave
  # consistently with how Core wires its own tmux files.
  blib_want tmux && [[ -f "$DOTFILES/offensive/tmux/tmux-eng.sh" ]] && blib_link "$DOTFILES/offensive/tmux/tmux-eng.sh" "$CONFIG/tmux/tmux-eng.sh"
  # CTF/HTB cheatsheet + companion field references — surfaced at ~/ for htp/xdev/evade/ipp.
  [[ -f "$DOTFILES/offensive/hacktheplanet" ]] && blib_link "$DOTFILES/offensive/hacktheplanet" "$HOME/hacktheplanet"
  [[ -f "$DOTFILES/offensive/exploitdev" ]] && blib_link "$DOTFILES/offensive/exploitdev" "$HOME/exploitdev"
  [[ -f "$DOTFILES/offensive/evasion" ]] && blib_link "$DOTFILES/offensive/evasion" "$HOME/evasion"
  [[ -f "$DOTFILES/offensive/ippsec" ]] && blib_link "$DOTFILES/offensive/ippsec" "$HOME/ippsec"
  # The structured red<->blue companion (the `htpx` browser + its entries/ tree).
  # Linked as a directory so htpx resolves entries/ relative to itself; run via `htpx`.
  [[ -d "$DOTFILES/offensive/companion" ]] && blib_link "$DOTFILES/offensive/companion" "$HOME/companion"

  # The managed .zshrc loader (v4): param-less — it globs the numbered fragments, so the
  # offensive stage rides band 85 (85-offensive.zsh) with no explicit module list.
  #
  # This ALSO seeds $ZDOTDIR/.zshrc (via the lib's _blib_seed_zdotdir_rc): a login zsh
  # configured the XDG way reads $ZDOTDIR/.zshrc, not $HOME/.zshrc, and without the
  # mirror a fresh login window fires zsh-newuser-install before our rc loads.
  #
  # Do NOT re-do that link by hand here. The lib's seeder carries an ELOOP guard for
  # the INVERTED layout (~/.zshrc is itself a symlink to $ZDOTDIR/.zshrc): it compares
  # resolved inodes with -ef, warns, and declines. A second, unguarded `blib_link
  # "$HOME/.zshrc" "$CONFIG/zsh/.zshrc"` used to run right here and would move the
  # target aside and create exactly the symlink cycle the guard exists to prevent —
  # after which zsh resolves ~/.zshrc → $ZDOTDIR/.zshrc → ~/.zshrc and gives up.
  blib_write_zshrc_loader

  blib_set_login_shell

  # Install the local pre-commit core-guard so a hand-edit to the vendored core/
  # subtree is refused on THIS clone. .git/hooks isn't version-controlled, so a fresh
  # clone has no guard until something installs one — sync-core.sh does it from the
  # dotfiles-core side, which never runs on a machine that only ever consumes Core.
  # The CI gate (core-integrity.yml) is the durable backstop; this is the fast local one.
  #
  # Gated on DRY by hand: blib_install_core_guard is the one helper here that does NOT
  # honour BLIB_DRY (it writes .git/hooks/pre-commit unconditionally), so calling it
  # from a --dry-run would break the "nothing was changed" contract.
  if ((DRY)); then
    blib_say "would install the core-guard pre-commit hook in ${DOTFILES##*/}"
  else
    blib_install_core_guard "$DOTFILES" || true
  fi

  blib_ok "symlinks wired$(blib_selected_note)"
}

((LINKS_ONLY)) || provision
wire_links
blib_wire_summary
if ((DRY)); then
  blib_ok "dry run complete — nothing was changed."
else
  blib_ok "Kali bootstrap complete — open a new shell, or: exec zsh"
fi
