---
name: Bug report
about: Something in this layer misbehaves (bootstrap, the offensive stage, the OS overlays)
labels: bug
---

<!-- Anything under core/ or offensive/companion/ is vendored — please report those
     upstream instead (links on the "New issue" chooser). -->

## What happened

## What you expected

## Reproduce

```sh
# the exact command(s)
```

## Environment

- Kali version: <!-- grep VERSION_ID /etc/os-release -->
- WSL2 or bare metal:
- Vendored Core: <!-- grep core_tag core.lock -->
- Bootstrap flags used: <!-- e.g. --links-only, --no-offensive, --dry-run -->

## Output

<!-- Paste the failure. SANITIZE IT: no client names, target IPs/hostnames/domains,
     credentials, or scan output — this is a public repo. -->

```text

```

## Checked

- [ ] `./bootstrap.sh --dry-run` shows the plan I expected
- [ ] `make lint` and `make test` pass on a clean checkout
