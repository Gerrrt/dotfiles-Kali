# Offense Aliases Cheat Sheet

Aliases sourced from three layers: `core/` (Core), your **OS-native layer**
(`dotfiles-Debian`'s `os/debian.zsh` on Kali/Debian/Ubuntu), and
`offensive/offensive.zsh` (this repo's engagement layer). See `core/` for the full
Core alias reference (modern CLI, git, safety nets).

**The OS-layer aliases are no longer documented here.** `apt*`, `pbcopy`/`pbpaste`,
the WSL2 verbs and `dotsync` moved to `dotfiles-Debian` with the rest of the
OS-native layer — see [its docs][debian] rather than a copy that would drift.

[debian]: https://github.com/dotgibson/dotfiles-Debian

---

## Offensive Layer

Aliases and functions live in `offensive/offensive.zsh`. Most tool shortcuts are
guarded by `HAVE_*` detection flags and activate only when the tool is installed;
a few (e.g. `hethttp`) are unguarded.

### Directories

Paths the offensive layer exports; override any of them in your host-local
`99-local.zsh` before the offensive stage loads.

| Variable            | Default                | What it is                                                                                     |
| ------------------- | ---------------------- | ---------------------------------------------------------------------------------------------- |
| `$ENGAGEMENTS_DIR`  | `~/engagements`        | Engagement data root — deliberately **outside** the repo so client material is never committed |
| `$SECLISTS_DIR`     | `/usr/share/seclists`  | SecLists install path (Kali default); the `seclists` alias `cd`s here                          |
| `$WORDLISTS_DIR`    | `/usr/share/wordlists` | Kali's packaged wordlist tree (rockyou et al.)                                                 |
| `$DOTFILES_OFFENSE` | this checkout          | Resolved from the `85-offensive.zsh` symlink, so it is right wherever you cloned it            |

| Alias     | Expands To               | What it is                                                                                                                                   |
| --------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `offsync` | `cd "$DOTFILES_OFFENSE"` | Jump to this checkout. **Not** `dotsync` — that belongs to the OS-native layer (band 80), and reusing the name here would silently shadow it |

### Tool Shortcuts

| Alias      | Expands To           | Requires             |
| ---------- | -------------------- | -------------------- |
| `smb`      | `nxc smb`            | NetExec              |
| `ldap`     | `nxc ldap`           | NetExec              |
| `winrm`    | `nxc winrm`          | NetExec              |
| `msf`      | `msfconsole -q`      | Metasploit           |
| `sliver`   | `sliver-client`      | Sliver C2            |
| `seclists` | `cd "$SECLISTS_DIR"` | seclists dir present |

### Cheat Sheet Openers

Each `~/<name>` is a symlink to a file **tracked in this public repo**, so the four
vim-folded references open **read-only** by default — an errant `:w` would otherwise
commit whatever is in the buffer. Pass `-w` to edit the reference itself.
To fill in real target values, `sed` a copy into `$ENGAGEMENT` (recipe at the top of
`hacktheplanet`) — never substitute them into the buffer.

| Command              | Opens                                                                                                             | File              |
| -------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------- |
| `htp` / `htp -w`     | HackThePlanet — CTF/HTB/engagement command reference                                                              | `~/hacktheplanet` |
| `xdev` / `xdev -w`   | ExploitDev — stack/SEH overflows, shellcode, DEP/ASLR                                                             | `~/exploitdev`    |
| `evade` / `evade -w` | Evasion — AV/AMSI/AppLocker bypass, process injection                                                             | `~/evasion`       |
| `ipp` / `ipp -w`     | IppSec — engagement methodology & recon loop                                                                      | `~/ippsec`        |
| `htpx`               | Companion — ATT&CK-tagged red↔blue corpus (fzf: pick → preview attack beside detection → fill `{{slots}}` → clip) | `~/companion`     |

### Helper Functions

The four that write engagement data — `note`, `logshell`, `bhce`, `nmapsweep` —
resolve their target via `$ENGAGEMENT` (set by `mkengagement` / `eng`). With it
unset they **refuse to run inside a git work tree** rather than falling back to
`$PWD`, so a stray `note` can't land client data in a checkout. Outside a repo the
`$PWD` fallback still applies; to write into a repo deliberately, say
`ENGAGEMENT="$PWD" note "…"`.

| Function                                    | Purpose                                                                                                                                                                                        |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lhost [iface]`                             | Print attacker IP — prefers VPN (tun0/tun1/tap0/wg0), falls back to default route                                                                                                              |
| `hethttp [port]`                            | Quick delivery web server on 0.0.0.0 (optional port, default 8000); advertises the reachable callback URL via `lhost`                                                                          |
| `note [text]`                               | Append timestamped entry to engagement `notes.md`; no args opens it in `$EDITOR`                                                                                                               |
| `ttyup`                                     | Print the TTY stabilisation sequence with attacker rows/cols pre-filled                                                                                                                        |
| `cde`                                       | `cd` to the active `$ENGAGEMENT` directory                                                                                                                                                     |
| `rocks [query]`                             | Open ippsec.rocks search in browser (xdg-open / wslview / explorer.exe)                                                                                                                        |
| `nmapsweep <target>`                        | `nmap -sCV -T4 -oA nmap/<target>` into `./nmap/` (`/` and `:` sanitized to `__`)                                                                                                               |
| `bhce <dc> <user> <pass\|:NThash> [domain]` | BloodHound CE collection via `nxc ldap`, output to `loot/bloodhound/`                                                                                                                          |
| `mkengagement <name>`                       | Create dated engagement workspace — creates `scope/scope.txt` first for ROE                                                                                                                    |
| `eng`                                       | fzf picker to jump between existing engagements; sets `$ENGAGEMENT`                                                                                                                            |
| `logshell`                                  | Record terminal session via `script` to `notes/session-<timestamp>.log`                                                                                                                        |
| `redup`                                     | Manual, opt-in refresh of fast-moving offensive tools (nuclei templates always + its engine only where that build carries `-update`, which Kali's packaged nuclei does not; katana, searchsploit exploit-DB) — attacker box only, never mid-engagement; apt-packaged tools update via `up` |
