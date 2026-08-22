#!/usr/bin/env bash
# Install htpx standalone (no dotfiles required). Writes a thin wrapper script into ~/.local/bin (ensure it's on your PATH)
# so htpx resolves its entries/ relative to this checkout.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
BIN="${HOME}/.local/bin"
mkdir -p "$BIN"
cat >"$BIN/htpx" <<EOF
#!/usr/bin/env bash
exec "$REPO/htpx" "\$@"
EOF
chmod +x "$BIN/htpx"
echo "installed: $BIN/htpx -> $REPO/htpx"
echo "ensure $BIN is on your PATH; deps: fzf (required), bat + a clipboard tool (optional)"
