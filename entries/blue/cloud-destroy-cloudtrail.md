---
id: cloud-destroy-cloudtrail
title: Detect cloud data destruction (CloudTrail delete burst)
detection: splunk-cloudtrail
event_ids: []
attack:
  tactic: TA0040
  techniques: [T1485]
source: CloudTrail management events; data-destruction analytics
pair: cloud-snapshot-destroy
---

Destruction is a rare, high-impact verb set on the control plane: `DeleteSnapshot`,
`DeleteDBClusterSnapshot`, `DeleteBucket` / `DeleteObject*` on a versioned bucket,
`DeleteTable`. A single delete may be housekeeping; a *burst* of them across storage
services from one `userIdentity` in a short window — especially from a new IP/role
or with `errorCode` mixed in as it probes — is the pattern. Alert on the aggregate,
and defend structurally with S3 Object Lock, MFA-delete, and cross-account backup
copies the compromised principal can't reach.

> Caveat: `DeleteObject`/`DeleteObjects` are S3 **data events** — *not* logged by
> CloudTrail unless S3 data-event logging is enabled for the bucket. That splits this
> detection in half on a default account: the deny-recovery calls (`DeleteSnapshot`,
> `DeleteDBClusterSnapshot`, `DeleteBucket`, `DeleteTable`) are management events and
> arrive normally, but the destructive payload — an `aws s3 rm --recursive` sweep, which
> is exactly the `DeleteObjects` burst this query counts on — leaves no trace. Where data
> events are off, fall back to **S3 server access logs** / CloudWatch `BytesDeleted` for
> the object-delete burst, and treat the management-event half below as your only
> real-time signal. (Sibling entry `aws-s3-exfil-cloudtrail` carries the same caveat for
> `GetObject`, for the same reason.)

```spl
index=aws sourcetype=aws:cloudtrail (eventName IN ("DeleteSnapshot","DeleteDBClusterSnapshot","DeleteDBSnapshot","DeleteBucket","DeleteObject","DeleteObjects","DeleteTable"))
| bucket _time span=5m
| stats count, dc(eventName) as verbs, values(eventName) as which by _time, userIdentity.arn, sourceIPAddress
| where count>10
| sort - count
```

The `count>10` floor is right for the object-delete burst and wrong for the durable
copies: a *single* `DeleteBucket`, `DeleteTable`, or `DeleteDBClusterSnapshot` is a
finding on its own — there is no volume to wait for, and the burst query above will
never surface one. `DeleteBucket` in particular only succeeds on an already-empty
bucket, so seeing one means the object-delete sweep already happened, whether or not
data events captured it. Run this alongside the burst query, not instead of it:

```spl
index=aws sourcetype=aws:cloudtrail (eventName IN ("DeleteBucket","DeleteTable","DeleteSnapshot","DeleteDBClusterSnapshot","DeleteDBSnapshot"))
| eval actor=coalesce('userIdentity.userName','userIdentity.arn','userIdentity.principalId')
| eval target=coalesce('requestParameters.bucketName','requestParameters.tableName','requestParameters.snapshotId','requestParameters.dBClusterSnapshotIdentifier','requestParameters.dBSnapshotIdentifier')
| table _time, eventName, actor, target, sourceIPAddress, userAgent, errorCode
| sort - _time
```

Each service names its target under a different `requestParameters` key —
`bucketName`, `tableName`, `snapshotId`, `dBClusterSnapshotIdentifier`,
`dBSnapshotIdentifier` — so the `coalesce` above is what makes the row say *what* was
destroyed rather than just that something was. Extend the list as you add services;
a row with an empty `target` means a key is missing from it, not that the call had no
target. Same `eval target=coalesce(...)` shape as `aws-iam-privesc-cloudtrail`.
