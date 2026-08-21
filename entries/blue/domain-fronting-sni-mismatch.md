---
id: domain-fronting-sni-mismatch
title: Detect domain fronting (CDN edge from a non-browser process; SNI vs Host mismatch)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0011
  techniques: [T1090.004]
source: TLS SNI / HTTP Host correlation (Zeek ssl.log + http.log)
pair: domain-fronting-cdn
---

Fronting only works because the SNI and the inner Host differ, so where you can see both, the
mismatch is the invariant. The catch is that seeing both is the hard part, and it is getting
harder — so lead with the arm that does not need decryption: a **non-browser process making
TLS to a CDN edge**, on a repeating cadence, to a rare or recently-registered inner
destination. That shape survives everything in the currency note below, because it reads the
endpoint and the connection pattern rather than the handshake's contents.

```spl
index=sysmon EventCode=3 DestinationPort=443
    NOT (Image IN ("*\\chrome.exe","*\\firefox.exe","*\\msedge.exe","*\\brave.exe","*\\iexplore.exe"))
| lookup cdn_edge_domains domain AS DestinationHostname OUTPUT cdn
| where isnotnull(cdn)
| stats count dc(DestinationHostname) AS Names dc(DestinationIp) AS IPs min(_time) AS first by host, Image, cdn
| sort -count
```

This needs endpoint telemetry, because the process attribution is the point — `ssl.log` alone
cannot tell you *what* opened the connection. With network telemetry only, the substitute is
cadence: the same source beaconing to a CDN edge on a regular interval, which is
`https-beacon-jitter`'s query pointed at CDN destinations.

The SNI≠Host correlation stays as the confirming arm where you have TLS break-and-inspect (or
Zeek pairing `ssl.log` SNI to a decrypted `http.log` Host): alert when the SNI's registrable
domain differs from the Host header on the same connection, excluding the legitimate
multi-tenant vhost case.

```spl
index=zeek (sourcetype=zeek:ssl OR sourcetype=zeek:http)
| transaction uid maxspan=30s
| eval sni_dom=replace(server_name,"^.*\.([^.]+\.[^.]+)$","\1")
| eval host_dom=replace(host,"^.*\.([^.]+\.[^.]+)$","\1")
| where isnotnull(server_name) AND isnotnull(host) AND sni_dom!=host_dom
| table _time, id.orig_h, server_name, host, uri
```

**Currency — three things erode this pair, none of them fatal to it.** *One:* the mismatch arm
needs decryption, and the pinned CDN TLS the technique rides on is exactly what a
break-and-inspect proxy cannot transparently open — so on the traffic that matters most you
often have the SNI and nothing else. *Two:* classic fronting is deprecated on the major CDNs
the paired attack names — CloudFront, Google, Azure and Fastly added SNI/Host matching between
roughly 2018 and 2021 — so against those providers this is a historical technique, and what
remains is smaller or misconfigured CDNs and the domain-*borrowing* variants where SNI and Host
agree and no mismatch exists to find. *Three:* **Encrypted ClientHello** removes the SNI from
cleartext entirely; where ECH is negotiated, the mismatch invariant is not weakened but gone.
Keep the pair — the technique is still worth recognizing and the mismatch is still decisive
where it is visible — but weight your coverage toward the process-and-destination arm, which
none of the three touches.
