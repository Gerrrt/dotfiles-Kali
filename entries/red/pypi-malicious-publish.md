---
id: pypi-malicious-publish
title: PyPI malicious release upload (supply-chain implant)
section: PyPI / registry
phase: Initial Access
attack:
  tactic: TA0001
  techniques: [T1195.002]
platform: [pypi]
source: PyPI supply-chain compromise (trojanized release)
pair: pypi-publish-audit
---

With a stolen PyPI API token, upload a trojanized release of a package you now control.
Every downstream `pip install` — CI runners, developer laptops, images — resolves your
package, and your code runs when an sdist is built (its `setup.py` / PEP 517 backend) or the
package is imported at runtime, so one upload fans out across the dependency graph. A token upload also bypasses the project's OIDC **trusted
publishing** (the secure norm), which is itself the tell. The upload writes a PyPI journal
entry `action="new release"`. (Registry control plane — no on-host target, so no slots.)

```sh
# upload a trojanized release via a stolen API token (bypasses trusted publishing)
twine upload -u __token__ -p "<stolen-pypi-token>" dist/*
```
