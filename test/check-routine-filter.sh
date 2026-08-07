#!/usr/bin/env bash
# test/check-routine-filter.sh — does the routine filer still catch a BLOCKED run?
# ──────────────────────────────────────────────────────────────────────────────
# .github/workflows/file-routine-issue.sh has to tell three things apart: genuine
# findings, a run the model API blocked at the cybersecurity safety filter, and any other
# failed run. It got that wrong once already. The original guard matched the July-2026
# refusal wording with a single grep (issue #112); the API reworded the refusal (issue
# #177); the grep went blind; the raw API error was filed under the NORMAL findings title,
# where it then DEDUPED into the findings issue because the advisory title suffix never
# applied. Nothing went red — a human reading the issue is what caught it. This is the
# gate that catches it next time.
#
# It drives the REAL script end-to-end instead of re-testing a copy of its pattern: a
# copied regex IS the drift this exists to prevent, and half the bug lived in the
# COMPOSITION (the title — i.e. the dedup key), which a pattern test cannot see. The
# harness is a stub `gh` on PATH plus RUNNER_TEMP pointed at a scratch dir, so the helper
# runs exactly as claude-routines.yml runs it while touching no network and needing no
# GH_TOKEN.
#
# Cases — the two refusals are VERBATIM from the real incidents:
#   1. #112 (Jul 2026) "…safety measures that flagged this message for a cybersecurity
#      topic…"                                                   → BLOCKED advisory
#   2. #177 (Aug 2026) "…safeguards flagged this message… Cyber Verification Program…",
#      the reword that broke the old grep                        → BLOCKED advisory
#   3. a genuine multi-section report that QUOTES #112's wording in its prose — the trap
#      the shape-before-signal split exists for                  → normal findings title
#   4. a bare `Execution error` — the non-cyber failure branch   → FAILED advisory
#
# Exit codes (matching this repo's check-script convention — see
# test/check-companion-freshness.sh):
#   0  every case passed, OR a graceful skip (helper absent, no mktemp)
#   1  a case FAILED — the classifier or the composed title/body regressed
# There is deliberately no exit-2 "drift" state here: a red case is a bug, not a nudge, so
# the workflow can treat this as an ordinary pass/fail gate.
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

HELPER=".github/workflows/file-routine-issue.sh"
# The real ISSUE_TITLE from claude-routines.yml's methodology-review job, so the helper's
# `${title%%:*}` slug logic is exercised against a title that actually ships.
BASE_TITLE="methodology-review: weekly offensive-docs tooling audit"

# Palette + glyphs from the VENDORED shared bash UX lib (core/lib/ux.sh) — ONE colour/glyph
# rule instead of hand-rolled copies that drift. If core/ is incomplete the lib won't be
# readable, so fall back to no colour and ASCII glyphs rather than fail to source it.
if [[ -r "$REPO/core/lib/ux.sh" ]]; then
  # shellcheck source=/dev/null
  source "$REPO/core/lib/ux.sh"
  c_g=$UX_GRN c_y=$UX_YEL c_r=$UX_RED c_0=$UX_RST
else
  c_g='' c_y='' c_r='' c_0=''
fi
# ASCII fallbacks when ux.sh is absent; when it's present these are already the
# locale-correct glyph, so := leaves them be.
: "${UX_OK:=ok}" "${UX_WARN:=!}" "${UX_ERR:=x}" "${UX_INFO:=-}"

skip() {
  printf '%s%s%s %s\n' "$c_y" "$UX_INFO" "$c_0" "$*"
  exit 0
}

# A partial checkout has no helper to exercise — skip cleanly rather than red a tree that
# simply doesn't carry the file.
[[ -r "$HELPER" ]] || skip "check-routine-filter: no $HELPER (not a full checkout?)"
command -v mktemp >/dev/null 2>&1 || skip "check-routine-filter: mktemp unavailable"

TMP="$(mktemp -d)" || {
  printf '%s%s%s check-routine-filter: mktemp -d failed\n' "$c_r" "$UX_ERR" "$c_0" >&2
  exit 1
}
trap 'rm -rf "$TMP"' EXIT

# ── harness ───────────────────────────────────────────────────────────────────
# Stub gh(1). The helper's last act is `gh issue create --title … --body-file …`, and the
# COMPOSED TITLE exists only in that argv — so record argv one arg per line and let the
# assertions read the line after `--title` (the dedup probe's argv carries no bare
# `--title`, so there's no ambiguity). `gh issue list` prints nothing on stdout, so the
# helper always sees "no existing issue" and takes the create path. No network, no token.
mkdir -p "$TMP/bin"
cat >"$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >>"$GH_STUB_LOG"
exit 0
STUB
chmod +x "$TMP/bin/gh"
PATH="$TMP/bin:$PATH"
export PATH GH_STUB_LOG="$TMP/gh-argv.log"
# The helper composes into $RUNNER_TEMP/routine-issue-body.md — point that at the scratch
# dir so the body can be read back (and so a real /tmp is never written).
export RUNNER_TEMP="$TMP"

fail=0
ok() { printf '%s%s%s %s\n' "$c_g" "$UX_OK" "$c_0" "$*"; }
bad() {
  printf '%s%s%s %s\n' "$c_r" "$UX_ERR" "$c_0" "$*" >&2
  fail=1
}

# run_case <label> <report> <expected-title-suffix> <warning: yes|no> [body-needle …]
#   expected-title-suffix  '' means "must stay the bare findings title"
#   body-needle            literal substring that MUST appear; prefix with ! for MUST NOT
run_case() {
  local label="$1" report="$2" want_suffix="$3" want_warn="$4"
  shift 4
  local rc=0 out title want needle body="$TMP/routine-issue-body.md"

  : >"$GH_STUB_LOG"
  rm -f "$body"
  out="$(bash "$HELPER" "$BASE_TITLE" "$report" 2>&1)" || rc=$?

  # Green-always posture: a blocked run is REPORTED, never failed. A non-zero here would
  # red the whole claude-routines workflow on a block — the opposite of the design.
  [[ $rc -eq 0 ]] || bad "$label: helper exited $rc (must stay green)"

  # The title is the dedup key. This assertion is the actual regression guard: with the
  # old single grep, case 2 produced the BARE title and silently deduped into findings.
  title="$(awk '$0 == "--title" { getline; print; exit }' "$GH_STUB_LOG")"
  want="$BASE_TITLE$want_suffix"
  if [[ "$title" == "$want" ]]; then
    if [[ -n "$want_suffix" ]]; then
      ok "$label: title is \"…$want_suffix\""
    else
      ok "$label: title stays unsuffixed (dedups as findings — correct)"
    fi
  else
    bad "$label: wrong issue title"
    printf '      want: %s\n      got:  %s\n' "$want" "${title:-<no gh issue create seen>}" >&2
  fi

  case "$want_warn" in
  yes) grep -q '::warning::' <<<"$out" || bad "$label: no ::warning:: annotation for a failed run" ;;
  no) grep -q '::warning::' <<<"$out" && bad "$label: unexpected ::warning:: — a genuine report files quietly" ;;
  esac

  if [[ ! -s "$body" ]]; then
    bad "$label: helper composed no body at $body"
    return
  fi
  for needle in "$@"; do
    case "$needle" in
    '!'*) grep -qF -- "${needle#!}" "$body" && bad "$label: body contains text it must NOT: ${needle#!}" ;;
    *) grep -qF -- "$needle" "$body" || bad "$label: body is missing: $needle" ;;
    esac
  done
}

# ── fixtures ──────────────────────────────────────────────────────────────────
# Quoted heredocs ('EOF'): the fixtures carry backticks, $ and quotes and must land on
# disk byte-for-byte as the API emitted them.
cat >"$TMP/report-112.md" <<'EOF'
API Error: Opus 4.8 has safety measures that flagged this message for a cybersecurity topic. If your work requires this access, you can apply for an exemption: https://claude.com/form/cyber-use-case
EOF

cat >"$TMP/report-177.md" <<'EOF'
API Error: Sonnet 5's safeguards flagged this message. Our intentionally broad safeguards allow us to deliver more capabilities faster, but can sometimes flag legitimate cybersecurity work. Apply to the Cyber Verification Program to reduce these interruptions. Learn more: https://support.claude.com/en/articles/14604842-real-time-cyber-safeguards-on-claude
EOF

# A real report — and an ADVERSARIAL one: its last section quotes #112's wording on a
# single line, which the OLD signal-only grep matched. Signal alone would misfile these
# genuine findings as a block; the shape gate (first non-blank line is markdown, not
# `API Error:`) is the only thing that keeps this a normal findings issue.
cat >"$TMP/report-genuine.md" <<'EOF'
## methodology-review — findings

### 1. Deprecated flag in `offensive/hacktheplanet`

`nmap --script-updatedb` is documented as a warm-up step; the packaged nmap
regenerates the script DB on demand, so the line is noise.

### 2. Renamed binary

`nuclei -t cves/` should be `nuclei -t http/cves/` — the template tree moved and
install/offensive-packages.txt already carries the new name.

### 3. Nothing to carry over

Last week the run was blocked upstream ("safety measures that flagged this message for a cybersecurity topic"); this run completed, so there is no backlog.

_No changes made — report-first._
EOF

# The non-cyber failure branch: same SHAPE, no cyber SIGNAL.
cat >"$TMP/report-execerror.md" <<'EOF'
Execution error: the model stream ended unexpectedly after 0 tokens (503 upstream)
EOF

# ── cases ─────────────────────────────────────────────────────────────────────
run_case '#112 wording (Jul 2026)' "$TMP/report-112.md" ' — BLOCKED (cyber-safety filter)' yes \
  'https://claude.com/form/cyber-use-case' \
  'https://support.claude.com/en/articles/14604842-real-time-cyber-safeguards-on-claude' \
  'Run-status advisory, not findings.'

run_case '#177 reword (Aug 2026)' "$TMP/report-177.md" ' — BLOCKED (cyber-safety filter)' yes \
  'https://claude.com/form/cyber-use-case' \
  'https://support.claude.com/en/articles/14604842-real-time-cyber-safeguards-on-claude' \
  'Run-status advisory, not findings.'

run_case 'genuine report (quotes #112 in prose)' "$TMP/report-genuine.md" '' no \
  '### 2. Renamed binary' \
  'Report-first: review and act' \
  '!Run-status advisory' \
  '!BLOCKED'

run_case 'generic run failure' "$TMP/report-execerror.md" ' — FAILED (run error)' yes \
  '### Triage' \
  '!https://claude.com/form/cyber-use-case'

if [[ $fail -eq 0 ]]; then
  printf '%s%s%s check-routine-filter: all cases passed (%s)\n' "$c_g" "$UX_OK" "$c_0" "$HELPER"
  exit 0
fi
# shellcheck disable=SC2016  # the backticks and `$cyber_signal` name it points at are
# literal — this is a pointer to the code to edit, not an expansion.
{
  printf '%s%s%s check-routine-filter: the routine filer misclassifies at least one run\n' "$c_r" "$UX_ERR" "$c_0"
  printf '    the classifier is `classify_report` in %s\n' "$HELPER"
  printf '    shape:  first non-blank line begins `API Error:` / `Execution error`\n'
  printf '    signal: the $cyber_signal anchor set (broaden it, then add the fixture here)\n'
} >&2
exit 1
