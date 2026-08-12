# Kali Aliases Cheat Sheet

Aliases sourced from three layers: `core/` (Core), `os/kali.zsh` (Debian/WSL2),
and `offensive/offensive.zsh` (engagement layer). See `core/` for the full
Core alias reference (modern CLI, git, safety nets).

---

## OS Layer — Debian / WSL2

### Package Management (apt)

| Alias | Expands To |
|-------|------------|
| `aptu` | `sudo apt-get update && sudo apt-get full-upgrade -y` |
| `apti` | `sudo apt-get install -y` |
| `aptr` | `sudo apt-get remove` |
| `apts` | `apt-cache search` |
| `aptw` | `dpkg -S` (which package owns a file) |
| `aptl` | `dpkg -L` (list files in package) |
| `aptshow` | `apt-cache show` |

### Clipboard

| Alias | Expands To | Condition |
|-------|-----------|----------|
| `pbcopy` | `clip` | `clip` installed |
| `pbpaste` | `clip-paste` | `clip-paste` installed |

### WSL2 Integration

| Alias | Expands To | Condition |
|-------|-----------|----------|
| `open` | `explorer.exe` | WSL2 only |
| `xdg-open` | `wslview` | WSL2 + wslview |
| `cdwin` | `cd "$WINHOME"` | WSL2 + WINHOME set |

### Navigation

| Alias | Expands To | Condition |
|-------|-----------|----------|
| `dotsync` | `cd "$HOME/dotfiles-Kali"` | always |
| `opsignin` | `eval "$(op signin)"` | `op` CLI installed |
| `localip` | `ip -brief -4 addr show scope global` | always |

---

## Offensive Layer

Aliases and functions live in `offensive/offensive.zsh`. Most tool shortcuts are
guarded by `HAVE_*` detection flags and activate only when the tool is installed;
a few (e.g. `hethttp`) are unguarded.

### Directories

Three paths the offensive layer exports; override any of them in your host-local
`99-local.zsh` before the offensive stage loads.

| Variable | Default | What it is |
|----------|---------|------------|
| `$ENGAGEMENTS_DIR` | `~/engagements` | Engagement data root — deliberately **outside** the repo so client material is never committed |
| `$SECLISTS_DIR` | `/usr/share/seclists` | SecLists install path (Kali default); the `seclists` alias `cd`s here |
| `$WORDLISTS_DIR` | `/usr/share/wordlists` | Kali's packaged wordlist tree (rockyou et al.) |

### Tool Shortcuts

| Alias | Expands To | Requires |
|-------|-----------|----------|
| `smb` | `nxc smb` | NetExec |
| `ldap` | `nxc ldap` | NetExec |
| `winrm` | `nxc winrm` | NetExec |
| `msf` | `msfconsole -q` | Metasploit |
| `sliver` | `sliver-client` | Sliver C2 |
| `seclists` | `cd "$SECLISTS_DIR"` | seclists dir present |

### Cheat Sheet Openers

| Alias | Opens | File |
|-------|-------|------|
| `htp` | HackThePlanet — CTF/HTB/engagement command reference | `~/hacktheplanet` |
| `xdev` | ExploitDev — stack/SEH overflows, shellcode, DEP/ASLR | `~/exploitdev` |
| `evade` | Evasion — AV/AMSI/AppLocker bypass, process injection | `~/evasion` |
| `ipp` | IppSec — engagement methodology & recon loop | `~/ippsec` |
| `htpx` | Companion — ATT&CK-tagged red↔blue corpus (fzf: pick → preview attack beside detection → fill `{{slots}}` → clip) | `~/companion` |

### Helper Functions

| Function | Purpose |
|----------|---------|
| `lhost [iface]` | Print attacker IP — prefers VPN (tun0/tun1/tap0/wg0), falls back to default route |
| `hethttp [port]` | Quick delivery web server on 0.0.0.0 (optional port, default 8000); advertises the reachable callback URL via `lhost` |
| `note [text]` | Append timestamped entry to engagement `notes.md`; no args opens it in `$EDITOR` |
| `ttyup` | Print the TTY stabilisation sequence with attacker rows/cols pre-filled |
| `cde` | `cd` to the active `$ENGAGEMENT` directory |
| `rocks [query]` | Open ippsec.rocks search in browser (xdg-open / wslview / explorer.exe) |
| `nmapsweep <target>` | `nmap -sCV -T4 -oA nmap/<target>` into `./nmap/` (`/` and `:` sanitized to `__`) |
| `bhce <dc> <user> <pass\|:NThash> [domain]` | BloodHound CE collection via `nxc ldap`, output to `loot/bloodhound/` |
| `mkengagement <name>` | Create dated engagement workspace — creates `scope.txt` first for ROE |
| `eng` | fzf picker to jump between existing engagements; sets `$ENGAGEMENT` |
| `logshell` | Record terminal session via `script` to `notes/session-<timestamp>.log` |
| `redup` | Manual, opt-in refresh of fast-moving offensive tools (nuclei engine+templates, searchsploit exploit-DB, go-installed tools) — attacker box only, never mid-engagement; apt-packaged tools update via `up` |
