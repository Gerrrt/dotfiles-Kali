<!-- Back to top link -->
<a id="readme-top"></a>

<!-- Project Shields -->
<div align="center"><nobr>

[![dotgibson][dotgibson-shield]][dotgibson-url]<!--
-->[![CI][ci-shield]][ci-url]<!--
-->![Last Commit][lastcommit-shield]<!--
-->[![Contributors][contributors-shield]][contributors-url]<!--
-->[![Forks][forks-shield]][forks-url]<!--
-->[![Stargazers][stars-shield]][stars-url]<!--
-->[![Issues][issues-shield]][issues-url]<!--
-->[![MIT License][license-shield]][license-url]

</nobr></div>

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/dotgibson/">
    <img src="https://raw.githubusercontent.com/dotgibson/.github/main/profile/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">🔴 dotfiles-Offense</h3>

  <p align="center">
    The offensive role layer — recon → exploit → evasion, on any OS-native layer.
    <br />
    <a href="https://dotgibson.github.io/dotfiles-web/docs"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://dotgibson.github.io/dotfiles-web/purple/">Red ↔ Blue</a>
    &middot;
    <a href="https://github.com/dotgibson/dotfiles-Offense/issues/new?labels=bug">Report Bug</a>
    &middot;
    <a href="https://github.com/dotgibson/dotfiles-Offense/issues/new?labels=enhancement">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#languages">Languages</a></li>
        <li><a href="#tools">Tools</a></li>
      </ul>
    </li>
    <li><a href="#getting-started">Getting Started</a></li>
    <li><a href="#whats-in-this-layer">What's In This Layer</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

**`dotfiles-Offense` is the offensive Role layer** — the red twin of
[`dotfiles-Defense`](https://github.com/dotgibson/dotfiles-Defense). The shared
**Core** (zsh, tmux, Neovim, git, starship, mise) is vendored under `core/` via
`git subtree`; your **OS-native layer** owns packages, clipboard and paths; and this
repo adds the **offensive** stage on top — engagement scaffolding and workspace
workflow for **authorized** engagements.

It is **distro-agnostic and installs nothing by default.** `./bootstrap.sh` wires
symlinks and reports which offensive tools the box already has; `--install` is the
opt-in. The OS half of this repo — the apt base list, the pinned out-of-band installs,
the WSL bootstrap, the zsh/git/ssh overlays — moved to
[`dotfiles-Debian`](https://github.com/dotgibson/dotfiles-Debian), which now accepts
`ID=kali` as a first-class target.

> **The one rule that matters:** this is a public showcase repo, so **engagement
> and client data never live in it.** Everything goes under `~/engagements/`
> (outside any git tree); the paranoid `.gitignore` is only a backstop. Every
> tool here is for authorized work with written rules of engagement — the
> scope-first scaffolding exists to keep that discipline mechanical.

The full docs live on the [documentation site][docs]; the defensive mirror is
[`dotfiles-Defense`](https://github.com/dotgibson/dotfiles-Defense).

The system is three layers; this repo is the third:

| Layer | Lives in | Owns |
| --- | --- | --- |
| **Core** | [`dotfiles-core`](https://github.com/dotgibson/dotfiles-core), vendored under `core/` | zsh, tmux, nvim, git, starship — identical everywhere |
| **OS-native** | a separate repo — [`dotfiles-Debian`](https://github.com/dotgibson/dotfiles-Debian) for Kali/Debian/Ubuntu | package manager, clipboard, paths |
| **Role (offensive)** | `offensive/` — **this repo** | engagement scaffolding + workspace workflow |

### Languages

- [![Python][python-shield]][python-url]

### Tools

- [![Kali Linux][kali-shield]][kali-url]
- [![NetExec][nxc-shield]][nxc-url]
- [![BloodHound CE][bloodhound-shield]][bloodhound-url]
- [![Impacket][impacket-shield]][impacket-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

**An OS-native layer already installed**, and **Git**. Kali is the box this is built
for — install [`dotfiles-Debian`](https://github.com/dotgibson/dotfiles-Debian) first
and it will provision it. Any other Debian-family box works too; the tool report will
just be shorter.

Running Kali under **WSL2**? It is NAT'd by default, so a listener / reverse shell /
C2 isn't reachable from your LAN until you enable **mirrored networking** in the
_Windows-side_ `%UserProfile%\.wslconfig` (`networkingMode=mirrored`, Win11 22H2+) —
**not** `/etc/wsl.conf`. The example file lives in `dotfiles-Debian/wsl/`.

### Installation

```sh
# 1. the OS-native layer (skip if you already run one)
git clone https://github.com/dotgibson/dotfiles-Debian ~/dotfiles-Debian
~/dotfiles-Debian/bootstrap.sh

# 2. this role layer
git clone https://github.com/dotgibson/dotfiles-Offense ~/dotfiles-Offense
cd ~/dotfiles-Offense
./bootstrap.sh                 # symlinks + the host-tool report; installs nothing
./bootstrap.sh --install       # opt-in: the offensive tool stack
```

`core/` is a vendored subtree and is **already present** in a clone — there is no
submodule step. Flags: `--install` (the opt-in tool install — apt from
`install/offensive-packages.txt` on Kali, a pipx/go subset elsewhere), `--links-only`
(just re-create symlinks), `--no-check` (skip the host-tool report), `--dry-run`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- WHAT'S IN THIS LAYER -->
## What's In This Layer

The offensive stage loads after `os` and before `local` (`… os offensive local`) —
band 85, linked as `85-offensive.zsh` — so your OS layer's paths and clipboard resolve
first and a machine override still wins:

- `offensive/offensive.zsh` — the role-stage helpers (`mkengagement`, `eng`,
  `logshell`, `nmapsweep`, `bhce`, …), each `HAVE_*`-guarded — no exploit code
- `offensive/hacktheplanet`, `ippsec`, `exploitdev`, `evasion` — the vim-folded
  field references (`htp` / `ipp` / `xdev` / `evade`)
- `offensive/companion/` — the ATT&CK-tagged red↔blue corpus, a **vendored
  subtree of [htpx](https://github.com/dotgibson/htpx)** (browsed with `htpx`)
- `PURPLE-TEAM.md` — the defensive mirror of `hacktheplanet` (Splunk/Sentinel)
- `install/tools.lst` — the host-tool probe list; `install/offensive-packages.txt` —
  the apt list `--install` uses **on Kali only**
- `core/` — vendored from `dotfiles-core` (read-only here; edit upstream)

The tradecraft — the phase → ATT&CK → tool map, the OPSEC hygiene, and the tools
that bite (`nxc`/NetExec, BloodHound CE) — is written up on the hub:

> **[→ Offensive methodology][methodology]** · **[dotfiles-Offense on the hub][repo-docs]**

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

This is a **Role layer** stacked on Core + an OS layer, so two vendored trees are
off-limits and the rest is the offensive stage:

1. **Never hand-edit `core/` or `offensive/companion/`.** Both are vendored
   subtrees (`dotfiles-core` and [htpx](https://github.com/dotgibson/htpx)),
   overwritten on the next sync. Fix them **upstream**, then re-sync.
2. **Offensive config goes in the `offensive` stage**, not in `core/`. If it's
   identical everywhere it's Core; if it changes with the OS it's the OS layer.
3. **Keep the discipline.** No payloads, loot, or targets in the repo; scope and
   authorization come first. **Green the gates** — `make lint && make test`
   (shellcheck + `bash -n` / `zsh -n` + markdownlint; vendored trees excluded).

Full details, including how to sync either subtree and what the engagement-data
guards actually enforce, are in [`CONTRIBUTING.md`](CONTRIBUTING.md). Run `make`
with no target for the list of entry points.

Bugs and ideas: open an
[issue](https://github.com/dotgibson/dotfiles-Offense/issues). Security reports go
through [private vulnerability reporting](https://github.com/dotgibson/dotfiles-Offense/security/advisories/new)
— see [`SECURITY.md`](SECURITY.md).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

Garrett Allen - [@gerrrrt](https://x.com/gerrrrt) - <garrettallen2@gmail.com> - [LinkedIn](https://linkedin.com/in/garrettallen2)

Project Link: [dotgibson](https://github.com/dotgibson/)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- Markdown Links & Images -->
[repo-docs]: https://dotgibson.github.io/dotfiles-web/docs/repos/dotfiles-Offense
[methodology]: https://dotgibson.github.io/dotfiles-web/docs/reference/offensive-methodology
[dotgibson-shield]: https://img.shields.io/github/v/release/dotgibson/dotfiles-core?style=plastic&label=dotgibson&labelColor=181717&logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAF1klEQVR4nLSWbUxT7RnHr9PT09MXSltaoC9QXkqR16Iwhb0Iw8VYYE7jPri5aBaZzpmFZbpolpn4QeMyM%2BM%2B7MVt0Q9LNJIlxCzqxGWS6aKAig51vBQKIi3QltpCS0%2Fbc879pD1N3%2Bnz4fG5Pl2977v%2F331d131f5%2BZrddWQZAgAgy9uCRlefICzT6GeIsP%2FXF15kahmu9JglGmLRQoRQdIQWgu77BuWGe%2Fo%2BOqym8odApaWomTT1%2Bl2HqirahaTuJ9kQMggkgYhDRGfRiQDZBi9fuf52%2BD7l1b3ZhRcmq%2FMnBHmibuO7fvWoTalVoDjQRwL8RGgEOtzB0MbtBDnkRjGR0AgTK%2BQfNukr1LKXlhXKZpJSxTKGoFSq9vf16tQ8%2FiEh094Vu0L449mLGMup20DRWuFYVCiFm%2BvU36nTbOlMB%2BnCDxIOBzhvv6nFpc3TS0dUKDRHzh1Jk9O8wlPYN326Oa%2FJobnN8shAOxqKjrdXa8WSnGKWPewR%2FuHLG5P8oKUFJHi%2FH19F6UKEQ%2BnbJap27%2B%2BtWR15VAHgLkV%2F%2F0xW6OuQCfNE4PgmyX6f0xZKYbJDuj43lmtoYqHU%2FaZdwNXr4eoUG51zqgw%2B%2FCtrbm0UCeRynBhqVj2YC4RNC%2FuqStbKkydAODzeO7%2B6QYTpnOIYgB729R729RY9DAGafb0wDOHLwAA5vKK1mJNFoCpsxeLLn%2Fy91uU359719%2FfVXL%2BSM35IzU9rcXciCcQujz0imOfbGhOB0jkGo2hFQBW7Quzr0Zzq6vyBT%2FuKY%2BHErfBmQWLK1Lhr6l1OkleCqC0poPb%2FuTwv3OrA8DPDhgkokgLmLX77o86kqcGJmaj5xjr1JWlAAr1Js75MDEGAAI%2B1mvWX%2F1JY29XmYDPS5ZoNsrM24si1xSh3%2FRbGBYlz%2F73g41ztqliqYv1onyVHgDocMjjXASAKycavlqnZBHa2ajcasjv%2B8MbAPhRV9nI5MezB41crIPPHWOW9Gtl9XhDDCMCokIqSwGQ4shvyucFhEQCnqlSdm9k%2BdKt6XM%2FqO7aof7t8YbIIW5SHdpVIhUTAOAP0L8bmM3MHgJwByidQCgnhSmAqOEYnQ8AgRBr%2FuUzKsgggIs3pyVCfkeTCgAmFtaNOgm39C%2F3511r2W8JYvIAJbIaAwQ3vKAEoVgRaTQIBYKxqxgMs6euvdUXiQDgeHd5rV7K1fb2kC2rOgaYghQBMJ5grI3HUGuuhQiNIOWq8sy%2FLTgCKplgT0ZtCyprWw7%2FvKCyNr6yQqYg8cim59a9KQDnwv84R1%2F99UwAzsMya4vxeOYLN7YePGG%2BcAPjxXS%2BoavknFfOlRTAh8nHKNqLa1v2ZwK6dxQZtHk5ahu3%2FcYmLsoh%2B%2FsUgN%2BztDQzEvkYFBurGnan%2FS1%2B1P98L1FbxLIPzh193X%2FtwbmjiGUBYHd5nVFRCABPlxdtfh%2B3LHGKxof%2Bqo90C6yj58yi9Tm1kWjr94ZXsGhTuDuynAx2z0245yY4X06Kf9HWFd0N%2BuPbsUR64%2B3a57Erig2qIoOIlJSUNE69GWTZRFufXvRNL%2Fo2ywyJE1fMP6xWqHBEP5yfvP7%2FbAAAsFufG01mkVCqkGvLyrbNTD2mw9kfDckmE0oudx9rUZfhiF5Zd%2F%2F00QDF0NkBTJhanB3e0riHJIRKhXarqWfdu%2Bx0WnOot1ftuNR90lhQzEO0L7B2YvCm3b%2BWNI%2ByffSLq757%2BPcquYaIvBtgdcXycuzO9MzTFdccd9IwDNMVlDaXbzPXtxsVhQRDEQzl8i6d%2Buf12Y%2BONDVMo6vOfHWJxHLz3l811u8WAEZABCNAAHSI8n8k2HABKRJjLJ8JECxFMAE%2BHXhiGb7yn35vcCNDKVsEcSuv%2BEpn%2B7Etla0CwAQIOBLBhrkt85kAnwm8mX95e%2FTOa9vUZiIxQI43r0Kura9uN5SYNMoyuVDGZ2nK73C65iy28Rezo44152bSKYAvz3ifVA1lDn0WAAD%2F%2F%2FWvXexgMwqgAAAAAElFTkSuQmCC
[dotgibson-url]: https://github.com/dotgibson/dotfiles-core/releases/latest
[ci-shield]: https://img.shields.io/github/check-runs/dotgibson/dotfiles-Offense/main?style=plastic&logo=githubactions&logoColor=white&label=CI
[ci-url]: https://github.com/dotgibson/dotfiles-Offense/actions/workflows/lint.yml
[lastcommit-shield]: https://img.shields.io/github/last-commit/dotgibson/dotfiles-Offense?branch=main&style=plastic&logo=git&logoColor=white
[contributors-shield]: https://img.shields.io/github/contributors/dotgibson/dotfiles-Offense.svg?style=plastic&logo=github
[contributors-url]: https://github.com/dotgibson/dotfiles-Offense/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/dotgibson/dotfiles-Offense.svg?style=plastic&logo=github
[forks-url]: https://github.com/dotgibson/dotfiles-Offense/network/members
[stars-shield]: https://img.shields.io/github/stars/dotgibson/dotfiles-Offense.svg?style=plastic&logo=github
[stars-url]: https://github.com/dotgibson/dotfiles-Offense/stargazers
[issues-shield]: https://img.shields.io/github/issues/dotgibson/dotfiles-Offense?style=plastic&logo=github
[issues-url]: https://github.com/dotgibson/dotfiles-Offense/issues
[license-shield]: https://img.shields.io/github/license/dotgibson/dotfiles-Offense.svg?style=plastic
[license-url]: https://github.com/dotgibson/dotfiles-Offense/blob/main/LICENSE
[docs]: https://dotgibson.github.io/dotfiles-web/docs
[python-shield]: https://img.shields.io/github/v/release/python/cpython?style=plastic&logo=python&logoColor=white&label=Python&labelColor=3776AB&color=3D59A1
[python-url]: https://github.com/python/cpython
[kali-shield]: https://img.shields.io/badge/Kali_Linux-557C94?style=plastic&logo=kalilinux&logoColor=white
[kali-url]: https://www.kali.org
[nxc-shield]: https://img.shields.io/github/v/release/Pennyw0rth/NetExec?style=plastic&logo=gnometerminal&logoColor=24283B&label=NetExec&labelColor=BB9AF7&color=3D59A1
[nxc-url]: https://github.com/Pennyw0rth/NetExec
[bloodhound-shield]: https://img.shields.io/github/v/release/SpecterOps/BloodHound?style=plastic&logo=gnometerminal&logoColor=24283B&label=BloodHound%20CE&labelColor=BB9AF7&color=3D59A1
[bloodhound-url]: https://github.com/SpecterOps/BloodHound
[impacket-shield]: https://img.shields.io/github/v/release/fortra/impacket?style=plastic&logo=gnometerminal&logoColor=24283B&label=Impacket&labelColor=BB9AF7&color=3D59A1
[impacket-url]: https://github.com/fortra/impacket
