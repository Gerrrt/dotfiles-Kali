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

  <h3 align="center">⚔️ htpx</h3>

  <p align="center">
    Every attack, beside its detection — an ATT&CK-tagged, red↔blue paired corpus.
    <br />
    <a href="https://dotgibson.github.io/dotfiles-web/purple/"><strong>Explore the red ↔ blue view »</strong></a>
    <br />
    <br />
    <a href="https://dotgibson.github.io/dotfiles-web/docs">Documentation</a>
    &middot;
    <a href="https://github.com/dotgibson/htpx/issues/new?labels=bug">Report Bug</a>
    &middot;
    <a href="https://github.com/dotgibson/htpx/issues/new?labels=enhancement">Request Feature</a>
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
    <li><a href="#the-corpus">The Corpus</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

**`htpx` is the structured, ATT&CK-tagged, red↔blue-paired corpus** behind the
[dotgibson](https://github.com/dotgibson/) dotfiles system. Every entry is one
attack or one detection, in Markdown with typed YAML frontmatter, and each attack
is **paired** to the telemetry it trips. Browse it with the `htpx` fzf front end:
pick an attack, preview it **beside its blue detection**, fill the `{{slots}}`
from your target env, and copy. No mainstream tool ships attacks paired with the
detections they set off — that purple pivot is the point.

It is **host-agnostic**, so it lives in its own repo and is vendored back into
[`dotfiles-Offense`](https://github.com/dotgibson/dotfiles-Offense) at
`offensive/companion/` via `git subtree` (like Core is vendored into the OS
repos). It's the **source of truth** for the paired slice: `gen-views.sh`
generates the marked blocks in Offense's `hacktheplanet` / `PURPLE-TEAM.md` from the
entries, and CI drift-gates them. See the fleet's
[red ↔ blue view][purple] and the [offensive methodology][methodology] for the
wider context.

| Piece | Role |
| --- | --- |
| `htpx` | fzf browser: search → preview attack + its detection → fill slots → clip |
| `entries/red/*.md` | attacks (frontmatter + command template with `{{slots}}`) |
| `entries/blue/*.md` | detections (frontmatter + SPL/KQL), paired back to a red entry |
| `gen-views.sh` | renders entry-backed blocks into the flat views (`--check` drift-gates) |

### Languages

- [![Markdown][markdown-shield]][markdown-url]

Entries are Markdown + YAML frontmatter; detections carry Splunk SPL / KQL.

### Tools

- [![MITRE ATT&CK][attack-shield]][attack-url]
- [![fzf][fzf-shield]][fzf-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

Inside the dotfiles system, `htpx` is already on your shell (bootstrap symlinks
`companion/` to `~/companion` and defines the `htpx` function). To run it from a
standalone checkout:

```sh
git clone https://github.com/dotgibson/htpx ~/htpx
cd ~/htpx
export RHOST=10.10.10.5 DOMAIN=corp.local USER_T=svc_sql PASS='…'
./htpx            # pick an attack; the preview shows it + its blue detection,
                  # slot-filled and copied via clip/pbcopy/wl-copy/xclip/xsel
```

It needs `fzf`; `bat` (preview) and a clipboard helper are used if present, else
it falls back to `cat`/stdout. No `yq` dependency — it reads only the scalar
frontmatter fields it needs with `awk`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- THE CORPUS -->
## The Corpus

105 paired attack/detection concepts (plus one unpaired recon entry), spanning
Credential Access, Privilege Escalation, Lateral Movement, Persistence, Stealth,
Defense Impairment, Collection, Exfiltration, and Discovery — across on-prem AD,
a multi-cloud slice (Entra/M365, Azure ARM, AWS, GCP), Kubernetes, Okta, Google Workspace,
CI/CD (GitHub Actions, GitLab, Jenkins), Harbor, HashiCorp Vault, Terraform
Cloud, Snowflake, Cloudflare, the npm + PyPI registries, and Slack.

Tags track **live** ATT&CK rather than a pinned bundle — currently **v19 (April
2026)**, which split Defense Evasion into Stealth (`TA0005`) and Defense
Impairment (`TA0112`). The weekly corpus review re-verifies every technique ID
against `attack.mitre.org` and flags anything revoked or renamed, so retags land
as they happen. A representative slice:

| Attack (red) | Detection (blue) | ATT&CK |
| --- | --- | --- |
| Kerberoast SPNs | `4769` RC4 TGS | T1558.003 |
| DCSync | `4662` replication | T1003.006 |
| Pass-the-hash lateral | `4624` type-3 fan-out | T1550.002 |
| AD CS ESC1 (certipy) | `4886` SAN mismatch | T1649 |
| Device-code phishing (Entra) | sign-in `deviceCode` flow (KQL) | T1528 |
| Malicious package publish (npm) | audit `package.publish` off-CI actor | T1195.002 |

The full set lives in `entries/red|blue/*.md` — the `pair:` field is what makes
the purple pivot free (Kerberoast ↔ `4769`, DCSync ↔ `4662`, …).

An entry may be **deliberately unpaired** and carry `pair: null`. It must also carry
a **`pair_note:`** saying why, and CI enforces it: a bare `null` is indistinguishable
from an oversight, which is how two of them survived several rounds of triage. The
note is the difference between "this hole is known and reasoned" and "someone
forgot" — see [#97](https://github.com/dotgibson/htpx/issues/97).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

`htpx` is the **source of truth** for the paired red↔blue slice, so the workflow
is entry-first:

1. **Author the pair.** Add the red + blue entry (`entries/red|blue/*.md`) with
   ATT&CK tags and a `pair:` link; normalize command placeholders to `{{slots}}`.
   If the technique genuinely has no counterpart, set `pair: null` **and** a
   `pair_note:` giving the reason — CI rejects an unexplained `null`.
2. **Regenerate the views.** Mark the matching blocks in the flat files and run
   `gen-views.sh`; `gen-views.sh --check` (CI) fails on drift. Prose outside the
   markers stays hand-authored and canonical.
3. **Edit here, not in Offense.** The vendored copy at `dotfiles-Offense`'s
   `offensive/companion/` is overwritten on the next sync — fix it here, then
   Offense's `scripts/sync-companion.sh` pulls the change into that copy.

Bugs and ideas: open an
[issue](https://github.com/dotgibson/htpx/issues).

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
[purple]: https://dotgibson.github.io/dotfiles-web/purple/
[methodology]: https://dotgibson.github.io/dotfiles-web/docs/reference/offensive-methodology
[dotgibson-shield]: https://img.shields.io/github/v/release/dotgibson/dotfiles-core?style=plastic&label=dotgibson&labelColor=181717&logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAF1klEQVR4nLSWbUxT7RnHr9PT09MXSltaoC9QXkqR16Iwhb0Iw8VYYE7jPri5aBaZzpmFZbpolpn4QeMyM%2BM%2B7MVt0Q9LNJIlxCzqxGWS6aKAig51vBQKIi3QltpCS0%2Fbc879pD1N3%2Bnz4fG5Pl2977v%2F331d131f5%2BZrddWQZAgAgy9uCRlefICzT6GeIsP%2FXF15kahmu9JglGmLRQoRQdIQWgu77BuWGe%2Fo%2BOqym8odApaWomTT1%2Bl2HqirahaTuJ9kQMggkgYhDRGfRiQDZBi9fuf52%2BD7l1b3ZhRcmq%2FMnBHmibuO7fvWoTalVoDjQRwL8RGgEOtzB0MbtBDnkRjGR0AgTK%2BQfNukr1LKXlhXKZpJSxTKGoFSq9vf16tQ8%2FiEh094Vu0L449mLGMup20DRWuFYVCiFm%2BvU36nTbOlMB%2BnCDxIOBzhvv6nFpc3TS0dUKDRHzh1Jk9O8wlPYN326Oa%2FJobnN8shAOxqKjrdXa8WSnGKWPewR%2FuHLG5P8oKUFJHi%2FH19F6UKEQ%2BnbJap27%2B%2BtWR15VAHgLkV%2F%2F0xW6OuQCfNE4PgmyX6f0xZKYbJDuj43lmtoYqHU%2FaZdwNXr4eoUG51zqgw%2B%2FCtrbm0UCeRynBhqVj2YC4RNC%2FuqStbKkydAODzeO7%2B6QYTpnOIYgB729R729RY9DAGafb0wDOHLwAA5vKK1mJNFoCpsxeLLn%2Fy91uU359719%2FfVXL%2BSM35IzU9rcXciCcQujz0imOfbGhOB0jkGo2hFQBW7Quzr0Zzq6vyBT%2FuKY%2BHErfBmQWLK1Lhr6l1OkleCqC0poPb%2FuTwv3OrA8DPDhgkokgLmLX77o86kqcGJmaj5xjr1JWlAAr1Js75MDEGAAI%2B1mvWX%2F1JY29XmYDPS5ZoNsrM24si1xSh3%2FRbGBYlz%2F73g41ztqliqYv1onyVHgDocMjjXASAKycavlqnZBHa2ajcasjv%2B8MbAPhRV9nI5MezB41crIPPHWOW9Gtl9XhDDCMCokIqSwGQ4shvyucFhEQCnqlSdm9k%2BdKt6XM%2FqO7aof7t8YbIIW5SHdpVIhUTAOAP0L8bmM3MHgJwByidQCgnhSmAqOEYnQ8AgRBr%2FuUzKsgggIs3pyVCfkeTCgAmFtaNOgm39C%2F3511r2W8JYvIAJbIaAwQ3vKAEoVgRaTQIBYKxqxgMs6euvdUXiQDgeHd5rV7K1fb2kC2rOgaYghQBMJ5grI3HUGuuhQiNIOWq8sy%2FLTgCKplgT0ZtCyprWw7%2FvKCyNr6yQqYg8cim59a9KQDnwv84R1%2F99UwAzsMya4vxeOYLN7YePGG%2BcAPjxXS%2BoavknFfOlRTAh8nHKNqLa1v2ZwK6dxQZtHk5ahu3%2FcYmLsoh%2B%2FsUgN%2BztDQzEvkYFBurGnan%2FS1%2B1P98L1FbxLIPzh193X%2FtwbmjiGUBYHd5nVFRCABPlxdtfh%2B3LHGKxof%2Bqo90C6yj58yi9Tm1kWjr94ZXsGhTuDuynAx2z0245yY4X06Kf9HWFd0N%2BuPbsUR64%2B3a57Erig2qIoOIlJSUNE69GWTZRFufXvRNL%2Fo2ywyJE1fMP6xWqHBEP5yfvP7%2FbAAAsFufG01mkVCqkGvLyrbNTD2mw9kfDckmE0oudx9rUZfhiF5Zd%2F%2F00QDF0NkBTJhanB3e0riHJIRKhXarqWfdu%2Bx0WnOot1ftuNR90lhQzEO0L7B2YvCm3b%2BWNI%2ByffSLq757%2BPcquYaIvBtgdcXycuzO9MzTFdccd9IwDNMVlDaXbzPXtxsVhQRDEQzl8i6d%2Buf12Y%2BONDVMo6vOfHWJxHLz3l811u8WAEZABCNAAHSI8n8k2HABKRJjLJ8JECxFMAE%2BHXhiGb7yn35vcCNDKVsEcSuv%2BEpn%2B7Etla0CwAQIOBLBhrkt85kAnwm8mX95e%2FTOa9vUZiIxQI43r0Kura9uN5SYNMoyuVDGZ2nK73C65iy28Rezo44152bSKYAvz3ifVA1lDn0WAAD%2F%2F%2FWvXexgMwqgAAAAAElFTkSuQmCC
[dotgibson-url]: https://github.com/dotgibson/dotfiles-core/releases/latest
[ci-shield]: https://img.shields.io/github/check-runs/dotgibson/htpx/main?style=plastic&logo=githubactions&logoColor=white&label=CI
[ci-url]: https://github.com/dotgibson/htpx/actions/workflows/ci.yml
[lastcommit-shield]: https://img.shields.io/github/last-commit/dotgibson/htpx?branch=main&style=plastic&logo=git&logoColor=white
[contributors-shield]: https://img.shields.io/github/contributors/dotgibson/htpx.svg?style=plastic&logo=github
[contributors-url]: https://github.com/dotgibson/htpx/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/dotgibson/htpx.svg?style=plastic&logo=github
[forks-url]: https://github.com/dotgibson/htpx/network/members
[stars-shield]: https://img.shields.io/github/stars/dotgibson/htpx.svg?style=plastic&logo=github
[stars-url]: https://github.com/dotgibson/htpx/stargazers
[issues-shield]: https://img.shields.io/github/issues/dotgibson/htpx?style=plastic&logo=github
[issues-url]: https://github.com/dotgibson/htpx/issues
[license-shield]: https://img.shields.io/github/license/dotgibson/htpx.svg?style=plastic
[license-url]: https://github.com/dotgibson/htpx/blob/main/LICENSE
[markdown-shield]: https://img.shields.io/badge/Markdown-000000?style=plastic&logo=markdown&logoColor=white
[markdown-url]: https://commonmark.org
[attack-shield]: https://img.shields.io/badge/MITRE_ATT%26CK-C22035?style=plastic
[attack-url]: https://attack.mitre.org
[fzf-shield]: https://img.shields.io/github/v/release/junegunn/fzf?style=plastic&logo=gnometerminal&logoColor=24283B&label=fzf&labelColor=BB9AF7&color=3D59A1
[fzf-url]: https://github.com/junegunn/fzf
