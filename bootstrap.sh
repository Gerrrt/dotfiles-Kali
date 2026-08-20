#!/usr/bin/env bash
# dotfiles-Offense/bootstrap.sh
# Wire the OFFENSIVE (red) role layer onto an already-provisioned box.
# Distro-agnostic: installs NOTHING by default (your OS-native layer does that).
# Idempotent. Stacks: vendored Core + your OS-native layer + OFFENSIVE role.
#
# This repo used to be BOTH an OS-native layer for Kali and a role layer on top of it.
# The OS half now lives in dotfiles-Debian, which accepts ID=kali as a first-class
# target — so the apt base list, the SHA-pinned out-of-band installs, the WSL bootstrap
# and the ssh/git/zsh OS overlays all moved there. What is left here is the role.
#
# The SHARED half of a bootstrap — link-with-backup, the Core symlink surface, the
# managed ~/.zshrc loader — is CALLED out of core/lib/bootstrap-lib.sh, not copied.
# What stays here is the genuinely offensive part: the tool probe, the opt-in tool
# installer, and the band-85 role stage.
#
# >>>USAGE
#   ./bootstrap.sh                 # symlinks + loader + the host-tool probe
#   ./bootstrap.sh --links-only    # just (re)create symlinks (no probe)
#   ./bootstrap.sh --no-check      # skip the host-tool probe
#   ./bootstrap.sh --install       # OPT-IN: also install the offensive tool stack
#   ./bootstrap.sh --dry-run       # print the whole plan, change nothing
#   ./bootstrap.sh --only zsh,nvim # link ONLY these Core module groups
#   ./bootstrap.sh --skip tmux     # link everything EXCEPT these groups
#
# Module groups (for --only/--skip): zsh nvim tmux git prompt tools — Core wiring
# only; the band-85 role stage rides `zsh`.
# <<<USAGE
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
LINKS_ONLY=0
DO_CHECK=1
DO_INSTALL=0
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
  --no-check) DO_CHECK=0 ;;
  --install) DO_INSTALL=1 ;;
  # Accepted, not an error: --no-offensive used to mean "skip the heavy tool install",
  # which is now the DEFAULT. Anyone (or any script) carrying the old flag should get
  # the behaviour they asked for, not an abort — so say it is redundant and move on.
  --no-offensive)
    echo "note: --no-offensive is redundant — this bootstrap installs nothing unless --install is passed" >&2
    ;;
  # Likewise --no-upgrade: there is no apt full-upgrade here any more. Your OS-native
  # layer owns that (dotfiles-Debian's bootstrap.sh, or plain `apt full-upgrade`).
  --no-upgrade)
    echo "note: --no-upgrade is obsolete — package upgrades belong to your OS-native layer" >&2
    ;;
  --dry-run | -n) DRY=1 ;;
  --only) [[ $# -ge 2 ]] || { echo "--only requires module names, e.g. --only zsh,nvim" >&2; exit 1; }; ONLY_RAW="$2"; ONLY_SEEN=1; shift ;;
  --only=*) ONLY_RAW="${1#*=}"; ONLY_SEEN=1 ;;
  --skip) [[ $# -ge 2 ]] || { echo "--skip requires module names, e.g. --skip tmux" >&2; exit 1; }; SKIP_RAW="$2"; SKIP_SEEN=1; shift ;;
  --skip=*) SKIP_RAW="${1#*=}"; SKIP_SEEN=1 ;;
  -h | --help) usage; exit 0 ;;
  *) echo "unknown arg: $1" >&2; usage >&2; exit 1 ;;
esac; shift; done

# BLIB_DRY is the shared lib's own dry-run switch (core/lib/bootstrap-lib.sh): every
# mutating helper — blib_link / blib_seed / blib_write_zshrc_loader — then PRINTS what
# it would do and touches nothing.
((DRY)) && export BLIB_DRY=1

# ── PATH prelude ──────────────────────────────────────────────────────────────
# bootstrap runs in BASH, before any of the zsh layer exists, so the user-local bindirs
# `--install` writes into are NOT on PATH yet — the OS layer's zsh fragment and Core's
# 00-tools.zsh only prepend them for the interactive shell. Without this every later
# `command -v <tool>` is blind to what an earlier step just installed, and the probe
# reports a tool it watched get installed as missing.
#   ~/.local/bin — pipx shims, and our GOBIN for the go installs
#   ~/.cargo/bin — cargo-installed tools an operator may have added
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ── core/ subtree present? (inline: can't source a lib out of core/ before this) ─
# Validate the SPECIFIC paths we depend on (zsh modules + the two libs sourced next) so
# a missing/partial subtree fails HERE with a precise message, not later with a cryptic
# `source: No such file`.
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

# ── /etc/os-release, read once ────────────────────────────────────────────────
# NOT a gate. This bootstrap runs anywhere; the ID only decides which install ROUTE
# `--install` takes, and is reported by the probe so the report is interpretable.
OS_ID="" OS_ID_LIKE=""
if [[ -r /etc/os-release ]]; then
  OS_ID="$(sed -n 's/^ID=//p' /etc/os-release | head -1 | tr -d '"'"'"'')"
  OS_ID_LIKE="$(sed -n 's/^ID_LIKE=//p' /etc/os-release | head -1 | tr -d '"'"'"'')"
fi
# Debian-family covers kali, debian, ubuntu, and anything declaring ID_LIKE=debian.
_is_debian_family() {
  case "$OS_ID" in kali | debian | ubuntu | raspbian) return 0 ;; esac
  case " $OS_ID_LIKE " in *" debian "*) return 0 ;; esac
  return 1
}

# ── Host-tool probe (report only — never installs) ───────────────────────────
# `command -v` answers "is this on $PATH", which is NOT the question "is this tool on
# the box". Several offensive tools install somewhere $PATH never sees, and calling
# those "missing" sends you to reinstall something you already have. The opposite error
# would be just as wrong: offensive.zsh invokes these by bare name, so a tool that is
# present but off $PATH is still unusable by this layer. So report three states — on
# PATH, present-but-unreachable (with the one-line fix), and genuinely absent — and
# count only the last as missing. Same shape as dotfiles-Defense's probe.
#
# _probe_offpath <tool> — echo an executable path for <tool> found OFF $PATH, else fail.
# Deliberately a short, general list: tool-owned prefixes, unpacked release trees, snap,
# and pipx's venv bindir (how impacket/certipy/netexec arrive on a non-Kali box).
_probe_offpath() {
  local t="$1" p
  for p in "/opt/$t/bin/$t" "/usr/local/$t/bin/$t" "$HOME/.local/share/$t/$t" \
    "$HOME/.local/bin/$t" "/snap/bin/$t" "/usr/share/$t/$t"; do
    [ -x "$p" ] && {
      printf '%s\n' "$p"
      return 0
    }
  done
  return 1
}

# _probe_altname <tool> — echo an alternate command name for <tool> that IS on $PATH.
# One capability, several names depending on how it was packaged. This is the single
# biggest source of false "missing" on a non-Kali box: Kali ships wrapper scripts
# (impacket-secretsdump, httpx-toolkit, sliver-client) that pipx/go installs do not.
_probe_altname() {
  local t="$1" a
  case "$t" in
  impacket-secretsdump) set -- secretsdump.py ;;
  certipy-ad) set -- certipy ;;
  httpx-toolkit) set -- httpx ;;
  sliver-client) set -- sliver ;;
  searchsploit) set -- exploitdb ;;
  john) set -- john-the-ripper ;;
  # No bloodhound entry, deliberately: the CE collector installs as `bloodhound-ce-python`
  # from BOTH apt and pipx, so there is no alternate packaging name to teach. The legacy
  # `bloodhound-python` / `bloodhound.py` is a DIFFERENT capability — its zips don't ingest
  # into CE — so accepting it here would report a green tick for the one collector that
  # silently produces unusable output. A false "missing" is the cheaper failure.
  *) return 1 ;;
  esac
  for a in "$@"; do
    command -v "$a" >/dev/null 2>&1 && {
      printf '%s\n' "$a"
      return 0
    }
  done
  return 1
}

# _probe_list — the tools to probe, read from install/tools.lst (column 1, comments and
# blanks stripped). Single source: the set used to live only as a literal in this file,
# with nothing keeping it in step with what offensive.zsh actually calls.
_probe_list() {
  local f="$DOTFILES/install/tools.lst"
  [ -r "$f" ] || {
    blib_warn "install/tools.lst is missing or unreadable — cannot probe host tools"
    return 1
  }
  sed 's/#.*//' "$f" | awk 'NF { print $1 }'
}

check_tools() {
  blib_say "checking host tools on ${OS_ID:-an unknown distro} (install with --install, or via your OS layer)"
  local t missing=0 unreachable=0 found="" tools=""
  tools="$(_probe_list)" || return 0
  [ -n "$tools" ] || {
    blib_warn "install/tools.lst lists no tools — nothing probed"
    return 0
  }
  # Order is the file's order, and zsh leads it deliberately: it is the shell this whole
  # layer runs in, so its absence is categorically worse than a missing offensive tool.
  for t in $tools; do
    if command -v "$t" >/dev/null 2>&1; then
      blib_ok "found: $t"
    elif found="$(_probe_altname "$t")"; then
      blib_ok "found: $t (as \`$found\`)"
    elif found="$(_probe_offpath "$t")"; then
      blib_warn "unreachable: $t is installed at $found but is not on \$PATH"
      blib_warn "  offensive.zsh calls it by bare name — fix with:  ln -s $found ~/.local/bin/$t"
      unreachable=$((unreachable + 1))
    else
      blib_warn "missing: $t"
      missing=$((missing + 1))
    fi
  done
  # Wordlists are data, not commands, so `command -v` cannot see them — but the helpers
  # in offensive.zsh default straight at these paths, so their absence is worth one line.
  [ -d "${SECLISTS_DIR:-/usr/share/seclists}" ] ||
    blib_warn "seclists not at ${SECLISTS_DIR:-/usr/share/seclists} — set \$SECLISTS_DIR or install it"
  if ((missing == 0 && unreachable == 0)); then
    blib_ok "all probed tools present"
  else
    ((missing > 0)) &&
      blib_warn "$missing tool(s) missing — the offensive tools are optional; zsh is not"
    ((unreachable > 0)) &&
      blib_warn "$unreachable tool(s) installed but off \$PATH — symlink them (see above) or this layer cannot call them"
  fi
  # Report-only, like the rest of this probe: never a non-zero exit. Callers that want
  # to gate on it read the counts above.
  return 0
}

# ── OPT-IN tool install (--install) ──────────────────────────────────────────
# Two routes, and the difference is not cosmetic.
#
#   Kali          → apt, from install/offensive-packages.txt. Kali packages essentially
#                   this entire stack, with the wrapper names offensive.zsh probes for.
#   other Debian  → a PORTABLE SUBSET via pipx + go. Debian and Ubuntu package almost
#                   none of it, so the alternative to this subset is nothing at all.
#   anything else → refuse, and say so. Guessing a package manager here would install
#                   the wrong thing under the right name.
#
# The subset is small ON PURPOSE. It is the set that (a) installs cleanly from PyPI or
# the Go module proxy with no system libraries to chase, and (b) offensive.zsh actually
# probes. Everything else — responder, evil-winrm, metasploit, hashcat, burp — has real
# packaging behind it and belongs to your OS layer or an upstream installer, not to a
# best-effort loop here.
#
# NAME MISMATCH, and it is deliberate rather than a bug to fix: pipx's impacket installs
# `secretsdump.py`, not Kali's `impacket-secretsdump` wrapper, and PyPI certipy-ad
# installs `certipy`, not `certipy-ad`. offensive.zsh probes the KALI names, so those
# HAVE_* flags will not fire on a pipx box. _probe_altname above teaches the report to
# recognise both, so at least the report tells the truth; making the shell layer resolve
# both names is a change to offensive.zsh, tracked separately.
apt_install() { # resilient: bulk first, then per-package (apt aborts on one bad name)
  local -a pkgs=("$@")
  if sudo apt-get install -y --no-install-recommends "${pkgs[@]}"; then return 0; fi
  blib_say "bulk install hit a snag — retrying package-by-package"
  local p
  for p in "${pkgs[@]}"; do
    # Keep --no-install-recommends on the retry too: without it the fallback path
    # quietly pulls a much larger dependency set than the bulk path would have, so
    # WHICH path ran changed what ended up on the box.
    sudo apt-get install -y --no-install-recommends "$p" ||
      echo "   skipped (unavailable on this box?): $p"
  done
}

# _pipx_install <pypi-name> <binary-it-provides>
# Guarded on the BINARY, not the package: that is what makes a re-run free, and it is
# the same question the probe asks. Best-effort — a failure here degrades the layer, it
# never aborts the wiring below.
_pipx_install() {
  local pkg="$1" bin="$2"
  if command -v "$bin" >/dev/null 2>&1; then
    blib_ok "$bin already present — skipping"
    return 0
  fi
  blib_say "$pkg (pipx — provides $bin)"
  pipx install "$pkg" >/dev/null 2>&1 ||
    echo "   pipx install $pkg failed — retry by hand: pipx install $pkg"
}

# _go_install <module@version> <binary-it-provides>
# GOBIN is pinned to ~/.local/bin (already on PATH from the prelude) so the binaries land
# where the probe and the shell both look, rather than in a GOPATH the interactive shell
# may not export.
_go_install() {
  local mod="$1" bin="$2"
  if command -v "$bin" >/dev/null 2>&1; then
    blib_ok "$bin already present — skipping"
    return 0
  fi
  blib_say "$bin (go install $mod)"
  GOBIN="$HOME/.local/bin" go install "$mod" >/dev/null 2>&1 ||
    echo "   go install $mod failed — retry by hand: GOBIN=\"\$HOME/.local/bin\" go install $mod"
}

install_offensive() {
  local off_list="$DOTFILES/install/offensive-packages.txt"

  if [[ "$OS_ID" == kali ]]; then
    [[ -f "$off_list" ]] || {
      echo "missing $off_list — nothing to install" >&2
      return 1
    }
    local -a off=()
    mapfile -t off < <(blib_read_pkgs "$off_list")
    ((${#off[@]})) || {
      blib_warn "$off_list parsed to zero package names"
      return 0
    }
    if ((DRY)); then
      blib_say "(dry run) would apt-install ${#off[@]} offensive packages (install/offensive-packages.txt)"
      return 0
    fi
    # One password prompt up front, then keep the timestamp warm. Without this the first
    # sudo can land many minutes into an otherwise unattended run — long after the
    # operator walked away — and block on a prompt nobody is watching.
    if command -v sudo >/dev/null 2>&1; then
      sudo -v || { echo "sudo is required for the package install" >&2; return 1; }
    fi
    export DEBIAN_FRONTEND=noninteractive
    blib_say "apt update (the offensive stack is heavy — go get coffee)"
    sudo apt-get update
    apt_install "${off[@]}"
    blib_ok "offensive packages requested: ${#off[@]}"
    blib_say "the apt list is Kali's. On a slim box some of these ship in kali-linux-default already."
    return 0
  fi

  if ! _is_debian_family; then
    blib_warn "--install has no route for ${OS_ID:-this distro}"
    blib_warn "  the apt list is Kali's and the portable subset assumes a Debian-family box."
    blib_warn "  install the tools your OS packages, then re-run without --install to see the report."
    return 0
  fi

  # Portable subset: Debian/Ubuntu (and any other ID_LIKE=debian box) that is not Kali.
  blib_say "not Kali (ID=${OS_ID:-unknown}) — installing the PORTABLE SUBSET only"
  blib_say "  the rest of install/offensive-packages.txt is Kali-packaged; see its UPSTREAM notes"
  if ((DRY)); then
    blib_say "(dry run) would pipx-install: impacket certipy-ad netexec bloodyAD ldapdomaindump bloodhound-ce"
    blib_say "(dry run) would go-install:   nuclei gobuster ffuf kerbrute"
    return 0
  fi

  if command -v pipx >/dev/null 2>&1; then
    # Binary names are the ones the tool actually installs, which for impacket and
    # certipy-ad are NOT the Kali wrapper names — see the block comment above.
    _pipx_install impacket secretsdump.py
    _pipx_install certipy-ad certipy
    _pipx_install netexec nxc
    _pipx_install bloodyAD bloodyAD
    _pipx_install ldapdomaindump ldapdomaindump
    # PyPI `bloodhound-ce` provides the same `bloodhound-ce-python` binary Kali's package does.
    # Without it a non-Kali box got no collector at all, while tools.lst probed for one — a
    # warning that could never be satisfied by --install.
    _pipx_install bloodhound-ce bloodhound-ce-python
  else
    blib_warn "pipx not found — skipping the python tools (install pipx via your OS layer)"
  fi

  if command -v go >/dev/null 2>&1; then
    _go_install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest nuclei
    _go_install github.com/OJ/gobuster/v3@latest gobuster
    _go_install github.com/ffuf/ffuf/v2@latest ffuf
    # kerbrute is upstream-FROZEN (last release v1.0.3, Dec 2019) and has never been
    # apt-packaged, so @latest here is a stable commit rather than a moving target —
    # which is exactly why redup does not carry it as a "fast mover".
    _go_install github.com/ropnop/kerbrute@latest kerbrute
  else
    blib_warn "go not found — skipping the go tools (install golang via your OS layer)"
  fi
}

wire_links() {
  # Core's whole shipped surface, one call: the numbered zsh fragments, nvim + the vim
  # fallback, tmux (+ tpm), starship, git, and the tools group.
  blib_link_core "$DOTFILES" "$CONFIG"
  # NO blib_link_os_layer, and no os/ directory at all any more: band 80 belongs to
  # your OS-native repo (dotfiles-Debian, which covers Kali), not to this one.

  # ── OFFENSIVE role layer ───────────────────────────────────────────────────
  # One call, from Core (v4.13.1+). It links all three role destinations and drops a
  # stale pre-v4 unnumbered link, honouring BLIB_DRY throughout:
  #
  #   offensive/offensive.zsh   → $CONFIG/zsh/85-offensive.zsh   (role band 85-94)
  #   offensive/offensive.conf  → $CONFIG/tmux/role.conf         (sourced LAST by Core)
  #   offensive/templates/      → $CONFIG/offensive/templates
  #
  # This replaces a hand-rolled block that had already drifted from dotfiles-Defense's
  # copy of the same three links — Defense honoured the dry-run when dropping the stale
  # link and this repo did not, so `--dry-run` mutated the box here and not there.
  blib_link_role_layer "$DOTFILES" "$CONFIG" offensive

  # ── migrate a box bootstrapped before the role layer existed ───────────────
  # Two destinations this repo used to write are no longer ours, and both are left
  # DANGLING by the change above rather than updated:
  #
  #   $CONFIG/tmux/os.conf        — was os/kali.conf; the OS repo owns band 80 now
  #   $CONFIG/kali/templates      — templates moved to $CONFIG/offensive/templates
  #
  # Remove each ONLY when it is a symlink resolving inside THIS checkout. That guard is
  # the whole point: on a box also running dotfiles-Debian, $CONFIG/tmux/os.conf is
  # Debian's live link and must not be touched. Core deliberately declined a compat
  # symlink for the templates move (it would preserve a ~/.config/kali/ on a repo no
  # longer called Kali), so cleaning up is the alternative to leaving one behind.
  local _stale
  for _stale in "$CONFIG/tmux/os.conf" "$CONFIG/kali/templates"; do
    [[ -L "$_stale" ]] || continue
    # `readlink`, NOT `readlink -f`. -f CANONICALISES, which requires every parent
    # component of the target to exist — and os/ has just been deleted, so -f returns
    # EMPTY for exactly the dangling link this loop exists to clear, and the guard below
    # would never match it. Plain readlink reads the stored target verbatim, dangling or
    # not, which is the question being asked: does this link point into THIS checkout?
    [[ "$(readlink "$_stale" 2>/dev/null)" == "$DOTFILES"/* ]] || continue
    if ((DRY)); then
      blib_say "would drop stale link from the pre-role-layer wiring: $_stale"
    else
      rm -f "$_stale"
      # Take the now-empty $CONFIG/kali with it; rmdir refuses a non-empty dir, so a
      # host that put something else there keeps it.
      rmdir "${_stale%/*}" 2>/dev/null || true
    fi
  done

  # The `prefix + e` popup script. It CANNOT live under $CONFIG/tmux/scripts — that path
  # is a whole-dir symlink to core/tmux/scripts (Core-owned, no offensive script) — so
  # link it a level up, beside tmux.conf, and the binding points there. Gated on
  # `blib_want tmux` so --skip tmux / --only … behave consistently with Core's own wiring.
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
  # Do NOT re-do that link by hand here. The lib's seeder carries an ELOOP guard for the
  # INVERTED layout (~/.zshrc is itself a symlink to $ZDOTDIR/.zshrc): it compares
  # resolved inodes with -ef, warns, and declines.
  blib_write_zshrc_loader

  # Install the local pre-commit core-guard so a hand-edit to the vendored core/ subtree
  # is refused on THIS clone. .git/hooks isn't version-controlled, so a fresh clone has
  # no guard until something installs one. The CI gate (core-integrity.yml) is the
  # durable backstop; this is the fast local one.
  #
  # Gated on DRY by hand: blib_install_core_guard is the one helper here that does NOT
  # honour BLIB_DRY (it writes .git/hooks/pre-commit unconditionally), so calling it from
  # a --dry-run would break the "nothing was changed" contract.
  if ((DRY)); then
    blib_say "would install the core-guard pre-commit hook in ${DOTFILES##*/}"
  else
    blib_install_core_guard "$DOTFILES" || true
  fi

  blib_ok "symlinks wired$(blib_selected_note)"
}

# --links-only is the "just wire symlinks" path, so it skips BOTH the probe and the
# installer; without consulting LINKS_ONLY here the flag would be dead. --no-check skips
# the probe independently. --links-only with --install is a contradiction rather than a
# preference, so it is refused instead of silently honouring one of the two.
if ((LINKS_ONLY && DO_INSTALL)); then
  echo "--links-only and --install contradict each other: one wires symlinks only, the other installs packages" >&2
  exit 1
fi
((DO_CHECK && !LINKS_ONLY)) && check_tools
((DO_INSTALL && !LINKS_ONLY)) && install_offensive
wire_links
blib_wire_summary
blib_say "engagement data lives in ~/engagements (outside this repo) — run \`mkengagement <name>\` to start one"

if ((DRY)); then
  blib_ok "dry run complete — nothing was changed."
  exit 0
fi

# Everything above wires a zsh config. On a box with no zsh — or with zsh installed but
# not the login shell — every step still "succeeds" and nothing ever loads. So this is
# checked OUTSIDE check_tools: --no-check and --links-only skip a tool probe, but must
# not silence a correctness guard. Non-fatal, matching how missing tools are handled.
#
# Deliberately NOT blib_set_login_shell: that helper is correct, but it sudo's (chsh, and
# an append to /etc/shells). This bootstrap's contract is now report-only — "installs
# NOTHING by default", line 4 — so it names the remedy and lets the operator run it.
#
# Best-effort, and it MUST NOT abort: this file runs under `set -euo pipefail`, where
# pipefail makes `getent … | cut` return getent's status rather than cut's. getent exits
# 2 when the user is not in the passwd DB, and is 127 when absent altogether — either
# would take the whole bootstrap down on its last line, turning the non-fatal guard below
# into the loudest possible failure. So every lookup is guarded, in descending order of
# trust: getent, then /etc/passwd, then $SHELL.
detect_login_shell() {
  local user shell_field=""
  user="$(id -un 2>/dev/null || true)"
  if [[ -n "$user" ]]; then
    if command -v getent >/dev/null 2>&1; then
      shell_field="$(getent passwd "$user" 2>/dev/null | cut -d: -f7 || true)"
    fi
    if [[ -z "$shell_field" && -r /etc/passwd ]]; then
      shell_field="$(awk -F: -v u="$user" '$1 == u { print $7; exit }' /etc/passwd 2>/dev/null || true)"
    fi
  fi
  printf '%s' "${shell_field:-${SHELL:-}}"
}

login_shell="$(detect_login_shell)"
if ! command -v zsh >/dev/null 2>&1; then
  blib_warn "zsh is NOT installed — the config above is wired but inert; nothing reads ~/.zshrc"
  blib_warn "  your OS-native layer owns package installation (dotfiles-Debian covers Kali)"
elif [[ "$login_shell" != *zsh ]]; then
  blib_warn "zsh is installed, but your login shell is ${login_shell:-unknown}"
  blib_warn "  fix: chsh -s $(command -v zsh)  — takes effect at next login"
  blib_ok "Offense bootstrap complete — for this session: exec zsh"
else
  blib_ok "Offense bootstrap complete — open a new shell, or: exec zsh"
fi
