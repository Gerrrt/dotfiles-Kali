---
id: pypi-trusted-publisher
title: PyPI rogue trusted publisher (credential-less publish backdoor)
section: PyPI / registry
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [pypi]
source: PyPI supply-chain persistence (OIDC trusted publisher)
pair: pypi-trusted-publisher-audit
---

PyPI **trusted publishing** lets a named external CI identity (e.g. a specific GitHub repo +
workflow) publish to a project over OIDC with no long-lived token. Register a publisher you
control — your own repo/workflow — and you have a durable, credential-less publish path: no
token to revoke, and every future release from your workflow is trusted. It outlives a
password reset and blends in with legitimate CI publishing. It is a web-console action and
writes a PyPI journal entry that adds a trusted publisher to the project. (Registry control
plane — no slots.)

```sh
# PyPI trusted-publisher management is web-console only (no public API):
#   Manage project → Publishing → add a new pending/trusted publisher
#   (owner=<attacker-gh-org> repo=<attacker-repo> workflow=<publish.yml>)
# journal records: an "add ... trusted publisher" entry for the project
```
