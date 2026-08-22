---
id: dga-nxdomain-entropy
title: Detect DGA beacons (NXDOMAIN burst + label entropy)
detection: splunk-spl
event_ids: [22]
attack:
  tactic: TA0011
  techniques: [T1568.002]
source: Sysmon DnsQuery (Event ID 22) + DNS resolver NXDOMAIN logs
pair: dga-c2-domains
---

A DGA host generates far more domains than register, so it leaves a trail of failed
resolutions to names no human would type: high character randomness, no dictionary
words, unusual TLD spread. Alert when a single `Image`/host produces a burst of
distinct NXDOMAIN (or QueryStatus≠0) results whose labels are long and vowel-poor
in a short window — a self-contained proxy for the entropy a `dns_entropy` macro
would score if you have one. Sysmon 22 gives the process; the resolver's NXDOMAIN
log gives the failures — either alone works, together they're high fidelity.
Baseline out telemetry/antivirus clients that probe many names.

```spl
index=sysmon EventCode=22 QueryStatus!=0
| eval label=mvindex(split(QueryName,"."),0), llen=len(label)
| eval vowels=llen-len(replace(lower(label),"[aeiou]","")), vowel_ratio=vowels/llen
| stats count as nxdomains, dc(QueryName) as uniq, avg(llen) as avg_len, avg(vowel_ratio) as avg_vowel by Image, host
| where nxdomains>50 AND avg_len>12 AND avg_vowel<0.3
| sort - nxdomains
```
