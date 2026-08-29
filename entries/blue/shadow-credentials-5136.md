---
id: shadow-credentials-5136
title: Detect Shadow Credentials (5136 msDS-KeyCredentialLink write)
detection: splunk-spl
event_ids: [5136]
attack:
  tactic: TA0006
  techniques: [T1556]
source: Elad Shamir, "Shadow Credentials: Abusing Key Trust Account Mapping" (SpecterOps, 2021)
pair: shadow-credentials-certipy
---

The attack *must* write the `msDS-KeyCredentialLink` attribute — so a `5136`
directory-object-modified event naming that attribute is the invariant. Almost
nothing legitimately writes it except Windows Hello for Business enrollment, so
scope out those known sources and alert on the rest. (Requires the directory-
service-access audit subcategory + a SACL on the objects.)

```spl
index=main EventCode=5136 Attribute_LDAP_Display_Name="msDS-KeyCredentialLink"
| table _time, host, Subject_Account_Name, Object_DN, Operation_Type
```
