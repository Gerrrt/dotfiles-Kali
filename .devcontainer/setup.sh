#!/usr/bin/env bash
# .devcontainer/setup.sh — provision the instant-on Kali Codespace.
# ──────────────────────────────────────────────────────────────────────────────
# Lean by design: a small modern-CLI toolset + starship, then `bootstrap.sh
# --links-only` (Core + the offensive role layer + zsh as the shell; NO apt package
# stack). The cheatsheets and field helpers are the demo — for the full engagement
# tool stack run `./bootstrap.sh --install` inside the running container.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> apt: lean modern-CLI toolset"
apt-get update -qq
# Critical for the shell to come up at all — fail loudly if these don't install.
apt-get install -y --no-install-recommends \
  zsh git tmux curl ca-certificates less
# Nice-to-have CLIs that Core's aliases light up when present — best-effort, since Core
# degrades gracefully for anything missing. stderr stays VISIBLE (an apt lock / repo error
# should be diagnosable in a broken Codespace), with a concise note if the set can't be
# installed. (Debian/Kali rename bat->batcat, fd-find->fdfind; Core's 00-tools.zsh resolves both.)
apt-get install -y --no-install-recommends fzf ripgrep bat fd-find eza neovim jq ||
  echo "   note: some optional CLIs were unavailable — the shell still works (Core skips missing tools)"

echo "==> starship prompt (distro package)"
# From apt, NOT a piped remote installer (no `curl | sh`): Kali/Debian ship starship. If
# it's absent here the prompt just falls back to plain zsh; `./bootstrap.sh --install` uses
# the upstream installer. Kept on its own line so its absence can't sink the CLIs above.
apt-get install -y --no-install-recommends starship ||
  echo "   note: starship unavailable via apt here — prompt falls back to plain zsh"

echo "==> wiring dotfiles (Core + offensive role layer, no package install)"
# BLIB_SU= : run the privilege steps (chsh + appending /etc/shells) directly as root. This
# container runs as root and has no sudo, but blib_set_login_shell defaults BLIB_SU=sudo —
# which would fail with "sudo: command not found" and (under set -e) abort the wiring. This
# is the same setting the reusable bootstrap-test workflow passes (-e BLIB_SU=) to its
# distro containers.
export BLIB_SU=
# --links-only skips the host-tool probe (nothing installs without --install anyway)
# but runs wire_links:
# Core via blib_link_core, the offensive symlinks (hacktheplanet/exploitdev/evasion/ippsec
# + offensive.zsh), the offensive loader stage, and chsh to zsh.
./bootstrap.sh --links-only

cat <<'EOF'

  ✔ dotfiles-Offense is wired. Open a NEW terminal (it starts in zsh) and try:

      htp     hack-the-planet cheatsheet        ipp     the IppSec method
      xdev    exploit-dev companion             evade   defense-evasion
      lhost   your attacker / VPN IP            ttyup   stabilize a dumb shell
      note    timestamped engagement log        mkengagement   scope-first workspace

  Full engagement tool stack (heavy, optional):  ./bootstrap.sh --install
EOF
