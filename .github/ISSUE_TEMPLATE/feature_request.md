---
name: Feature request
about: A tool, helper, or workflow this layer should carry
labels: enhancement
---

## What & why

<!-- What should exist, and what engagement problem it solves. -->

## Which layer owns it?

<!-- Tick one. This is the question that decides where the change lands. -->

- [ ] **Offensive role** (`offensive/`) — changes with the operator; engagement
      scaffolding, a field-reference entry, a helper
- [ ] **OS layer** — changes with the distro; a package, a path, a clipboard or status
      detail. This belongs in
      [dotfiles-Debian](https://github.com/dotgibson/dotfiles-Debian) (it covers Kali),
      not here — this repo has no `os/` layer
- [ ] **Core** — identical on every machine. This belongs in
      [dotfiles-core](https://github.com/dotgibson/dotfiles-core), not here
- [ ] **Companion corpus** — a paired red/blue entry belongs in
      [htpx](https://github.com/dotgibson/htpx)

## If this is a new tool

- Package name on Kali (`apt-cache policy <name>`):
- If not packaged, how it installs:
- Does it replace something already here?

<!-- This repo installs nothing by default: your OS-native layer (dotfiles-Debian,
     which covers Kali) owns packages. `./bootstrap.sh --install` is the opt-in — apt
     from install/offensive-packages.txt on Kali, a small pipx/go subset elsewhere.
     Both routes verify their own downloads; a `curl | sh` installer will not be
     added. -->
