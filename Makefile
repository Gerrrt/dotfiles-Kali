# Makefile — the discoverable entry point for dotfiles-Offense.
# ──────────────────────────────────────────────────────────────────────────────
# This repo had no Makefile, which made several documented commands untrue:
# core.lock's own header says "Regenerate ... with: make core-lock", CLAUDE.md
# points at `make audit` / `make sync`, and neither target existed anywhere. The
# gates were real but each lived behind a different hand-typed path.
#
# NOTE ON SCOPE: dotfiles-core's Makefile is the AUTHORING gate for Core (audit,
# manifest, behavioral suite, release). This one is a CONSUMER's Makefile — it wires
# the checks this repo owns and the two vendored-subtree sync paths. Anything under
# core/ is verified upstream and is not re-gated here.
#
# Run `make` with no target for the list.
# ──────────────────────────────────────────────────────────────────────────────
.DEFAULT_GOAL := help
.PHONY: help lint shellcheck markdown trap-guard test packages-check secrets \
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
	@command -v shellcheck >/dev/null 2>&1 \
	  || { echo "shellcheck not installed — CI uses the pinned one from $(CORE_PINS)"; exit 0; }
	@echo ":: shellcheck"
	@SHELLCHECK_OPTS="-e SC1090 -e SC1091 -e SC2015 -e SC2088" shellcheck $(SH_FILES)
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

markdown: ## markdownlint repo-owned docs (pinned version, same as CI)
	@command -v npx >/dev/null 2>&1 || { echo "npx not available — skipping markdown"; exit 0; }
	@npx --yes markdownlint-cli2@$(MARKDOWNLINT_VERSION) $(MD_FILES)

test: ## Run the repo's behavioural checks
	@./test/check-routine-filter.sh
	@./offensive/companion/gen-views.sh --check
	@echo "✓ tests pass"

packages-check: ## Does every offensive-packages.txt name still resolve on Kali? (advisory)
	@./test/check-packages.sh || true

secrets: ## gitleaks over the working tree + full history (needs gitleaks)
	@command -v gitleaks >/dev/null 2>&1 \
	  || { echo "gitleaks not installed — CI installs the pinned one; see .github/workflows/checks.yml"; exit 0; }
	@gitleaks detect --no-git --redact --verbose --exit-code 1
	@gitleaks detect --redact --verbose --exit-code 1

bootstrap-dry: ## Preview the full bootstrap plan, changing nothing
	@./bootstrap.sh --dry-run

## ── vendored core/ (subtree of dotfiles-core) ────────────────────────────────

core-check: ## Is the vendored core/ behind upstream dotfiles-core?
	@./test/check-core-freshness.sh

core-sync: ## Pull Core from upstream and refresh core.lock (review + commit yourself)
	@./scripts/sync-core.sh

core-lock: ## Refresh core.lock after a MANUAL `git subtree pull` of core/
	@./scripts/sync-core.sh --check
	@echo
	@echo "core.lock is written by scripts/sync-core.sh as part of the pull."
	@echo "If you pulled by hand, re-run the pull through 'make core-sync' so the"
	@echo "lock is stamped from the squash commit's git-subtree-split trailer."

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
