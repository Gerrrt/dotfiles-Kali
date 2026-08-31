# Makefile — the discoverable entry point for dotfiles-Offense.
# ──────────────────────────────────────────────────────────────────────────────
# This repo had no Makefile, which made several documented commands untrue: core.lock's
# header pointed at a `make core-lock` that existed nowhere, CLAUDE.md pointed at
# `make audit` / `make sync`, and neither target existed anywhere. The gates were real but
# each lived behind a different hand-typed path.
#
# core.lock no longer says that: it is written by Core's fan-out and says so. `make
# core-lock` survives as the place that EXPLAINS that, because it is still what someone
# types when they want to know how the lock moves.
#
# NOTE ON SCOPE: dotfiles-core's Makefile is the AUTHORING gate for Core (audit,
# manifest, behavioral suite, release). This one is a CONSUMER's Makefile — it wires
# the checks this repo owns and the vendored-subtree sync paths. Anything under
# core/ is verified upstream and is not re-gated here.
#
# ONE of those two subtrees still pulls locally: the COMPANION (htpx) does, because htpx
# vendors its whole tree. CORE does not, since dotfiles-core#676 made a vendored core/ a
# filtered subset that `git subtree pull` cannot produce. The asymmetry is deliberate;
# do not "fix" companion-sync to match core-sync.
#
# Run `make` with no target for the list.
# ──────────────────────────────────────────────────────────────────────────────
.DEFAULT_GOAL := help
.PHONY: help lint shellcheck markdown trap-guard test corpus-commands view-counts packages-check secrets \
        core-check core-sync core-lock companion-check companion-sync companion-integrity \
        bootstrap-dry hooks

# Pinned tool versions come from the vendored Core, so local runs match CI exactly.
CORE_PINS := core/scripts/tool-versions.env
MARKDOWNLINT_VERSION := $(shell sed -n 's/^MARKDOWNLINT_VERSION=//p' $(CORE_PINS) 2>/dev/null)

# Repo-owned sources only — the two vendored subtrees are gated by their upstreams.
SH_FILES := $(shell git ls-files '*.sh' ':!:core/**' ':!:offensive/companion/**' 2>/dev/null)
ZSH_FILES := $(shell git ls-files '*.zsh' ':!:core/**' ':!:offensive/companion/**' 2>/dev/null)
MD_FILES := $(shell git ls-files '*.md' ':!:core/**' ':!:offensive/companion/**' 2>/dev/null)

help: ## Show this help
	@grep -hE '^[a-z][a-z0-9_-]*:.*?## ' $(MAKEFILE_LIST) \
	  | sort | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

## ── gates ────────────────────────────────────────────────────────────────────

lint: shellcheck markdown trap-guard ## Run every static gate (shellcheck + syntax + markdown + trap discipline)

shellcheck: ## shellcheck + bash -n / zsh -n over repo-owned shell
	@# ONE recipe line, same reason as `markdown` below: make gives each recipe line its
	@# own shell, so the `exit 0` ended only ITS line — this printed "not installed" and
	@# then ran shellcheck anyway, exiting 127 (dotgibson/dotfiles-core#775).
	@if ! command -v shellcheck >/dev/null 2>&1; then \
	  echo "shellcheck not installed — CI uses the pinned one from $(CORE_PINS)"; \
	else \
	  echo ":: shellcheck"; \
	  SHELLCHECK_OPTS="-e SC1090 -e SC1091 -e SC2015 -e SC2088" shellcheck $(SH_FILES); \
	fi
	@echo ":: bash -n"
	@for f in $(SH_FILES); do bash -n "$$f" || exit 1; done
	@command -v zsh >/dev/null 2>&1 && { echo ":: zsh -n"; for f in $(ZSH_FILES); do zsh -n "$$f" || exit 1; done; } || true
	@echo "✓ shell clean"

trap-guard: ## Refuse a RETURN trap that does not disarm itself (shellcheck cannot see this)
	@# A bash RETURN trap is a GLOBAL slot, not a function-scoped one: armed inside a
	@# function it survives into the CALLER's frame and fires again on ITS return, where
	@# the local it cleans up is gone and `set -u` kills the script. That is issue #198.
	@# Valid syntax, so shellcheck and `bash -n` both pass it, and no gate in this fleet
	@# ever runs a real install path — hence a dedicated grep. See the script's header.
	@./test/check-return-traps.sh

# ONE recipe line. make runs each line in its own shell, so the guard's `exit 0` only
# ended THAT line — this printed "npx not available — skipping markdown" and then ran npx
# anyway, exiting 127. Joining them makes the skip a real skip (dotgibson/dotfiles-core#775).
#
# An unreadable pin FAILS rather than falling back to @latest. "Pinned version, same as CI"
# is this target's whole claim; silently linting under a different version would make a
# local pass mean nothing, which is the failure mode the rest of that sweep is about.
markdown: ## markdownlint repo-owned docs (pinned version, same as CI)
	@if ! command -v npx >/dev/null 2>&1; then echo "npx not available — skipping markdown"; \
	elif [ -z "$(MARKDOWNLINT_VERSION)" ]; then \
	  echo "!! MARKDOWNLINT_VERSION unreadable from $(CORE_PINS) — refusing to lint unpinned"; exit 1; \
	elif [ -z "$(MD_FILES)" ]; then echo "no repo-owned .md"; \
	else npx --yes markdownlint-cli2@$(MARKDOWNLINT_VERSION) $(MD_FILES); fi

test: ## Run the repo's behavioural checks
	@./test/check-routine-filter.sh
	@./offensive/companion/gen-views.sh --check
	@./test/check-view-counts.sh
	@./test/check-corpus-commands.sh --self-test
	@./test/check-corpus-commands.sh
	@echo "✓ tests pass"

view-counts: ## Do the views still state the corpus's real red/blue/projected counts?
	@# hacktheplanet, PURPLE-TEAM.md and OFFENSIVE-METHODOLOGY.md quote HAND-TYPED counts
	@# about a VENDORED corpus. gen-views --check compares block CONTENT and never counts
	@# blocks; markdownlint cannot tell 101 from 102. Two of those files carry their own
	@# caveat that these go stale on every companion-sync — they did, twice (#261, #262).
	@# This is that caveat, executed. Semantic buckets (56 cloud, 13 C2, 7 Linux, 69/76,
	@# the percentages) are NOT checked: nothing in the entries marks an entry "cloud".
	@./test/check-view-counts.sh

corpus-commands: ## Does every command in the red corpus resolve to something? (offline)
	@# 84 of the corpus' 103 red entries are unprojected, so gen-views --check (which
	@# byte-compares the 19 projected blocks) has never seen their command lines, and
	@# check-packages.sh reads the manifest rather than the corpus. `impacket-petitpotam`
	@# and `dfscoerce` shipped through that gap. See issue #208.
	@./test/check-corpus-commands.sh --self-test
	@./test/check-corpus-commands.sh

packages-check: ## Does every offensive-packages.txt name still resolve on Kali? (advisory)
	@./test/check-packages.sh || true

secrets: ## gitleaks over the working tree + full history (needs gitleaks)
	@# The guard and BOTH scans are one recipe line: make gives each line its own shell, so
	@# the old `exit 0` ended only ITS line and both `gitleaks detect` calls ran anyway,
	@# exiting 127 on any box without it (dotgibson/dotfiles-core#775).
	@# -c core/gitleaks.toml — ONE POLICY FILE, Core's, the rule Core's own reusable
	@# lint-call.yml secrets leg states, and the one .github/workflows/checks.yml here already
	@# passes. Without it these two ran the STOCK rule set, so this target and this repo's own
	@# CI measured by different policies (dotgibson/dotfiles-core#623). Several stock rules
	@# match on credential-shaped POSITION rather than content — curl-auth-user fires on
	@# anything in curl's basic-auth credential slot — so a variable reference, which is the
	@# SECURE shape because the value never enters the file, was reported as a leak. That is
	@# not hypothetical: the vendored core/CHANGELOG.md documents that very allowlist, so the
	@# stock scan flagged Core's explanation of the rule as a violation of it. It matters more
	@# on the second line, which reads full HISTORY: a false positive there cannot be fixed
	@# forward, only by a rewrite, so it would wedge this target permanently.
	@if ! command -v gitleaks >/dev/null 2>&1; then \
	  echo "gitleaks not installed — CI installs the pinned one; see .github/workflows/checks.yml"; \
	else \
	  gitleaks detect --no-git -c core/gitleaks.toml --redact --verbose --exit-code 1 && \
	  gitleaks detect -c core/gitleaks.toml --redact --verbose --exit-code 1; \
	fi

bootstrap-dry: ## Preview the full bootstrap plan, changing nothing
	@./bootstrap.sh --dry-run

## ── vendored core/ (subtree of dotfiles-core) ────────────────────────────────

core-check: ## Is the vendored core/ behind upstream dotfiles-core?
	@./test/check-core-freshness.sh

# core-sync and core-lock NO LONGER WRITE ANYTHING (dotfiles-core#676). Both report how
# far core/ is behind and say how Core actually arrives — by fan-out. The local
# `git subtree pull` is retired: it merges upstream's WHOLE tree, and a vendored core/ is
# a filtered subset of it, so pulling would land files core/ is not supposed to carry and
# core-integrity would report TAMPERED. The scripts/sync-core.sh header has the long form.
#
# Kept as targets rather than deleted: they are what someone types when asking "how do I
# move Core?", and that question still has an answer. They exit 0 — they are informational,
# not gates, so there is nothing here for the fleet's make-gate audit to catch.

core-sync: ## Report how far core/ is behind upstream (Core now arrives by fan-out — see core-check)
	@./scripts/sync-core.sh

core-lock: ## core.lock is written by Core's fan-out, not here — explains how
	@./scripts/sync-core.sh

## ── vendored offensive/companion/ (subtree of htpx) ──────────────────────────

companion-check: ## Is the vendored companion behind upstream htpx?
	@./test/check-companion-freshness.sh

companion-integrity: ## Was the vendored companion hand-edited? (tree vs companion.lock)
	@./test/check-companion-integrity.sh

companion-sync: ## Pull the companion from upstream htpx and refresh companion.lock
	@./scripts/sync-companion.sh

## ── maintenance ──────────────────────────────────────────────────────────────

# No tool-checksums target: install/tool-versions.env and its updater moved to
# dotfiles-Debian with the rest of the OS-native layer. This repo pins nothing —
# `--install` uses apt on Kali, and pipx/go elsewhere, both of which verify their own
# downloads (PyPI hashes, the Go checksum database).

hooks: ## Install the local core-guard pre-commit hook into this clone
	@bash -c 'source core/lib/ux.sh; source core/lib/bootstrap-lib.sh; blib_install_core_guard "$$PWD"'
