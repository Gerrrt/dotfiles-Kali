#!/usr/bin/env bash
# .github/workflows/file-routine-issue.sh
# ──────────────────────────────────────────────────────────────────────────────
# File a Claude routine's report as a DEDUPLICATED GitHub issue: if an open issue
# with the given title already exists, append the report as a comment; otherwise
# open a new one. Keeps a weekly bot from stacking duplicate issues. Invoked by
# .github/workflows/claude-routines.yml via `bash …` (so it needs no exec bit).
# (Mirrors dotfiles-core/dotfiles-Defense's helper of the same name — the offensive
# role layer carries its own copy; core/ is vendored read-only and its scripts/ is
# not on PATH here.)
#
# Usage: file-routine-issue.sh <issue-title> <report-file>
# Requires: gh (preinstalled on GitHub runners) + GH_TOKEN in the environment.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

title="${1:?usage: file-routine-issue.sh <title> <report-file>}"
report="${2:?usage: file-routine-issue.sh <title> <report-file>}"

if [ ! -s "$report" ]; then
  echo "::warning::routine produced an empty report ($report) — nothing to file"
  exit 0
fi

# Compose the issue body: a dated heading, the report, and a report-first footer.
body="${RUNNER_TEMP:-/tmp}/routine-issue-body.md"
{
  printf '## %s — %s\n\n' "$title" "$(date -u +%Y-%m-%d)"
  cat "$report"
  printf '\n_Filed by the claude-routines workflow. Report-first: review and act — nothing was changed._\n'
} >"$body"

# ──────────────────────────────────────────────────────────────────────────────
# Run-status classification: SHAPE first, then SIGNAL.
#
# The model API can refuse a routine's request outright — a REQUEST-level error, not
# findings. Filed verbatim, that once masqueraded as a real report (an "audit" whose only
# content was the error — issue #112). The guard added then matched that July-2026 wording
# with a single grep; the API later REWORDED the refusal (issue #177 — "…safeguards
# flagged this message…"), the grep went blind, and the raw error was filed under the
# normal findings title again — where it also DEDUPED into the findings issue, because the
# advisory title suffix never applied. Refusal prose churns; the SHAPE of a failed run
# does not. So:
#
#   SHAPE  — is this a failed run at all? The CLI prints request-level errors RAW, so a
#            failure BEGINS with `API Error:` / `Execution error`; a genuine report is
#            markdown and never does. Testing the FIRST non-blank line — not "anywhere in
#            the file" — also fixes the opposite defect the old grep had: a real report
#            that merely QUOTES an API error was matched and misfiled as a block, which a
#            doc-hygiene report legitimately does when it mentions last week's run.
#   SIGNAL — given a failure, is it the cyber filter? Deliberately broad and multi-anchor:
#            the nouns both wordings share, plus the two links. URLs and programme names
#            outlive the sentences around them.
#
# Anything else is a generic run failure. Either way we file a clearly-labelled advisory
# under a DISTINCT title — distinct from the findings title AND from the other advisory,
# so nothing can ever dedup across the three — then warn, but stay green (exit 0),
# matching the preflight no-op posture. Nothing in the repo is ever edited.
# test/check-routine-filter.sh is the regression gate on all of this.
# ──────────────────────────────────────────────────────────────────────────────

# Every anchor below was observed in a REAL block; they overlap on purpose, so a reword
# that drops one still trips another (ERE, matched case-insensitively):
#   #112, Jul 2026: "…has safety measures that flagged this message for a cybersecurity
#                    topic… apply for an exemption: …/form/cyber-use-case"
#   #177, Aug 2026: "…safeguards flagged this message… Apply to the Cyber Verification
#                    Program… …/real-time-cyber-safeguards-on-claude"
cyber_signal='safeguard|safety measures|flagged this message|cyber.use.case|cyber.verification.program|cyber.safeguards'

# classify_report <report-file> → prints one of: report | blocked-cyber | failed
classify_report() {
  local f="$1" first
  # First NON-BLANK line with its indent stripped; `q` stops there (no full-file read).
  first="$(sed -n '/[^[:space:]]/{s/^[[:space:]]*//;p;q;}' "$f")"
  case "$first" in
  'API Error:'* | 'Execution error'*) ;; # a failed run — fall through to the signal test
  *)
    printf 'report\n'
    return 0
    ;;
  esac
  if grep -qiE "$cyber_signal" "$f"; then
    printf 'blocked-cyber\n'
  else
    printf 'failed\n'
  fi
}

status="$(classify_report "$report")"
if [ "$status" != report ]; then
  slug="${title%%:*}" # e.g. "methodology-review" — capture before we suffix the title
  case "$status" in
  blocked-cyber)
    echo "::warning::${title}: blocked by the cybersecurity safety filter — filing an advisory, not a report. The account-level exemption / Cyber Verification Program is what re-enables it."
    title="$title — BLOCKED (cyber-safety filter)"
    ;;
  *)
    echo "::warning::${title}: the run failed before producing any findings — filing an advisory, not a report. The raw error is in the issue."
    title="$title — FAILED (run error)"
    ;;
  esac
  # shellcheck disable=SC2016  # literal backticks/flags in the markdown advisory must NOT expand
  {
    printf '## %s — %s\n\n' "$title" "$(date -u +%Y-%m-%d)"
    if [ "$status" = blocked-cyber ]; then
      printf 'This scheduled routine could **not** run: the model API blocked its request at the\n'
      printf 'cybersecurity safety filter (a request-level block, **not** an audit finding). Raw signal:\n\n'
    else
      printf 'This scheduled routine could **not** run: it failed at the request level before any\n'
      printf 'findings existed (**not** an audit finding, and not a model refusal). Raw signal:\n\n'
    fi
    printf '```\n'
    cat "$report"
    printf '\n```\n\n'
    if [ "$status" = blocked-cyber ]; then
      printf '### Fix (account-level, one-time)\n\n'
      printf -- '- Apply for the cyber-use-case exemption: <https://claude.com/form/cyber-use-case>\n'
      printf -- '- And/or apply to the Cyber Verification Program, which the current wording points at:\n'
      printf '  <https://support.claude.com/en/articles/14604842-real-time-cyber-safeguards-on-claude>\n'
      printf -- '- Switching models is no longer a workaround: opus (#112) and sonnet (#177) have both\n'
      printf '  been blocked. The `--model` flag in `.github/workflows/claude-routines.yml` is a lever,\n'
      printf '  not a remedy.\n\n'
    else
      printf '### Triage\n\n'
      printf -- '- Read the raw signal above: a transport/quota/timeout blip clears on the next run;\n'
      printf '  a repeat needs the workflow looked at.\n'
      printf -- '- The failing step is the `-p` run in `.github/workflows/claude-routines.yml`; its run\n'
      printf '  log carries the full stderr this advisory does not see.\n'
      printf -- '- If the raw signal DOES mention safeguards or a cybersecurity topic, this was a cyber\n'
      printf '  block the classifier failed to recognise: add the new anchor to `cyber_signal` in\n'
      printf '  `.github/workflows/file-routine-issue.sh` **and** a fixture to\n'
      printf '  `test/check-routine-filter.sh`. That is a bug here, not an API problem.\n\n'
    fi
    printf 'The routine re-files this advisory every run until it succeeds. Run the audit by hand\n'
    printf 'meanwhile: `/%s` locally, or the matching skill.\n' "$slug"
    printf '\n_Filed by the claude-routines workflow. Run-status advisory, not findings._\n'
  } >"$body"
fi

# gh search is fuzzy, so re-check the title exactly before deciding to dedup.
existing="$(gh issue list --state open --limit 200 --search "$title in:title" --json number,title \
  --jq '.[] | [.number, .title] | @tsv' | awk -F'\t' -v t="$title" '$2 == t {print $1; exit}')"

if [ -n "$existing" ]; then
  gh issue comment "$existing" --body-file "$body"
  echo "appended report to existing issue #$existing"
else
  gh issue create --title "$title" --body-file "$body"
fi
