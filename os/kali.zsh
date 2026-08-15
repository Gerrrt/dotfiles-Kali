# dotfiles-Kali/os/kali.zsh  ->  ~/.config/zsh/80-os.zsh  (v4: numbered OS-layer fragment)
# Kali (Debian/apt) OS-native shell layer. Loaded AFTER Core, BEFORE offensive.
# Built for WSL2: clipboard rides Core's clip (clip.exe), GUI via WSLg.
[[ $- == *i* ]] || return 0

# ~/.local/bin is NOT prepended here: Core's 00-tools.zsh already does it, and Core
# loads before this fragment (band 00 vs 80). The duplicate was a verbatim copy of
# that line — harmless, but it made the OS layer look like the owner of a Core
# concern. ~/.cargo/bin and ~/.atuin/bin below are genuinely not Core's today.
[[ -d "$HOME/.cargo/bin" && ":$PATH:" != *":$HOME/.cargo/bin:"* ]] && export PATH="$HOME/.cargo/bin${PATH:+:$PATH}"
# ~/.atuin/bin — legacy prefix. bootstrap.sh now installs the pinned atuin release
# into ~/.local/bin, but a box bootstrapped before that change has atuin at the
# path setup.atuin.sh hardcodes, and nothing else puts it on PATH. Without this
# line Core's HAVE_ATUIN probe never fires there and history silently stops.
[[ -d "$HOME/.atuin/bin" && ":$PATH:" != *":$HOME/.atuin/bin:"* ]] && export PATH="$HOME/.atuin/bin${PATH:+:$PATH}"

_IS_WSL=0
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  _IS_WSL=1
elif [[ -r /proc/version ]]; then
  # zsh reads the file directly (no grep/cat fork) — WSL kernels tag /proc/version.
  _pv="$(</proc/version)"; _pv=${_pv:l}
  [[ "$_pv" == *microsoft* || "$_pv" == *wsl* ]] && _IS_WSL=1
  unset _pv
fi

# clipboard -> Core's cross-OS scripts (under WSL these call clip.exe / Get-Clipboard)
command -v clip       >/dev/null && alias pbcopy='clip'
command -v clip-paste >/dev/null && alias pbpaste='clip-paste'

# ── tool completions / shell hooks (parity with the other os layers) ─────────
# direnv/gh emit DETERMINISTIC scripts (the generated hook/completion TEXT is static for a
# given binary; only the runtime hooks vary per-dir/-shell), so route them through Core's
# _cache_eval (00-tools.zsh) — one cheap `source` of a cached file instead of forking each
# generator on EVERY interactive shell. _cache_eval self-guards on the binary being present
# and regenerates only when it's newer than the cache. Falls back to the eager eval if
# this OS layer is sourced without Core's 00-tools.zsh — the fallback
# keeps direnv's stderr visible, while the cached path suppresses the generator's
# stderr (as _cache_eval does); direnv's per-dir runtime warnings are unaffected.
if (( $+functions[_cache_eval] )); then
  _cache_eval direnv direnv hook zsh
  _cache_eval gh gh completion -s zsh
else
  command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
  command -v gh >/dev/null 2>&1 && eval "$(gh completion -s zsh 2>/dev/null)"
fi

# dotsync — jump to THIS checkout, wherever it lives. `${0:A}` resolves the symlink
# ~/.config/zsh/80-os.zsh back to <repo>/os/kali.zsh, so :h:h is the repo root. The
# old form hardcoded ~/dotfiles-Kali, which matched the README's clone command and
# nothing else — on any other checkout path the alias silently cd'd nowhere.
DOTFILES_KALI="${${0:A}:h:h}"
[[ -d "$DOTFILES_KALI" ]] || DOTFILES_KALI="$HOME/dotfiles-Kali"   # last-resort fallback
export DOTFILES_KALI
alias dotsync='cd "$DOTFILES_KALI"'
command -v op >/dev/null 2>&1 && alias opsignin='eval "$(op signin)"'
alias localip='ip -brief -4 addr show scope global'

# ── apt quality-of-life ────────────────────────────────────────────────────────
alias aptu='sudo apt-get update && sudo apt-get full-upgrade -y'
alias apti='sudo apt-get install -y'
alias aptr='sudo apt-get remove'
alias apts='apt-cache search'
alias aptw='dpkg -S'          # which package owns a file / command
alias aptl='dpkg -L'          # list files a package installed
alias aptshow='apt-cache show'

# ── WSL niceties ───────────────────────────────────────────────────────────────
if (( _IS_WSL )); then
  alias open='explorer.exe'
  command -v wslview >/dev/null && alias xdg-open='wslview'
  [[ -n "${WINHOME:-}" ]] && alias cdwin='cd "$WINHOME"'
fi

unset _IS_WSL

# auto-start / attach tmux (skip inside tmux, VS Code, a non-interactive shell, or
# when KALI_NO_TMUX is set — an opt-out for scripted logins, parity with Windows'
# PSMUX_NO_AUTOLAUNCH).
if command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" && -z "${KALI_NO_TMUX:-}" && -t 1 && "$TERM_PROGRAM" != "vscode" ]]; then
  tmux attach -t main 2>/dev/null || tmux new-session -s main
fi
