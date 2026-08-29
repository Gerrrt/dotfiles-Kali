---
id: gl-protected-branch-off
title: Remove protected-branch rules (merge unreviewed code)
section: GitLab / CI/CD
phase: Defense Impairment
attack:
  tactic: TA0112
  techniques: [T1685]
platform: [gitlab]
source: GitLab supply-chain abuse (protected-branch tamper)
pair: gl-protected-branch-audit
---

Protected branches + required approvals are the control that stops unreviewed code
reaching `main` (and the pipeline that deploys it). With Maintainer/Owner, delete the
protection, push or merge your code, then (optionally) re-create it to cover tracks.
Attacker code lands in the protected branch and flows straight into CI/CD. The delete
writes a `protected_branch_removed` audit event; a re-create writes
`protected_branch_created`. (Cloud CI — no slots.)

```sh
# drop protection on main, land code, then it can be re-created to cover tracks
curl --request DELETE --header "PRIVATE-TOKEN: <token>" \
  "https://<gitlab>/api/v4/projects/<project_id>/protected_branches/main"
```
