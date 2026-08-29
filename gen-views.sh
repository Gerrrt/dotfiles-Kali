#!/usr/bin/env bash
# offensive/companion/gen-views.sh — render entry-backed blocks into the flat views.
# ──────────────────────────────────────────────────────────────────────────────
# The source-of-truth bridge. The structured `entries/` are CANONICAL for the
# paired red<->blue attack/detection slice; the flat field references
# (`PURPLE-TEAM.md`, later `hacktheplanet`) stay canonical for everything else —
# the tradecraft prose, dorks, sequencing, warnings that don't fit the entry
# schema. Where the two OVERLAP, this script makes the entry win: it regenerates
# the marked blocks in the flat file FROM the entry, so the overlap can't drift.
#
# A flat file opts a block in with a marker pair naming the entry id, in the host
# file's comment style — HTML for markdown, `#` for the shell-style hacktheplanet:
#
#     <!-- companion:gen kerberoasting-4769 -->   (PURPLE-TEAM.md, a blue detection)
#     …generated from entries/blue/kerberoasting-4769.md…
#     <!-- companion:end kerberoasting-4769 -->
#
#     # companion:gen kerberoast-getuserspns      (hacktheplanet, a red attack)
#     …generated from entries/red/kerberoast-getuserspns.md…
#     # companion:end kerberoast-getuserspns
#
# Anything OUTSIDE the markers is hand-authored and never touched.
#
#   gen-views.sh            # rewrite every marked block in place from its entry
#   gen-views.sh --check    # exit 1 (with a diff) if any block is out of date
#
# --check is the drift gate (CI runs it); the bare form is what you run after
# editing an entry. The render shape is keyed off the entry's colour: a BLUE entry
# renders as `**title**` + prose + a fenced ```spl detection; a RED entry renders
# as its raw command lines with the `{{slot}}` placeholders reverse-mapped to
# hacktheplanet's `<angle-bracket>` house style (see SLOT_TO_ANGLE).
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
ENTRIES="$HERE/entries"
REPO="$(cd -- "$HERE/../.." && pwd)"

# The flat files that carry generated blocks (paths relative to the repo root).
# PURPLE-TEAM.md takes blue detections (HTML markers); hacktheplanet takes red
# attacks (`#` markers). HOST-AGNOSTIC: this list is the default for the Offense host,
# but a consumer can override it via $COMPANION_TARGETS (space/newline-separated,
# repo-root-relative) — so the same script works when this dir is vendored into a
# different repo, or runs standalone (no flat views) where it simply finds nothing
# to do. A listed target that doesn't exist on disk is SKIPPED with a notice rather
# than failing, which is what makes the standalone case green.
if [[ -n "${COMPANION_TARGETS:-}" ]]; then
  # honor both space- and newline-separated lists (fold newlines to spaces first)
  read -r -a TARGETS <<<"${COMPANION_TARGETS//$'\n'/ }"
else
  TARGETS=("PURPLE-TEAM.md" "offensive/hacktheplanet")
fi

CHECK=0
[[ "${1:-}" == "--check" ]] && CHECK=1

# Reverse of the normalization the corpus applies: the entries store target params
# as {{slots}}; hacktheplanet's house style is <angle-bracket> tokens. This sed
# program (ERE) maps every slot back to the exact token that file already uses, so
# a generated red block is byte-identical to the hand-written command it replaces.
SLOT_TO_ANGLE='
  s/\{\{rhost\}\}/<ip_address>/g
  s/\{\{lhost\}\}/<your-ip>/g
  s/\{\{domain\}\}/<domain>/g
  s/\{\{user\}\}/<user>/g
  s/\{\{password\}\}/<password>/g
  s/\{\{hostname\}\}/<hostname>/g
  s/\{\{nthash\}\}/<NThash>/g
  s/\{\{port\}\}/<port>/g
  s/\{\{share\}\}/<share>/g
'

# entry_for_id <id> — print the path of the ONE entry whose frontmatter id == <id>.
# Fails (non-zero, with a clear message naming the paths) on zero or multiple
# matches, so a typo or a duplicate id can never silently regenerate the wrong
# block. Callers must invoke it in a conditional (`if ! ef=$(entry_for_id …)`) so
# the failure is visible under `set -e` (a bare `ef=$(…)` assignment swallows it).
entry_for_id() {
  local id="$1" matches n
  matches="$(grep -rl "^id:[[:space:]]*$id\$" "$ENTRIES" 2>/dev/null || true)"
  n="$(printf '%s' "$matches" | grep -c . || true)"
  if [[ "$n" -eq 0 ]]; then
    echo "gen-views: no entry with id '$id'" >&2; return 1
  elif [[ "$n" -gt 1 ]]; then
    echo "gen-views: duplicate id '$id' across multiple entries:" >&2
    printf '%s\n' "$matches" | sed 's/^/  /' >&2; return 1
  fi
  printf '%s\n' "$matches"
}

# render_blue <entry-file> — the markdown block PURPLE-TEAM.md shows for a blue
# detection: the bold title, the body prose, the fenced detection, then any
# trailing note (e.g. a "Tighter:" follow-up after the query). One awk pass; reads
# only the first frontmatter block for the title and treats the FIRST fenced block
# as the query, so a stray ``` or key: in the body can't confuse it. Content before
# the fence is prose, content after it is the tail.
render_blue() {
  awk '
    /^---[[:space:]]*$/ { fm++; if (fm == 2) stage = 1; next }
    fm == 1 { if (index($0, "title:") == 1) { t = $0; sub(/^title:[[:space:]]*/, "", t) } next }
    stage == 1 && /^```/ { stage = 2; next }
    stage == 2 && /^```/ { stage = 3; next }
    stage == 1 { prose = prose $0 "\n" }
    stage == 2 { spl = spl $0 "\n" }
    stage == 3 { tail = tail $0 "\n" }
    END {
      gsub(/^\n+/, "", prose); gsub(/\n+$/, "", prose)
      gsub(/\n+$/, "", spl)
      gsub(/^\n+/, "", tail); gsub(/\n+$/, "", tail)
      if (tail != "")
        printf "**%s**\n\n%s\n\n```spl\n%s\n```\n\n%s\n", t, prose, spl, tail
      else
        printf "**%s**\n\n%s\n\n```spl\n%s\n```\n", t, prose, spl
    }
  ' "$1"
}

# render_red <entry-file> — what hacktheplanet shows for a red attack: just the raw
# command lines (its house style is command-first, terse, no prose/fence), with the
# entry's {{slot}} placeholders reverse-mapped to hacktheplanet's <angle-bracket>
# vocabulary. The attack's surrounding `# comment:` header and any extra recon lines
# stay hand-authored OUTSIDE the markers — the entry owns only its own commands.
render_red() {
  # extract the FIRST fenced block (the commands), then reverse-map the slots.
  awk '/^```/ { c++; next } c == 1 { print }' "$1" | sed -E "$SLOT_TO_ANGLE"
}

# marker_id <kind> <line> — echo the id if <line> is a `companion:<kind>` marker in
# EITHER comment style (HTML `<!-- … -->` or shell `# …`), else return non-zero.
# kind is gen|end. Keeps build_file agnostic to the host file's comment syntax.
marker_id() {
  local kind="$1" line="$2"
  if [[ "$line" =~ ^\<!--\ companion:$kind\ ([a-z0-9-]+)\ --\>$ ]]; then printf '%s' "${BASH_REMATCH[1]}"; return 0; fi
  if [[ "$line" =~ ^#\ companion:$kind\ ([a-z0-9-]+)$ ]]; then printf '%s' "${BASH_REMATCH[1]}"; return 0; fi
  return 1
}

# render_for <entry-file> — dispatch on the entry's colour (which dir it lives in).
render_for() {
  case "$1" in
    */entries/red/*) render_red "$1" ;;
    */entries/blue/*) render_blue "$1" ;;
    *) echo "gen-views: cannot tell colour (red/blue) of entry $1" >&2; return 2 ;;
  esac
}

# build_file <flat-file> — emit the file with every marked block regenerated.
build_file() {
  local file="$1" line id ef
  while IFS= read -r line || [[ -n "$line" ]]; do
    if id="$(marker_id gen "$line")"; then
      printf '%s\n' "$line"                       # keep the opening marker verbatim
      # Conditional call so entry_for_id's failure surfaces under `set -e`; it has
      # already printed the specific reason (missing / duplicate id).
      if ! ef="$(entry_for_id "$id")"; then
        echo "gen-views: ^ referenced by a companion:gen marker in $file" >&2; return 2
      fi
      render_for "$ef" || return 2
      # consume the old block up to and including its end marker
      local found=0 l2 endid
      while IFS= read -r l2; do
        if endid="$(marker_id end "$l2")"; then
          [[ "$endid" == "$id" ]] || { echo "gen-views: marker mismatch: gen '$id' closed by end '$endid' in $file" >&2; return 2; }
          printf '%s\n' "$l2"; found=1; break
        fi
      done
      [[ "$found" == 1 ]] || { echo "gen-views: unterminated 'companion:gen $id' region in $file" >&2; return 2; }
    else
      printf '%s\n' "$line"
    fi
  done < "$file"
}

rc=0
for t in "${TARGETS[@]}"; do
  file="$REPO/$t"
  # A configured target that isn't present is skipped, not fatal — so a standalone
  # checkout (just entries + this script, no flat views) passes cleanly. In a host
  # that DOES ship the flat file, it exists, so it's always checked.
  [[ -f "$file" ]] || { echo "gen-views: target not present, skipping: $t" >&2; continue; }
  if ! grep -qE '^(<!-- |# )companion:gen ' "$file"; then
    echo "gen-views: $t has no companion:gen markers — skipping" >&2
    continue
  fi
  generated="$(build_file "$file")" || { rc=$?; continue; }
  if [[ "$CHECK" == 1 ]]; then
    if ! diff -u "$file" <(printf '%s\n' "$generated") >/dev/null; then
      echo "gen-views: DRIFT in $t — a generated block is out of date with its entry:" >&2
      diff -u "$file" <(printf '%s\n' "$generated") | sed 's/^/  /' >&2 || true
      echo "  fix: run offensive/companion/gen-views.sh and commit the result." >&2
      rc=1
    else
      echo "gen-views: $t up to date"
    fi
  else
    printf '%s\n' "$generated" > "$file"
    echo "gen-views: regenerated $t"
  fi
done
exit "$rc"
