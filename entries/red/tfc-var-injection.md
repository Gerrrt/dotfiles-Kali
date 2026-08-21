---
id: tfc-var-injection
title: Terraform Cloud variable injection (run code / exfil at apply)
section: Terraform Cloud / IaC
phase: Execution
attack:
  tactic: TA0002
  techniques: [T1072]
platform: [terraform]
source: Terraform Cloud IaC abuse (workspace variable injection)
pair: tfc-var-audit
---

Terraform Cloud is a deployment tool — abuse it to run code across the estate. Inject an
**environment variable** into a workspace and the next plan/apply carries it: a
`TF_CLI_ARGS`/`TF_CLI_CONFIG_FILE` pointing at an attacker provider mirror runs your
binary at plan time, or a planted cloud credential redirects `apply` at your account.
No config PR, no review — the variable is the payload. Setting it writes a
`resource.type=variable` `resource.action=create`/`update` audit event. (IaC control
plane — no slots.)

```sh
# inject an env var (category=env) that hijacks the run (e.g. a rogue provider mirror)
curl -s -H "Authorization: Bearer <token>" -H "Content-Type: application/vnd.api+json" \
  -d @var.json "https://app.terraform.io/api/v2/workspaces/<ws-id>/vars"
```
