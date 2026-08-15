<!-- This repo stacks THREE layers (Core → OS → offensive) and vendors TWO subtrees.
     Most review mistakes here are "right change, wrong layer". -->

## What & why

<!-- One or two lines. -->

## Which layer does this belong to?

- [ ] It is **not** in `core/` — that tree is vendored from
      [dotfiles-core](https://github.com/dotgibson/dotfiles-core) and is overwritten
      on the next sync. Identical-everywhere config is fixed **upstream**.
- [ ] It is **not** in `offensive/companion/` — vendored from
      [htpx](https://github.com/dotgibson/htpx); same rule. Edit the entry upstream
      and re-run `offensive/companion/gen-views.sh`.
- [ ] Changes with the OS → `os/kali.*`. Changes with the operator → `offensive/`.

## Engagement-data discipline

- [ ] No client names, target IPs/hostnames/domains, credentials, loot, or scan output
- [ ] If a helper writes files, it resolves its root via `_eng_writeroot` (refuses to
      write inside a git work tree without `$ENGAGEMENT`)
- [ ] The four field references (`hacktheplanet`, `exploitdev`, `evasion`, `ippsec`)
      were not used as a scratchpad — they are tracked and open read-only for a reason

## Checks

- [ ] `make lint` green (shellcheck + `bash -n`/`zsh -n` + markdownlint)
- [ ] `make test` green (routine-filter classifier + companion view drift)
- [ ] If `bootstrap.sh` changed: `./bootstrap.sh --dry-run` reviewed, and re-run twice
      to confirm it is still idempotent
- [ ] If `install/*.txt` changed: `make packages-check`
- [ ] If a tool version in `install/tool-versions.env` changed:
      `scripts/update-tool-checksums.sh --verify`

## Notes

<!-- Load-order implications, follow-up sync, anything reviewers should know. -->
