# Features and options

[Русский](FEATURES.ru.md)

What podkop-engine adds to sing-box that you can configure: the options of `/etc/config/sing-box`,
the environment of the init script, options of the sing-box JSON configuration and command-line
tools. Fixes and changes that need no configuration are in [CHANGELOG.md](../CHANGELOG.md), each
patch is in [PATCHES.md](PATCHES.md).

"Since rN" names the podkop-engine release. Everything here is on the 1.14 line (`v1.14.4-r27`).
The 1.13 line is no longer built (last release `v1.13.21-r18`); the 1.12 line has only the REALITY
and uTLS patches. The 1.14 line had no r3 and r4: what they brought reached 1.14 in r5. sing-box
without these patches refuses the JSON options below (for example `json: unknown field …`); a program that
writes configurations for several engines checks the [Features line](#the-features-line).

## Contents

- [The package on OpenWrt](#the-package-on-openwrt)
- [Outbounds and transports](#outbounds-and-transports)
- [URL test groups (urltest)](#url-test-groups-urltest)
- [DNS](#dns)
- [Rule-sets (lists)](#rule-sets-lists)
- [Sniffing: BitTorrent](#sniffing-bittorrent)
- [Programs that embed the engine](#programs-that-embed-the-engine)
- [Tools](#tools)
- [Works without configuration](#works-without-configuration)

## The package on OpenWrt

One of two packages is installed. `podkop-engine` has the outbounds podkop writes: direct, socks,
shadowsocks, trojan, vless, hysteria2, tuic, selector, urltest, http (since r15) and block (since
r19). `podkop-engine-full` adds vmess, snell, tor, ssh, shadowtls, anytls, hysteria and naive
(NaiveProxy only on some architectures). Inbounds in both: tproxy, direct, mixed. An outbound of
`podkop-engine-full` fails `sing-box check` in `podkop-engine` with "… not included in this build
(podkop_slim), install podkop-engine-full". Neither package has other inbounds (tun, socks, http,
…), the DNS servers `quic` and `h3`, or the services api and ssm-api: those fail with "… not
included in this build (podkop_slim)". Choosing and switching packages: [INSTALL.md](INSTALL.md).

### Options of /etc/config/sing-box

Section `sing-box.main`. The options of the OpenWrt sing-box package (`enabled`, `user`, `conffile`,
`workdir`, `ifaces`) work as there. An upgrade adds `dns_fallback`, `urltest_download_check`,
`urltest_download_url` and `liveness` with their defaults when they are missing; set values stay.

| Option | Default | What it does | Since |
|---|---|---|---|
| `dns_fallback` | `1` | With podkop installed: a DNS server reached directly through the WAN that fails is answered by the [provider's DNS](#fallback-to-the-providers-dns) | r4 (1.14: r5) |
| `urltest_download_check` | `1` | The [download check](#download-check) before a urltest group switches | r8 |
| `urltest_download_url` | `https://speed.cloudflare.com/__down?bytes=65536` | Its URL: `http://` or `https://` without spaces; since r14 another value is skipped with a line in the log, and the check is off | r8 |
| `memory_limit` | not set: [automatic](#memory-limit) | `off`, or a size in MiB or GiB (`64MiB`, `1GiB`, at most 7 digits), passed as `GOMEMLIMIT`; since r14 another value is skipped with a line in the log | r9 |
| `failsafe` | not set: on | `0`, `off`, `false`, `no` or `disabled` turns the [failsafe service](#failsafe-and-liveness-probe) off, the liveness probe with it | r12 (service since r4; 1.14: r5) |
| `liveness` | `1` | The liveness probe; the same values turn it off | r13 |

```sh
uci set sing-box.main.urltest_download_check=0
uci commit sing-box; service podkop restart     # without podkop: service sing-box restart
                                                # failsafe, liveness: service podkop-engine restart
```

`dns_fallback`, `failsafe` and `liveness` act only with podkop installed.

The init script also sets, with no option: 65536 open files, 15 s for a stop, a crash loop counted
from crashes less than 10 minutes apart (`respawn 600 5 5`), no color codes in the log.

### Environment of sing-box

The init script passes these; a program that runs sing-box itself may set them.

| Variable | Set by the init script | Effect | Since |
|---|---|---|---|
| `SING_BOX_DNS_FALLBACK` | `ubus`, with podkop installed and `dns_fallback` on | Any non-empty value turns the DNS fallback on | r4 (1.14: r5) |
| `SING_BOX_URLTEST_DOWNLOAD_URL` | `urltest_download_url`, when `urltest_download_check` is on | The download check URL of a urltest group without `download_url` | r8 |
| `SING_BOX_RULESET_RECOVERED_HOOK` | `/usr/libexec/podkop-engine/lists-recovered`, with podkop installed | Shell command run when remote rule-sets that failed at start have come (one run for the sets that come within 5 s of each other, another for any that come later); their tags, comma-separated, are in `SING_BOX_RULESET_TAGS` | r2 |
| `GOMEMLIMIT` | from `memory_limit` | Go's memory limit in place of the automatic one | r9 |
| `SING_BOX_UTLS_FALLBACK` | — | Any non-empty value turns the [uTLS fingerprint fallback](#utls-fingerprint-fallback) on for a configuration without `experimental.utls_fallback` | r13 (any value since r17) |
| `SING_BOX_RULE_SET_START_EMPTY` | — | A remote rule-set with nothing cached starts empty at once and downloads in the background, so the start does not wait for it (podkop-experimental sets it; `rule.RemoteStart` in the context of a box overrides it since r29) | r15 |

### Start without lists

When a remote rule-set cannot be downloaded at start (no WAN yet, a wrong clock, a dead first urltest
member), sing-box starts with it empty and tries again after 5, 10 and 20 s, then every 30 s, instead
of exiting with `FATAL … initial rule-set`. When the lists have come, the hook runs
`podkop list_update`, so that podkop's own lists come too. A cached list starts from the cache.
Since r2.

### Memory limit

By default sing-box keeps Go's memory limit at what Go holds plus what the system can still give
(`MemAvailable`, or the rest of a cgroup limit), recomputed after each garbage collection: when memory
runs short, the collector works before the OOM killer does. The start logs
`memory limit <N>, following the available memory`. `memory_limit`, `GOMEMLIMIT` or
`experimental.debug.memory_limit` replaces it. Since r9.

### Failsafe and liveness probe

The service `/etc/init.d/podkop-engine` watches procd's events for sing-box. When sing-box crashes in a loop and procd
gives up, it runs `/etc/init.d/podkop stop`: dnsmasq returns to its usual servers, and the network
works without the proxy. The reason and the router's memory go to the log and to
`/etc/sing-box/failsafe.last`; `service podkop start` starts podkop again. Since r4 (1.14: r5).

The liveness probe (since r13) asks sing-box for podkop's test name through `127.0.0.42` every 20 s.
After three queries in a row without an answer (49–72 s) it kills the process; procd starts it again,
and that counts as a crash. Silence counts only for a process that has already answered with a
FakeIP address;
rounds during `podkop list_update` or while the router itself does not deliver (connection table 95 %
full, no answer to its own ping) do not. A kill leaves `has not answered DNS on 127.0.0.42 for N s`
in the log.

## Outbounds and transports

### XHTTP transport

The client of Xray's XHTTP (SplitHTTP) transport, `"transport": {"type": "xhttp"}`, for any
outbound with a V2Ray transport: vless and trojan, and vmess in `podkop-engine-full`. Field names follow sing-box-extended; a range is `"100-1000"`, `"30"`, a number or
`{"from": 100, "to": 1000}`; an unknown field fails `sing-box check`. Feature name
`transport.xhttp`. Since r11.

```json
"transport": { "type": "xhttp", "mode": "auto", "host": "example.com", "path": "/api/" }
```

| Field | Default | Notes |
|---|---|---|
| `mode` | `auto` | `packet-up`, `stream-up`, `stream-one`; `auto` is `stream-one` with REALITY (`stream-up` with `download`), otherwise `packet-up` |
| `host`, `path`, `headers` | — | `headers` cannot set `Host`, `Upgrade`, `Transfer-Encoding`, `Connection` or `Content-Length` |
| `x_padding_bytes` | `100-1000` | not 0, at most 65536 |
| `uplink_http_method` | `POST` | `GET` only in `packet-up` |
| `sc_max_each_post_bytes` | `1000000`; `4096` when `uplink_data_placement` is `header` or `cookie` | Xray's megabyte does not fit into the 8 KiB of headers a server takes |
| `sc_min_posts_interval_ms` | `30` | |
| `xmux` | when it sets nothing: `max_connections` 3, `h_max_request_times` 600-900, `h_max_reusable_secs` 1800-3000 | `max_connections` and `max_concurrency` exclude each other; also `c_max_reuse_times`, `h_keep_alive_period` |
| `download` | — | another server for the download: `server`, `server_port` (required), `tls`, `detour` and the fields above except `mode`; not with `stream-one` |

Other Xray fields keep their names (`x_padding_*`, `session_*`, `seq_*`, `uplink_data_*`,
`uplink_chunk_size`, `no_grpc_header`); server-side fields are accepted and not used. VLESS `flow`
over XHTTP needs [VLESS Encryption](#vless-encryption). No server side or Browser Dialer; [finalmask](#finalmask) is a dial option of the outbound. Without
hardware AES the cipher matters most: MT7621 (r11, 50 MB) gave 1.9 MB/s with `utls` `chrome`
(AES-GCM first), 3.26 MB/s without `utls` (ChaCha20), 3.75 MB/s without a proxy.

### VLESS Encryption

`encryption` of a vless outbound is the client side of Xray's VLESS Encryption (ML-KEM-768 and
X25519, the whole stream encrypted to the server); a server with `decryption` set takes no client
without it. The value is Xray's client string, as `xray vlessenc` prints it and panels put it into
the link: `mlkem768x25519plus.<native|xorpub|random>.<1rtt|0rtt>[.<padding>…].<key>[.<key>…]`.
Empty or `none`: no encryption. A string Xray would not take fails the start. Since r14.

```json
{ "type": "vless", "server": "192.0.2.1", "server_port": 443, "uuid": "…", "flow": "xtls-rprx-vision",
  "encryption": "mlkem768x25519plus.native.0rtt.<key>", "tls": { "enabled": true, "server_name": "example.com" } }
```

`0rtt` sends data at once on a ticket of the first exchange, `1rtt` makes a full exchange each time.
A key is base64url of 32 bytes (X25519) or 1184 bytes (ML-KEM-768); several keys make a chain;
padding segments, `probability-from-to` such as `100-111-1111` (lengths and pauses in turn), whose
pauses add up to 10 s at most. With `encryption`,
`flow: xtls-rprx-vision` works over any transport and without TLS (an Xray server accepts `flow`
over XHTTP only with VLESS Encryption). AES-GCM with hardware AES, otherwise ChaCha20-Poly1305; a silent server ends the
handshake in 15 s. No server side; no name in the `Features:` line.

### tls.spoof with REALITY

The TLS options `spoof` and `spoof_method` of sing-box 1.14 (and the route option `tls_spoof`) send a
forged ClientHello with the name from `spoof` before the real one, made so that the server drops it
(`spoof_method`: `wrong-sequence` by default, `wrong-checksum`, `wrong-ack`, `wrong-md5`,
`wrong-timestamp`). Here they also work with REALITY, which upstream refuses, and the forged packet
leaves the way the connection goes (mark, interface, source address, TTL). Since r13.

```json
"tls": { "enabled": true, "server_name": "example.com", "spoof": "allowed.example.net",
  "utls": { "enabled": true, "fingerprint": "chrome" }, "reality": { "enabled": true, "public_key": "…", "short_id": "…" } }
```

Limits: root (`CAP_NET_RAW`, `CAP_NET_ADMIN`). Only a connection straight to the TLS server: a
`detour` to a proxy outbound is a configuration error (to `direct` it works); not with
`tcp_fast_open` or a transport of several streams. `wrong-timestamp` needs TCP timestamps,
`wrong-ack` a server kernel 6.7 or a stable one since December 2023. Put in `spoof` a name the filter lets through (one on its whitelist); a name not on the list
did not help.
On one provider (2026-10-08) that cuts a connection after 25 packets unless the first ClientHello has
a whitelisted name, a 200 KB download failed in 8 of 8 runs without `spoof` and passed in 21 of 21
with it (all methods but `wrong-checksum`, which did not help).

### uTLS fingerprint fallback

Off by default; on for the whole configuration with:

```json
"experimental": { "utls_fallback": { "enabled": true } }
```

A TLS or REALITY client with a uTLS fingerprint then watches its handshake. When the ClientHello is
not acknowledged after two retransmissions (about a second on a 50 ms path, 5 s at most) and the
server has sent nothing, it gives the connection up and connects again: with the same candidate
once more if it is the first or has worked on this path, otherwise with the next one:

1. the configured fingerprint without the X25519MLKEM768 key share (`edge`, `ios`, `qq`, `360`,
   `android` have none and go as they are);
2. `firefox` with the key share;
3. the configured fingerprint as it is.

The first candidate answered is kept for the server for 24 hours, in `cache.db` when the cache file
is on. A REALITY server since Xray-core 26.9.8 answers a ClientHello without the key share as a
stranger's: that moves on at once. When no candidate is answered, the fallback rests 30 s (doubling,
up to 10 minutes). `fingerprints` in the section is accepted and not used. Feature name
`tls.utls-fallback`. Since r13; this order and `cache.db` since r17.

Limits: Linux; a TCP connection sing-box opens itself (not through a `detour` to a proxy outbound;
not hysteria2, tuic, shadowtls; not with `tcp_fast_open`, kTLS or ECH from DNS); only a ClientHello
dropped silently. Other connections to a server wait up to 5 s while the first tries candidates. On
a path that freezes bursts of `chrome` ClientHellos (r17, REALITY, Xray 26.6.27), of 20 requests at
once 0 passed with `chrome` alone and 18–20 with the fallback.

### fragment and record_fragment with REALITY

The TLS options `fragment` (the ClientHello in several TCP segments) and `record_fragment` (in
several TLS records) act on a REALITY client too; upstream accepts them there and does nothing. The
server reassembles the same ClientHello, and REALITY verifies it. podkop-experimental offers
`"record_fragment": true` against a freeze by fingerprint: on such a path 0 of 15 connections passed
without it, 15 of 15 with it. Since r24.

### finalmask

Xray's fragment mask (`finalmask` of Xray-core, type `fragment`) as a dial option of an outbound:
it cuts what the outbound writes to the TCP connections it opens itself, beneath TLS, REALITY and
every transport. Feature name `dialer.finalmask`. Since r28.

```json
"finalmask": {"tcp": [
  {"type": "fragment", "packets": "1-1", "length": "100-200", "max_split": "2"},
  {"type": "fragment", "packets": "tlshello", "length": "11-24", "delay": "0"}
]}
```

| Field | Notes |
|---|---|
| `type` | only `fragment`; another type fails `sing-box check` (Xray's other masks need the server) |
| `packets` | `tlshello`: the first write, when it is a whole ClientHello record, cut into TLS records; `N-M` (from 1): writes N to M cut into pieces; empty: every write |
| `length`, `lengths` | the size of a record or piece, a range such as `"11-24"`, drawn as Xray draws it (11 to 23); `lengths`: a range for each piece, the last for the rest |
| `delay`, `delays` | milliseconds after each piece; with `tlshello` a single delay of `0` sends the records in one write, anything else a write per record |
| `max_split` | at most this many pieces, the last one taking the rest |

Masks in a list are chained as in Xray, the first next to the socket: above, the records of the
ClientHello go out in two TCP pieces, the first of 100–200 bytes. On two ISPs that drop the
ClientHello of some servers this form passed 165 of 168 times; `tlshello` alone in one write was
dropped whenever the hello fits one packet (the 508 bytes of `edge` and `ios`), and a write per
record never passed. A pause ends when the connection closes or at its write deadline. With a
`detour` the outbound opens no connection of its own and the mask does nothing; UDP and QUIC are
not touched.

### Certificate pin and other names

`tls.certificate_sha256` (from sing-box 1.15; since r28) pins the SHA-256 of the server's
certificate, base64, a list. A pinned leaf is taken without the roots, a self-signed one too. A
pinned CA of the chain above the leaf, as Xray's `pinnedPeerCertSha256` takes it, becomes the only
root, and the chain is verified to it by name. Not together with `certificate` or
`certificate_path`.

`tls.certificate_server_name` (since r28): the names the certificate is verified by, in place of
`server_name`, which is still sent (Xray's `verifyPeerCertByName`): a server reached by one name
with a certificate for another. With a pinned CA the names verify the chain to it. Refused with
`insecure`; not with REALITY, naive, or the apple and windows engines. Feature names
`tls.certificate_sha256` and `tls.certificate_server_name`.

```json
"tls": { "enabled": true, "server_name": "cdn.example.com", "certificate_server_name": ["origin.example.com"] }
```

### block outbound

`block` is in `podkop-engine` too (since r19) and can be a [urltest fallback](#fallbacks) (since
r20). A connection it refuses is logged at debug, as one the `reject` action refuses; its own line
`blocked connection to …` stays at info.

## URL test groups (urltest)

Options this build adds to an outbound of type `urltest`:

| Option | Default | Since |
|---|---|---|
| `fallbacks` | — | r10; a group of fallbacks alone since r20 |
| `download_url` | `SING_BOX_URLTEST_DOWNLOAD_URL` | r10 |
| `urls` | `url` | r24 |
| `mode` | `fastest` | r24 |
| `loss_url` | — (required by `loss` and `balance`) | r24 |
| `loss_interval` | `30m` (at least `1m`) | r24 |
| `loss_threshold` | `1` (percent) | r24 |
| `balance_size` | `3` (1 to 16) | r24 |
| `balance_idle` | `5m` | r24 |

### Fallbacks

```json
{ "type": "urltest", "tag": "auto", "outbounds": ["vps-1", "vps-2"], "fallbacks": ["backup-vps", "block-out"] }
```

While any of `outbounds` passes its test, the group chooses among them as usual, even when a fallback
is faster. When none passes (no result, or the download check stopped), it takes the first fallback
in list order that has a result, and goes back as soon as a main member passes. A `block` fallback
is not tested and refuses at once; while it is chosen, rounds come after 30 s, then twice as late,
up to the interval. Before the first round after a start or a hot swap ends, no fallback is taken.
`outbounds` may be left out (since r20). A tag cannot be in both lists. The Clash API `/proxies`
ends `all` with them and, since r21, lists them in `fallbacks`. Feature name `urltest.fallbacks`.

### Download check

A server behind a DPI that freezes connections after about 16 KB passes a URL test of a few hundred
bytes. So before switching to a member the group downloads 64 KiB through it; a member whose download
stops is passed over until its next test result. The member in use is not checked; with no other
member a frozen one is taken. Cost: 64 KiB a switch. The group's `download_url` wins over
`urltest_download_url`: `""` turns the check off, a URL turns it on even with
`urltest_download_check=0`; the body must be 64 KiB or more. Feature name `urltest.download_url`.
Since r8; the option of the group since r10.

### Several URLs, median, retry

```json
{ "type": "urltest", "tag": "auto", "outbounds": ["a", "b"],
  "urls": ["https://check-1.example.com/generate_204", "https://check-2.example.com/generate_204"] }
```

One URL a round, in turn, chosen by the clock, so all groups of the process use the same URL in a
round. A member's delay is the median of the last rounds (as many as URLs). A member that did not
answer the URL of the round is tested again with the URL that answered through it last time: it is
down when two URLs fail. With `urls`, `url` is not used. Since r24.

All groups share one tester (since r24): a test another group waits for is not repeated, and tests
through the same first server start 2 s apart. At most 4 URL tests run at once in the process (since
r20; the wait is not part of the timeout), and one loss probe.

### Modes loss and balance

```json
{ "type": "urltest", "tag": "auto", "outbounds": ["a", "b", "c"], "mode": "balance",
  "loss_url": "https://speed.cloudflare.com/__down?bytes=1048576", "balance_size": 2 }
```

- `loss`: delays weighed by the loss of the members. Every `loss_interval` the member in use and
  the three best others download 256 KiB from `loss_url`; a member the group would switch to without a
  fresh count first downloads 1 MiB in the background. Loss that all counted members show is the
  line's and moves nothing. On the stand a page cost 59 + 4.85·RTT + p·(155 + 1.2·RTT) ms (RTT in ms,
  p the loss in percent): 0.8 % at 20 ms costs what a clean member at 50 ms does (a member over TCP; a hysteria2 or tuic
  member pays much less at short RTTs: 1 % costs ×1.03 at 20 ms, ×1.44 at 100 ms).
- `balance`: connections are spread by source address over at most `balance_size` best members
  (within `tolerance`, loss not above `loss_threshold`). A device stays on its member, leaves it at
  once when it fails, and is spread again after `balance_idle` without connections.

The probes run while the group carries connections (since r29): a group that is the fallback of
another downloads nothing while the outbounds of that group answer. Its first choice goes by delay.
The members it then probes and has no count of (the one in use and three others; in a balance those
in it and two more) are each probed with 1 MiB once, one at a time, so loss decides within seconds;
after that with 256 KiB every `loss_interval`. A member has one such probe in a `loss_interval` at
most, and counts are kept for 24 hours. `idle_timeout` after the last connection the probes stop: a
shorter `idle_timeout` (at least `interval`) on a fallback group stops them sooner once the group
above has its outbounds back. A group that was idle tests its members at its first connection.

A balance rests while the group carries no connections: it goes by its one choice, as `fastest`. The
first connection after that is spread at once, by the delays; the download tests of the members run
from then, and a member that fails one leaves the balance. A member that passed it within the
`loss_interval` is not tested again. `/proxies` shows no `balance` while it rests, an empty one when
no member is in it.

`loss_url` should serve 1 MiB or more. The probe counts the lost segments of its own TCP connection
(packet socket, root). A hysteria2 or tuic member is counted by its QUIC packets (since r27) when
`loss_url` takes a `bytes` parameter or HTTP Range; otherwise it goes by delay, as a member over a
multiplexed transport does. The Clash API `/proxies` shows `mode`, `balance` and each member's `loss`
over 1–24 hours. Since r24.

## DNS

### Fallback to the provider's DNS

Turned on by `SING_BOX_DNS_FALLBACK` (option `dns_fallback`, with podkop installed). It covers a
server sing-box reaches through a plain socket (no `detour` or a `detour` to `direct`; no
`bind_interface`, `routing_mark`, bind address, netns) at a public address or a domain name; servers
behind a proxy or a group, the VPN sections of podkop and local or private resolvers are left alone.
Since r4 (1.14: r5).

- No answer in 3.5 s, a refused or reset connection, a TLS or HTTP error, or SERVFAIL: the query is
  asked of the provider's DNS (netifd, over ubus); its answers live 60 s at most. Two failures in a
  row (not SERVFAIL) set the server aside, tested by a copy of a query after 30 s, up to every 5
  minutes. A provider that fails twice turns the fallback off for that server for a minute.
- The provider's servers: of the device sing-box binds to (`auto_detect_interface`,
  `default_interface`); without binding (since r16), of every uplink with a default route, not a
  tunnel, each asked through its uplink. With mwan3 such a socket needs an `ip rule` before mwan3's
  rules that sends it to the main table; podkop-experimental adds one.
- The log tells at warn (since r14): `server <tag> falls back to provider DNS when it fails` or
  `no provider DNS fallback for server <tag>: <reason>`.

### Group of servers and the provider's DNS

Two DNS server types (since r21):

```json
"servers": [
  { "type": "https", "tag": "dns-1", "server": "dns.example.com" },
  { "type": "provider", "tag": "dns-2" },
  { "type": "udp", "tag": "dns-3", "server": "192.0.2.53" },
  { "type": "group", "tag": "dns-server", "servers": ["dns-1", "dns-2", "dns-3"], "strategy": "order" }
]
```

- `provider` (no options) asks the provider's DNS the way the fallback does; when the router knows
  none, the query fails at once.
- `group` asks its `servers` (not `group`, `fakeip` or `hosts`). `strategy`: `order` (default) in
  list order; `fastest` the fastest by smoothed time first, measuring the others with background
  copies. NOERROR and NXDOMAIN are answers; other codes move to the next member.
- An attempt waits 4 smoothed times of the member, 1.5 to 3 s (3 s unmeasured); the last one only the
  query's deadline. After a timeout with more than one member left, the rest are asked together
  (since r25). Two failures in a row set a member aside, tested after 30 s, up to every 5 minutes.
- With the fallback on, a group without `provider`, one of whose members would have the fallback
  alone, asks the provider when every member failed.

Closed stand, three servers of 80, 20 and 40 ms: `order` gave a median of 82 ms, `fastest` 22 ms with
copies for 0.6 % of the queries.

### ipv6_if_no_ipv4

```json
"dns": { "strategy": "ipv4_only", "ipv6_if_no_ipv4": true }
```

With `ipv4_only`, the AAAA question goes out when the A question of the same name through the same
server got a successful answer without A records: a site with IPv6 alone opens. A name with IPv4
still gets an empty AAAA, FakeIP names are not touched. sing-box's own lookups (an outbound's
server, the `resolve` action) and `ipv4_only` in a DNS rule follow the option. With the DNS cache off
each AAAA costs one more A query. Off by default; podkop-experimental turns it on. Since r17.

## Rule-sets (lists)

### Format text

```json
{ "type": "remote", "tag": "my-list", "format": "text", "url": "https://example.com/domains.txt" }
```

A local or remote list in plain text, one item a line. A domain (with a dot, or beginning with `.` or
`+.`) matches itself and its subdomains (`domain_suffix`); an IP address or CIDR matches the
destination (`ip_cidr`); `#` and `//` begin a comment. Other lines are skipped; a list without a
single item (a block page in its place) is an error. Since r15.

### Download fallbacks and paths

Two options of an HTTP client, used by the remote rule-sets that name it:

```json
"http_clients": [
  { "tag": "via-proxy", "detour": "proxy-1" },
  { "tag": "lists", "fallback": ["via-proxy"] },
  { "tag": "lists-any", "outbounds": ["direct", "proxy-1", "proxy-2"] }
],
"route": { "rule_set": [
  { "type": "remote", "tag": "my-list", "format": "binary", "url": "https://example.com/list.srs", "http_client": "lists-any" }
] }
```

- `fallback` (since r25): tags of clients of `http_clients`. A list that did not come through its own
  client (an error, a foreign answer, 30 s without data, not a list) is downloaded again through each
  fallback in turn, each with its own 30 s.
- `outbounds` (since r26): only on a client of `http_clients`, not with `detour` or `fallback`; the
  ways its downloads may take. For a host, the way that brought its last file goes first, then the
  first of the list, ways known to work (faster first), the unknown, and those that failed for it.
  The next way starts beside the running ones after 4 s without an answer or a 1 s pause in the body
  (3 s after the first MiB), three at most; the first answer that parses as a list wins. Times from
  1200 downloads a client (Filogic 820, MT7621, x86): the slowest working answer 3.78 s, the longest
  pause in a body 0.94 s.

### Where lists are stored

A remote list is kept in a file beside the cache file, `<path of cache.db>.rule-sets/<tag>-<hash>`,
not inside it (since r18); lists of an earlier release are moved at start, and going back makes it
download them again. A 304 answer writes only the time of the check (since r16). A list over 50 MiB is
refused; lists of 1 MiB and more update one at a time.

## Sniffing: BitTorrent

The sniffer `bittorrent` (in the default set of the `sniff` action) recognises the UDP socket of a
torrent client. DHT (BEP 5) is a new packet sniffer: the client sends DHT, uTP and the UDP tracker
from one socket, and its first packet, a DHT query, decides the protocol of the socket. uTP is taken
only from a SYN, as Xray does; of 200 000 random packets of 40–1400 bytes none was taken for uTP or
DHT, and a WireGuard tunnel is not taken for uTP (since r18). Since r27.

```json
"rules": [ { "action": "sniff" }, { "protocol": "bittorrent", "outbound": "direct" } ]
```

## Programs that embed the engine

Go APIs that podkop-experimental uses; neither `config.json` nor the command line reaches them.
The two below are the larger ones; every symbol, option, variable and text such a program relies
on is in [EMBEDDING.md](EMBEDDING.md).

### Outbounds replaced while sing-box runs

```go
// package box (github.com/sagernet/sing-box)
func (s *Box) UpdateOutbounds(outbounds []option.Outbound, remove []string, limit int) (OutboundUpdate, error)
```

Builds and starts the new outbounds under their tags in the running box and takes out the tags in
`remove`. New connections go through the new objects; the old ones close when the Clash API lists no
connection through them, after 2 minutes to a day (an older connection through a shared transport —
gRPC, HTTP/2, XHTTP, QUIC, multiplex — is cut then). A replaced urltest group hands its choice over.
Refused: an outbound that stays goes through one that changes, or more than `limit` replaced
outbounds (not groups; `0`: no limit) still carry connections; a refused update changes nothing. A
`detour` (HTTP client, DNS server, XHTTP download) finds its outbound by tag at each dial. Since r19.

### Block detector

With the cache file on, the engine records for each REALITY server whether no ClientHello was
answered, whether the handshake failed after an answer, and whether the server refused the first
fallback candidate as a stranger's (Xray-core since 26.9.8), with the fingerprint in use
(`adapter.CacheFile.LoadDetectOutcome`). Connections count bytes both ways and know whether the
remote side ended the stream; the URL test history keeps the last failed test and the last download
check. Nothing of this changes a connection. Since r21. Also: `adapter.DNSGroupTransport`,
`adapter.DNSProviderTransport` (r21).

## Tools

### sing-box tools decode-link

```sh
echo 'vless://…@example.com:443?type=xhttp&security=tls&…#name' | sing-box tools decode-link --compact
```

Prints the outbound of one share link (stdin or an argument): status 0 and JSON, with `warning: …`
lines on stderr; 2 and one `error: …` line when the link cannot be used; 1 otherwise. Messages never
repeat the link. The outbound is built by the code of `sing-box check`, so what is printed this
binary accepts. Schemes: `vless`, `trojan`, `ss`, `socks` (also `socks4`, `socks4a`, `socks5`, `socks5h`), `hysteria2`/`hy2`, `tuic`,
`http`/`https`; in `podkop-engine-full` also `vmess`, `hysteria`, `anytls`, `naive+https`/`naive+quic`.
Any other option: `sb.<path>` (`sb.tls.record_fragment=1`). Feature name `tools.decode-link`. Since
r11, all protocols since r13. Every parameter: [LINKS.md](LINKS.md) (in Russian).

### The Features line

```
$ sing-box version
sing-box version 1.14.4-pdk-r28
…
Features: urltest.fallbacks,urltest.download_url,transport.xhttp,tools.decode-link,tls.utls-fallback,dialer.finalmask,tls.certificate_sha256,tls.certificate_server_name
```

The last line of `sing-box version` (since r11) names what this build adds that a configuration or a
script may depend on: `urltest.fallbacks` and `urltest.download_url` (the options since r10),
`transport.xhttp`, `tools.decode-link`, since r13 `tls.utls-fallback`, and since r28
`dialer.finalmask`, `tls.certificate_sha256` and `tls.certificate_server_name`. A name is never removed
and never changes its meaning; podkop does not write an option whose name is missing. Options
without a name are told by the version (`-pdk-rN`).

Neither package has the API service. `podkop-engine` also has no `sing-box tools networkquality`,
`sing-box tools stun` or `sing-box schema` (since r26); `podkop-engine-full` keeps these three.

## Works without configuration

In short; details in [CHANGELOG.md](../CHANGELOG.md) and [PATCHES.md](PATCHES.md).

- REALITY and uTLS fingerprints as the Xray 26.9.9 client (X25519MLKEM768, version 26.3.27).
- DNS: a socket per UDP query to a server reached without a proxy; DoH and DoT hold under loss.
- FakeIP: the table lives in memory, `cache.db` is written in the background; after a crash no
  address goes to another domain. Going back to an earlier release or to stock sing-box keeps
  cache.db readable, but the names it knew get new addresses once.
- urltest: a member whose connections fail or stay silent is tested at once and left.
- Lists in compact structures; less memory per connection; a panic in a sniffer costs one
  connection. A uTLS fingerprint on hysteria, hysteria2 or tuic is dropped with a warning.
- REALITY: the fingerprints `android` and `360` are a configuration error, `edge`, `ios` and `qq` a
  warning (Xray-core 26.9.8+ servers refuse them); a `short_id` over 16 hex digits is an error.
