#!/usr/bin/env bash
# tmux-eng.sh — fuzzy-find an engagement and create/switch to its tmux session.
# The offensive-layer twin of Core's tmux-sesh.sh.
# Bound to: prefix + e   (in dotfiles-Offense offensive/offensive.conf, the role layer)
#
# Switch-only by design: NEW engagements are created with `mkengagement` in a
# shell (it opens scope/scope.txt in your editor first). This popup just gets you
# back into an existing one fast. The session is rooted at the engagement dir and
# its $ENGAGEMENT env var is set, so `bhce` / `logshell` target the right tree.

# Fail fast on errors, unset vars, and broken pipes. Two commands are expected to
# return non-zero: the close-prompt read on EOF (guarded with `|| true`), and fzf
# when the operator cancels the picker — for that one we capture the exit code and
# treat only fzf's cancel statuses (1 = no match, 130 = ESC) as graceful, so any
# other failure (e.g. 127 = fzf not installed) still surfaces instead of masking.
set -euo pipefail

# Honor the env if the shell exported it; else fall back to the Core default.
ENGAGEMENTS_DIR="${ENGAGEMENTS_DIR:-$HOME/engagements}"

if [[ ! -d "$ENGAGEMENTS_DIR" ]]; then
	echo "No engagements dir at $ENGAGEMENTS_DIR — run 'mkengagement <name>' first."
	read -r -p "Press enter to close…" _ || true
	exit 0
fi

# Resolve the pager BEFORE baking it into fzf's preview string: fzf runs that string in a
# subshell, so the binary name has to be real there. Debian/Kali ship bat as `batcat` (the
# name clash CLAUDE.md warns about), and the literal `bat` this used to carry silently fell
# through to the eza branch on every box — so the scope sheet this popup exists to show
# never appeared. Core hits the same trap in 35-fzf.zsh and fixes it with $BAT_BIN, but
# that's a zsh var this bash script can't see, so resolve it here with the same precedence.
if command -v bat >/dev/null 2>&1; then
	pager="bat --color=always --style=plain"
elif command -v batcat >/dev/null 2>&1; then
	pager="batcat --color=always --style=plain"
else
	pager="cat"
fi

# Newest first; preview the scope sheet (the thing you actually want to see).
selected=$(find "$ENGAGEMENTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
	sort -r |
	fzf \
		--prompt="Engagement ❯ " \
		--preview="$pager {}/scope/scope.txt 2>/dev/null || eza --icons --tree --level=1 {}" \
		--preview-window="right:55%:wrap:border-left") || rc=$?

# fzf exits 130 (ESC) or 1 (no match) on a normal operator cancel — treat those as
# a graceful no-op. Any other non-zero (e.g. 127 = fzf not installed) is a real
# failure and should surface rather than silently exit 0 with an empty selection.
rc=${rc:-0}
if ((rc != 0 && rc != 1 && rc != 130)); then
	echo "tmux-eng: picker failed (exit $rc)" >&2
	exit "$rc"
fi

[[ -z "$selected" ]] && exit 0

# Session name from the dir basename (already date-prefixed by mkengagement).
session_name=$(basename "$selected" | tr '[:upper:] .' '[:lower:]__')

if ! tmux has-session -t "$session_name" 2>/dev/null; then
	tmux new-session -ds "$session_name" -c "$selected"
	# Make $ENGAGEMENT available to panes/windows opened in this session.
	tmux set-environment -t "$session_name" ENGAGEMENT "$selected"
fi

tmux switch-client -t "$session_name"
