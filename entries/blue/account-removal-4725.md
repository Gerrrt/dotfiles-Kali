---
id: account-removal-4725
title: Detect account access removal (admin disable/delete/reset + group removal)
detection: splunk-spl
event_ids: [4724, 4725, 4726, 4729, 4733]
attack:
  tactic: TA0040
  techniques: [T1531]
source: Windows account-management auditing (4724/4725/4726)
pair: account-lockout-defenders
---

Locking defenders out leaves a clean audit trail: 4724 (password reset attempt),
4725 (account disabled), 4726 (account deleted), and 4733/4729 (removal from a
privileged group). Individually these are ordinary help-desk actions; the impact
pattern is a *burst* targeting privileged or break-glass accounts, by an actor who
doesn't normally administer identity, close in time to other impact signals. Alert
on multiple such events against admin accounts in a short window, and protect
break-glass accounts with alerting on any change to them at all.

```spl
index=wineventlog EventCode IN (4724,4725,4726,4729,4733)
| bucket _time span=10m
| stats count, dc(Target_Account_Name) as targets, values(Target_Account_Name) as who by _time, Subject_Account_Name, EventCode
| where targets>3
| sort - count
```
