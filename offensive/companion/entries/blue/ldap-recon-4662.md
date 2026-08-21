---
id: ldap-recon-4662
title: Detect LDAP reconnaissance (4662 targeted reads; 1644 broad filters)
detection: splunk-spl
event_ids: [4662, 1644]
attack:
  tactic: TA0007
  techniques: [T1087.002, T1069.002]
source: TrustedSec AD monitoring; targeted LDAP-query telemetry
pair: ldap-recon
---

Same telemetry as the BloodHound sweep, a different shape. Hand-run LDAP recon does not
fan out across thousands of objects — it issues a *small number of broad, revealing
filters*: `(servicePrincipalName=*)` to find Kerberoastable accounts,
`(userAccountControl:1.2.840.113556.1.4.803:=...)` bitfield queries for
"don't-require-preauth" or "trusted-for-delegation," `adminCount=1` for the protected
groups. So this pairs with the collection detector rather than duplicating it: `4662`
volume catches the graph pull, and the **content of the search** catches the targeted
query that never trips a fan-out threshold.

The catch is that the raw LDAP *filter string* is not in `4662` — that event names the
object and the property GUIDs accessed, not the client's query text. The filter lives in
**1644**, which is why the primary arm here is `1644` (with the same off-by-default DC
diagnostics prerequisite the BloodHound entry states), matching on the tell-tale filter
attributes rather than a volume threshold:

```spl
index=main EventCode=1644
    (Search_Filter="*servicePrincipalName*" OR Search_Filter="*userAccountControl:1.2.840.113556.1.4.803*"
     OR Search_Filter="*adminCount*" OR Search_Filter="*msDS-AllowedToDelegateTo*"
     OR Search_Filter="*trustedForDelegation*")
| table _time, host, Client, User, Search_Filter, Search_Time_ms
| sort -_time
```

Without `1644`, fall back to `4662` on the **property GUIDs** those filters read — a
non-service account requesting `servicePrincipalName` (`28630ebc-41d5-11d1-a9c1-0000f80367c1`)
or `userAccountControl` (`bf967a68-0de6-11d0-a285-00aa003049e2`) across many user objects
is the same intent seen one layer down. It is noisier than the filter match and needs the
Directory Service Access SACL in place, so state that limitation rather than presenting it
as equivalent:

```spl
index=main EventCode=4662 Security_ID!="S-1-5-18"
    (Properties="*28630ebc-41d5-11d1-a9c1-0000f80367c1*" OR Properties="*bf967a68-0de6-11d0-a285-00aa003049e2*")
| bin _time span=5m
| stats dc(Object_Name) AS objects by _time, host, Account_Name
| where objects > 50 | sort -objects
```
