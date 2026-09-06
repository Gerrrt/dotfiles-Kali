#!/usr/bin/env bash
# test/check-corpus-commands.sh
# ──────────────────────────────────────────────────────────────────────────────
# Does every command the RED CORPUS tells an operator to run actually exist?
#
# Two entries in `coerce-petitpotam` once invoked `impacket-petitpotam` and `dfscoerce`.
# Neither is a real command — PetitPotam is topotam/PetitPotam and was never an impacket
# script; DFSCoerce is a git clone with no binary on PATH. A human found them by reading
# the file, because NO GATE ON EITHER SIDE COULD:
#
#   gen-views.sh --check     byte-compares the 19 PROJECTED red blocks against their
#                            entries. 87 of 106 red entries are unprojected — invisible.
#   check-packages.sh        resolves names in install/offensive-packages.txt. It reads the
#                            MANIFEST, and has never looked at the corpus.
#   companion integrity      compares the vendored tree to companion.lock. Provenance, not
#                            content: a wrong command hashes exactly as well as a right one.
#   htpx CI (upstream)       pair: symmetry and {{slot}} coverage. Structure, not existence.
#
# Nothing in that list asks *does this command exist?* — and an unprojected entry is just
# as operational as a projected one: ~/companion is symlinked, `htpx` is a first-class
# alias, and `clip` puts the line straight on the clipboard. See dotgibson/dotfiles-Offense#208.
#
# WHAT IT DOES NOT DO. It answers "does this resolve", never "is this still the right
# flag" — `--filter-method-name Efs` vs a patched `EfsRpcOpenFileRaw` is a judgement for
# /doc-audit and /tool-scout. It is a floor, not a review.
#
# ⚠ WHEN THIS GOES RED ON A companion-sync PR, THE FIX IS USUALLY NOT HERE.
# offensive/companion/ is a vendored subtree of dotgibson/htpx; CONTRIBUTING §2 and the
# companion-integrity gate both forbid hand-editing it. A bad command in an entry is fixed
# UPSTREAM in htpx and arrives via scripts/sync-companion.sh. What lands here is either a
# manifest addition (the tool is real, we just never listed it) or a classification line in
# install/corpus-commands.lst (the tool is deliberately not on the operator's box).
#
# It reads only the tree — never apt, never the network, never the local box — so it is
# deterministic enough to be a REQUIRED check. (check-packages.sh is advisory precisely
# because it must ask apt, and kali-rolling moves under it.)
#
# Exit codes (this repo's check-script convention — see test/check-routine-filter.sh):
#   0  every command resolves, or a graceful skip (no corpus vendored here)
#   1  usage/environment failure, or a broken corpus invariant the parser relies on
#   2  an unresolved command, or a classification no entry uses any more — the drift signal
#
# Usage:
#   test/check-corpus-commands.sh                  # offensive/companion/entries/red
#   test/check-corpus-commands.sh <entries-dir>    # a fixture (disables the stale check)
#   test/check-corpus-commands.sh --self-test      # prove the #208 escapes still redden it
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
# `set -e` is deliberately off (the exit code IS the result), so guard the cd explicitly.
cd -- "$REPO_ROOT" || exit 1

if [[ -r "$REPO_ROOT/core/lib/ux.sh" ]]; then
  # shellcheck source=core/lib/ux.sh
  source "$REPO_ROOT/core/lib/ux.sh"
fi
say()  { printf '%s::%s %s\n' "${UX_BLU:-}" "${UX_RST:-}" "$*"; }
ok()   { printf '%s%s%s %s\n' "${UX_GRN:-}" "${UX_OK:-+}" "${UX_RST:-}" "$*"; }
skip() { printf '%s%s%s %s\n' "${UX_YEL:-}" "${UX_INFO:--}" "${UX_RST:-}" "$*"; exit 0; }
bad()  { printf '%s%s%s %s\n' "${UX_RED:-}" "${UX_ERR:-x}" "${UX_RST:-}" "$*" >&2; }
die()  { bad "check-corpus-commands: $*"; exit 1; }

MANIFEST="install/offensive-packages.txt"
CLASSES="install/corpus-commands.lst"
IMPACKET="install/impacket-binaries.lst"
ENTRIES_DEFAULT="offensive/companion/entries/red"

# ── extract (entry, first-token) pairs ────────────────────────────────────────
# Fence walk copied from offensive/companion/gen-views.sh render_red():
#     awk '/^```/ { c++; next } c == 1 { print }'
# Copied rather than sourced: that file lives in the vendored subtree, and its function
# also runs SLOT_TO_ANGLE, which would rewrite {{rhost}} -> <ip_address> and corrupt the
# token text we are about to compare. Extended here to record the fence LANGUAGE.
extract_tokens() { # extract_tokens <entries-dir>  -> "<file>\t<token>" on stdout
  local dir="$1" f
  for f in "$dir"/*.md; do
    [[ -e "$f" ]] || continue
    awk -v F="$f" '
      # --- fence walk -------------------------------------------------------
      /^```/ { c++; if (c == 1) lang = substr($0, 4); next }
      c != 1   { next }
      lang != "sh" { next }
      # --- heredoc body: skip to the terminator -----------------------------
      hd { if ($0 ~ "^" hdtag "[[:space:]]*$") hd = 0; next }
      match($0, /<<-?['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?/) {
        t = substr($0, RSTART, RLENGTH)
        sub(/^<<-?['"'"'"]?/, "", t); sub(/['"'"'"]$/, "", t)
        hdtag = t; hd = 1
      }
      # --- join continuations: only the FIRST physical line carries token 1 --
      cont { if ($0 !~ /\\$/) cont = 0; next }
      /\\$/ { cont = 1 }
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*$/ { next }
      {
        l = $0
        sub(/^[[:space:]]*/, "", l)
        gsub(/^[({][[:space:]]*/, "", l)
        while (1) {
          n = split(l, a, " "); t = a[1]
          # VAR=value prefix is an assignment, not a command
          if (t ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { sub(/^[^ ]+[ ]+/, "", l); continue }
          # wrappers: the wrapper IS a command too, so emit it, then unwrap.
          # a[2] !~ /^-/ keeps `sudo -l` resolving as sudo rather than as "-l".
          if ((t == "sudo" || t == "proxychains4" || t == "env" || t == "command") \
              && a[2] !~ /^-/ && n > 1) {
            print F "\t" t; sub(/^[^ ]+[ ]+/, "", l); continue
          }
          if ((t == "for" || t == "while" || t == "if" || t == "until") \
              && match(l, /;[ ]*(do|then)[ ]+/)) {
            l = substr(l, RSTART + RLENGTH); continue
          }
          break
        }
        n = split(l, a, " ")
        if (a[1] != "") print F "\t" a[1]
      }
    ' "$f"
  done
}

# ── corpus invariants the parser depends on ───────────────────────────────────
# `c == 1` silently reads garbage if an entry has more or fewer than one fence, and an
# unrecognised language would be a silent way to smuggle commands past a `sh`-only walk.
assert_invariants() { # assert_invariants <entries-dir>
  local dir="$1" f n lang rc=0
  for f in "$dir"/*.md; do
    [[ -e "$f" ]] || continue
    n="$(grep -c '^```' "$f")"
    if [[ "$n" != 2 ]]; then
      bad "$f: expected exactly 2 fence lines, found $n — the fence walk cannot be trusted"
      rc=1; continue
    fi
    lang="$(grep -m1 '^```' "$f" | sed 's/^```//')"
    case "$lang" in
      sh|powershell|cmd|sql|text|python) ;;
      *) bad "$f: unclassified fence language '${lang:-(none)}'"
         bad "    add it to the closed set in $0 — an unknown language is a silent bypass"
         rc=1 ;;
    esac
  done
  return "$rc"
}

# ── self-test: the #208 escapes must still redden this ────────────────────────
self_test() {
  local tmp out rc=0 fail=0
  tmp="$(mktemp -d)" || die "mktemp failed"
  # Disarm first: test/check-return-traps.sh is a gate in this repo.
  trap 'trap - EXIT; rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/red" || die "mkdir failed"
  # Reconstructed pre-v2.8.0 coerce-petitpotam. Built at run time rather than checked in:
  # a fixture *.md would be swept up by markdownlint via git ls-files.
  cat >"$tmp/red/coerce-petitpotam.md" <<'FIXTURE'
---
id: coerce-petitpotam
---
Reconstructed pre-v2.8.0 form: the two commands that shipped in a released corpus and
that no gate on either side could see (dotgibson/dotfiles-Offense#208).

```sh
impacket-petitpotam {{lhost}} {{rhost}}
printerbug {{domain}}/{{user}}:{{password}}@{{rhost}} {{lhost}}
dfscoerce -u {{user}} -p {{password}} -d {{domain}} {{lhost}} {{rhost}}
```
FIXTURE
  out="$("$0" "$tmp/red" 2>&1)" || rc=$?
  [[ "$rc" == 2 ]] || { bad "self-test: expected exit 2, got $rc"; fail=1; }
  grep -q 'impacket-petitpotam' <<<"$out" || { bad "self-test: did not name impacket-petitpotam"; fail=1; }
  grep -q 'dfscoerce'           <<<"$out" || { bad "self-test: did not name dfscoerce"; fail=1; }
  grep -q 'not in install/impacket-binaries.lst' <<<"$out" \
    || { bad "self-test: impacket-petitpotam was not caught by the MEMBERSHIP rule"; fail=1; }
  if grep -q 'printerbug' <<<"$out"; then
    bad "self-test: false-positived on printerbug, which resolves via pkg:krbrelayx"; fail=1
  fi
  if ((fail)); then
    printf '%s\n' "$out" >&2
    bad "self-test FAILED — the gate would not have caught #208"
    exit 1
  fi
  ok "self-test: the two #208 escapes redden the gate, printerbug still resolves."
  exit 0
}

[[ "${1:-}" == "--self-test" ]] && self_test

ENTRIES="${1:-$ENTRIES_DEFAULT}"
STALE_CHECK=1
[[ -n "${1:-}" ]] && STALE_CHECK=0   # a fixture uses a subset; unused lines are expected

[[ -d "$ENTRIES" ]] || skip "no corpus at $ENTRIES — nothing to check."
for f in "$MANIFEST" "$CLASSES" "$IMPACKET"; do
  [[ -r "$f" ]] || die "missing $f"
done

# Reuse Core's manifest parser — the SAME function bootstrap.sh feeds apt, so this
# resolves against the names that would really be installed.
# shellcheck source=core/lib/bootstrap-lib.sh
source "$REPO_ROOT/core/lib/bootstrap-lib.sh"

say "corpus: $ENTRIES"
assert_invariants "$ENTRIES" || die "corpus invariants broken (see above)"

declare -A PKG=() CLASS=() USED=()
while IFS= read -r p; do PKG["$p"]=1; done < <(blib_read_pkgs "$MANIFEST")
declare -A IMP=()
while read -r b; do [[ -n "$b" ]] && IMP["$b"]=1; done < <(grep -vE '^\s*(#|$)' "$IMPACKET")

# classification table, with the prose requirement enforced
lineno=0
while IFS= read -r line; do
  lineno=$((lineno + 1))
  [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
  cmd="${line%%[[:space:]]*}"; rest="${line#"$cmd"}"
  cls="$(awk '{print $1}' <<<"$rest")"
  why="${line#*#}"; [[ "$why" == "$line" ]] && why=""
  [[ -z "$cls" ]] && die "$CLASSES:$lineno: no class for '$cmd'"
  # #208's acceptance: whatever the allowlist excuses, it says so in a line of prose.
  if [[ ${#why} -lt 20 ]]; then
    die "$CLASSES:$lineno: '$cmd' needs a '# why' of at least 20 characters — an unexplained excuse is how #208 happened"
  fi
  CLASS["$cmd"]="$cls"
done < "$CLASSES"

# Sets REASON rather than echoing it: the caller must NOT use $( ), because command
# substitution forks a subshell and every USED[] mark made in here would be discarded —
# which would report the whole classification file as stale on every run.
REASON=""
resolve() { # resolve <token> <depth> -> 0 ok, 1 with REASON set
  local t="$1" d="${2:-0}" cls tgt
  if ((d > 1)); then REASON="classification recurses more than one level"; return 1; fi
  if [[ "$t" == impacket-* ]]; then
    [[ -n "${PKG[impacket-scripts]:-}" ]] || { REASON="impacket-scripts is not in $MANIFEST"; return 1; }
    [[ -n "${IMP[$t]:-}" ]] && return 0
    REASON="not in $IMPACKET — the impacket- prefix is not a licence, membership is"
    return 1
  fi
  [[ -n "${PKG[$t]:-}" ]] && return 0
  cls="${CLASS[$t]:-}"
  [[ -z "$cls" ]] && { REASON="unresolved: no apt package of this name, and no line in $CLASSES"; return 1; }
  USED["$t"]=1
  case "$cls" in
    pkg:*) tgt="${cls#pkg:}"
           [[ -n "${PKG[$tgt]:-}" ]] && return 0
           REASON="classified pkg:$tgt, but $tgt is not in $MANIFEST"; return 1 ;;
    repl:*) tgt="${cls#repl:}"; USED["$tgt"]=1
           resolve "$tgt" $((d + 1)) || { REASON="via $cls -> $REASON"; return 1; }; return 0 ;;
    upstream)
           grep -qwF -- "$t" "$MANIFEST" && return 0
           REASON="classified upstream, but $MANIFEST never mentions it — document the install path"; return 1 ;;
    elsewhere|base) return 0 ;;
    *)     REASON="unknown class '$cls' in $CLASSES"; return 1 ;;
  esac
}

# Read the pairs into an array FIRST: piping the loop would put it in a subshell and lose
# the USED[] marks, the same trap as $( ) above.
mapfile -t PAIRS < <(extract_tokens "$ENTRIES")

pairs=0
declare -A SEEN=()
bad_pairs=()
for pair in "${PAIRS[@]}"; do
  file="${pair%%$'\t'*}"; tok="${pair#*$'\t'}"
  [[ -n "$tok" ]] || continue
  pairs=$((pairs + 1))
  REASON=""
  if ! resolve "$tok"; then
    ent="$(basename "$file" .md)"
    # one finding per (entry, token) — an entry that invokes the same bad command three
    # times is one defect, not three
    [[ -n "${SEEN[$ent|$tok]:-}" ]] && continue
    SEEN["$ent|$tok"]=1
    bad_pairs+=("$ent|$tok|$REASON")
  fi
done

ntok="$(printf '%s\n' "${PAIRS[@]}" | cut -f2 | sort -u | grep -c .)"
say "$pairs command invocations, $ntok distinct commands"

# an excuse nobody uses any more is rot
stale=()
if ((STALE_CHECK)); then
  for c in "${!CLASS[@]}"; do [[ -z "${USED[$c]:-}" ]] && stale+=("$c"); done
fi

echo
if ((${#bad_pairs[@]} == 0)) && ((${#stale[@]} == 0)); then
  ok "every corpus command resolves ($ntok distinct, across $pairs invocations)."
  exit 0
fi

if ((${#bad_pairs[@]})); then
  bad "${#bad_pairs[@]} corpus command(s) resolve to nothing:"
  for e in "${bad_pairs[@]}"; do
    IFS='|' read -r ent tok why <<<"$e"
    printf '    %-28s %-22s %s\n' "$tok" "($ent)" "$why" >&2
  done
fi
if ((${#stale[@]})); then
  bad "${#stale[@]} classification(s) in $CLASSES that no entry uses any more:"
  printf '    %s\n' "${stale[@]}" >&2
fi

cat >&2 <<'EOF'

An unresolved command is one of:
  • a tool that is real but was never listed — add it to install/offensive-packages.txt
  • a tool that is real but not in apt      — add it there as an `# X → UPSTREAM (...)`
                                               line, then classify it `upstream` here
  • a binary whose package has another name — classify it `pkg:<apt-name>` here
  • a thing that runs on the TARGET, not on the operator's box — classify it `elsewhere`
  • a command that does not exist at all    — fix the ENTRY, and note that
                                               offensive/companion/ is a vendored subtree:
                                               the fix lands UPSTREAM in dotgibson/htpx and
                                               arrives via scripts/sync-companion.sh
A stale classification means the entry that needed it is gone — delete the line.
EOF
exit 2
