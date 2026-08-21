---
id: jenkins-job-backdoor
title: Jenkins job/pipeline backdoor (run code on controller + agents)
section: Jenkins / CI/CD
phase: Execution
attack:
  tactic: TA0002
  techniques: [T1072]
platform: [jenkins]
source: Jenkins abuse (malicious job / pipeline)
pair: jenkins-job-backdoor-audit
---

Jenkins is a deployment tool — abuse it to run code across the estate. Create a job (or
reconfigure one) whose build step runs your payload, then let it execute on the
controller or fan out to build **agents** (harvesting their credentials and reaching the
networks they can). A cron/SCM trigger makes it recurring. Creating a job hits
`/createItem`; reconfiguring one hits `/job/<name>/configSubmit` — both logged by the Audit
Trail plugin. (CI controller — no slots.)

```sh
# create a job whose build step runs attacker code (config.xml carries the payload)
curl -s -u <user>:<api-token> -H "Content-Type: application/xml" --data-binary @config.xml \
  "https://<jenkins>/createItem?name=ci-cache"
```
