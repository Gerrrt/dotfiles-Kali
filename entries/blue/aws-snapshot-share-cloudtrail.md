---
id: aws-snapshot-share-cloudtrail
title: Detect cross-account snapshot / AMI sharing (CloudTrail management events)
detection: splunk-cloudtrail
event_ids: []
attack:
  tactic: TA0010
  techniques: [T1537]
source: CloudTrail management events; cross-account resource-sharing grants
pair: aws-snapshot-share-exfil
---

The invariant is a **share grant whose grantee is outside the organisation**:
`ModifySnapshotAttribute`, `ModifyImageAttribute`, `ModifyDBSnapshotAttribute`, or
`ModifyDBClusterSnapshotAttribute` adding a principal that is not one of your own
accounts. Cross-account sharing is legitimate and routine — DR copies, shared golden
AMIs, an analytics account — so the account allowlist is what makes this a detection
rather than a report; without it the query returns your backup pipeline every night.

Two tiers, and they are worth splitting because only one needs tuning. A grant to
`group: all` makes the snapshot or AMI **public** and is a finding on its own with no
allowlist at all — there is no benign reading of publishing a production volume. A
grant to a named `userId` needs the org-account list to be worth anything. Deploy the
public arm first; it is correct on day one.

Structurally: deny `ec2:ModifySnapshotAttribute` / `ModifyImageAttribute` and the RDS
equivalents to everything but a break-glass role via SCP, and prefer AWS Backup's
cross-account vaults — an explicitly modelled destination beats an ad-hoc grant.

> Caveat, because it is the reverse of the sibling entries' problem: these are
> **management** events, so unlike `aws-s3-exfil-cloudtrail` and
> `cloud-destroy-cloudtrail` — which both go half-blind without S3 data-event logging
> — they are in every trail by default and need no extra telemetry. What you *cannot*
> see is the other half: the attacker's `CopySnapshot` runs in **their** account and
> never touches your trail, exactly as `CopyObject` is recorded against the
> destination bucket. The grant is therefore the only observable you will ever get,
> which makes missing it terminal rather than merely inconvenient.
>
> That also rules out inventory-based detection. A share → copy → un-share sequence
> completes in seconds, and `--operation-type remove` leaves the snapshot's permission
> list clean, so a nightly "which snapshots are shared?" sweep — the obvious posture
> check, and what most CSPM tooling does here — sees nothing. Only the event stream
> catches it.

```spl
index=aws sourcetype=aws:cloudtrail (eventName IN ("ModifySnapshotAttribute","ModifyImageAttribute","ModifyDBSnapshotAttribute","ModifyDBClusterSnapshotAttribute"))
| eval actor=coalesce('userIdentity.userName','userIdentity.arn','userIdentity.principalId')
| eval target=coalesce('requestParameters.snapshotId','requestParameters.imageId','requestParameters.dBSnapshotIdentifier','requestParameters.dBClusterSnapshotIdentifier')
| eval grantee=coalesce('requestParameters.createVolumePermission.add.items{}.userId','requestParameters.launchPermission.add.items{}.userId','requestParameters.valuesToAdd{}')
| eval public=coalesce('requestParameters.createVolumePermission.add.items{}.group','requestParameters.launchPermission.add.items{}.group')
| where isnotnull(grantee) OR public="all" OR grantee="all"
| search NOT grantee IN ("<your-org-account-ids>")
| table _time, eventName, actor, target, grantee, public, sourceIPAddress, userAgent, errorCode
| sort - _time
```

Each service names its grantee under a different `requestParameters` key — EC2
snapshots under `createVolumePermission`, AMIs under `launchPermission`, RDS under a
flat `valuesToAdd` list — so the `coalesce` is what makes the row say *who* the data
went to rather than only that something was shared. Same shape as
`cloud-destroy-cloudtrail`'s `eval target=coalesce(...)`, and it fails the same way: an
empty `grantee` on a row means a key is missing from the list, not that the grant had
no recipient. RDS also accepts the literal string `all` in `valuesToAdd` rather than a
separate group field, which is why `grantee="all"` is tested alongside `public`.

CloudTrail telemetry (Splunk `aws:cloudtrail` / Athena / Sentinel `AWSCloudTrail`),
companion-only — `PURPLE-TEAM.md` is on-prem Windows.
