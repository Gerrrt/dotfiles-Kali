# Engagement: __NAME__   (started __DATE__)

Local workspace — __never committed to any public repo.__

## Layout

This is exactly what `mkengagement` creates — keep this list and that function in
step, and keep both in step with the repo's `.gitignore` backstop. A directory
name that drifts here is a directory the backstop stops covering.

- `scope/scope.txt` — scope & rules of engagement (read first, every session)
- `recon/` — passive/OSINT collection
- `scans/` — active scanning output
- `nmap/` — `nmapsweep` writes `<target>.{nmap,gnmap,xml}` into the cwd
- `web/` — web-app output (ffuf/feroxbuster/nuclei/katana)
- `loot/creds/` — captured / cracked credentials
- `loot/hashes/` — hash dumps awaiting hashcat/john
- `loot/bloodhound/` — CE-ready collector zips (`bhce` writes here)
- `screenshots/` — screenshots & artifacts for the report
- `exploit/` — PoCs gathered or adapted for this engagement
- `notes.md` — running log (use the `note` command)
- `notes/` — `logshell` session transcripts (`session-<stamp>.log`)
- `report/` — deliverable + `finding.md` copies

## Quick status

- [ ] Scope confirmed & authorization on file
- [ ] Recon complete
- [ ] Findings logged
- [ ] Report drafted
- [ ] Debrief delivered

## Key facts

- Active engagement helpers: `eng`, `cde`, `note "..."`, `lhost`
- `$ENGAGEMENT` points at this directory. The helpers that write engagement data
  (`note`, `logshell`, `bhce`, `nmapsweep`) refuse to run inside a git work tree
  when it is unset — so a stray `note` can never land in the dotfiles repo.
