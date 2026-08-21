---
id: pypi-publish-audit
title: Detect token release upload (PyPI journal)
detection: pypi-audit-log
event_ids: []
attack:
  tactic: TA0001
  techniques: [T1195.002]
source: PyPI supply-chain compromise (trojanized release)
pair: pypi-malicious-publish
---

`action="new release"` is the invariant. Releases are routine — but a project publishes them
from one known identity, so the tell is a release by an unexpected uploader, from an unusual
IP, out of hours, or a first-ever uploader on a widely depended-on package. Pin releases to
that identity, allowlist it, and alert on any `new release` outside it; a release immediately
after a role/owner change or a token addition is the high-signal sequence.

PyPI journal telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=pypi sourcetype=pypi:journal action="new release" NOT submitted_by IN ("<ci-publisher-identity>")
| table _time, submitted_by, action, name, version, submitted_from
```

**Allowlist the identity, never the actor class** — the same rule as `npm-publish-audit`, and
it bites twice here. The paired attack uploads with a *stolen API token*, so it is recorded as
exactly the same kind of actor as a legitimate token upload; an exclusion on the publishing
*method* would filter out the attacker's own primary path. And `publisher_type` is not a field
the journal emits at all — the public journal carries `action`, `submitted_by`, `name`,
`version`, `submitted_date` and `submitted_from` — so a clause like
`NOT publisher_type=trusted_publisher` is vacuously true in Splunk and quietly degrades the
search into "every release ever published," OIDC ones included. Pin `submitted_by` to the
release identity instead.

Trusted publishing (OIDC) is the secure norm and remains the right thing to *triage* by: a
token upload to a project that normally publishes via trusted publishing is the higher-signal
case, since it bypasses the OIDC path entirely. Where your ingestion enriches releases with
provenance — the project's configured trusted publishers, or PEP 740 attestations on the
uploaded files — carry it as a column to rank hits by, not as a filter clause. A project whose
attestations stop appearing is itself the finding.
