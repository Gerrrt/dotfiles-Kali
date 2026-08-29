---
id: pypi-role-add
title: PyPI rogue collaborator add (durable publish rights)
section: PyPI / registry
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [pypi]
source: PyPI supply-chain persistence (project role)
pair: pypi-role-audit
---

Add an attacker-controlled account as an **Owner** (or Maintainer) of the project. Now you
publish forever with your OWN account — the durable version of a stolen token, surviving the
victim's password reset and token revocation — and it blends in among legitimate
collaborator changes. PyPI has no API for this; it is a web-console action, and it writes a
PyPI journal entry `action="add Owner <user>"` (or `add Maintainer <user>`). (Registry
control plane — no slots.)

```sh
# PyPI collaborator management is web-console only (no public API):
#   Manage project → Collaborators → invite <attacker-user> as Owner
# journal records: add Owner <attacker-user>
```
