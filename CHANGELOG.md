# Changelog

[Русский](CHANGELOG.ru.md)

Releases are tagged `v<sing-box version>-r<N>`; one revision number covers every sing-box line built
in it (`v1.13.21-r18` and `v1.14.4-r18` are one release). Each entry lists what changed against the
previous release and what it means for a user; a line is named only where a change applied to one
line. What each patch does: [docs/PATCHES.md](docs/PATCHES.md); the options: [docs/FEATURES.md](docs/FEATURES.md);
full notes and packages: [GitHub releases](https://github.com/podkop-net/podkop-engine/releases).

## r28 — 2026-11-21

sing-box 1.14.4

- **outbounds:** `finalmask`, Xray's fragment mask in the dialer: the ClientHello cut into small TLS records beneath TLS, REALITY and every transport. On two Russian ISPs that drop the ClientHello of some servers, records of 11–24 bytes in two TCP pieces got through 165 of 168 times, a whole hello never.
- **tls:** `certificate_sha256` of sing-box 1.15 pins the server's certificate (a self-signed one too) or, as Xray does, a CA of its chain; `certificate_server_name` verifies the certificate by other names than the one sent (Xray's `vcn`).
- **decode-link:** links give `fm` (`finalmask`; in Hysteria 2 links salamander, gecko and port hopping), `pcs` and `pinSHA256` (`certificate_sha256`), `vcn` (`certificate_server_name`): servers with self-signed certificates connect now. Hysteria's `realm` stays refused.
- **urltest, probesock, detector:** a balance holds 4096 devices at most; a test reads 64 KB of response headers at most; the prober no longer keeps replaced outbounds; a far end cannot hold a loss probe; a server's handshake outcome is written to the cache file at a bounded rate.
- **version:** the Features line adds `dialer.finalmask`, `tls.certificate_sha256` and `tls.certificate_server_name`.

## r27 — 2026-11-15

sing-box 1.14.4 · podkop-exp 0.8.16, 0.8.17

- **sniffing:** uTP is recognized only by its SYN, as in Xray, and DHT (BEP 5) is a new packet sniffer, so a rule `protocol: bittorrent` sees the sockets of qBittorrent, Transmission, aria2 and rTorrent. None of 200,000 random packets is taken for BitTorrent (the old check passed about one in 6400).
- **urltest:** in the modes `loss` and `balance`, the loss of hysteria2 and tuic members is counted from the packets of their QUIC connection, at a price measured for hysteria2 (forks podkop-net/quic-go and podkop-net/sing-quic). Before, such a member was chosen by its delay alone.

## r26 — 2026-11-14

sing-box 1.14.4 · podkop-exp 0.8.15

- **package:** the 1.13 line is no longer built; its last release is `v1.13.21-r18`. The engine for podkop 0.7.24 is `v1.14.4-r26` or newer.
- **lists:** an HTTP client of `http_clients` takes a list of ways, `outbounds`, instead of `detour`. A download starts with the way that brought the host's last file; the next way starts beside it when the first is silent or stalls, at most three at once. Stand with the first three rules dead and the direct way closed: the list in 12 s (r25: not in 180 s).
- **CPU:** the route of a new UDP session and its DNS exchange run on goroutines kept warm, and debug lines are built only when they are logged. Filogic 820: 12–21 % less CPU per query at 500 queries a second than r25; saturation at 1773 queries a second instead of 1285.
- **protocols:** hysteria2 without hardware AES: Chrome's QUIC ClientHello offers ChaCha20 first, as Chrome does (fork podkop-net/quic-go). MT7621, 32 MB downloads: 1.9 MB/s instead of 1.2, as on 1.13.21.
- **package:** `podkop-engine` no longer has the networkquality, STUN and schema tools: the binary is 328 KB smaller on aarch64 and 459 KB on mipsel.

## r25 — 2026-11-12

sing-box 1.14.4 · podkop-exp 0.8.14

- **DNS:** a server of the type `group` asks the rest of its servers at once after one gave no answer in time; before, each waited for its own timeout. Stand with four DoH servers dropped: the first answer in 6.0 s (r24: none).
- **lists:** an HTTP client may name `fallback` clients: a remote rule-set whose download fails or stalls repeats it through each of them in turn. Stand with the direct way to the list dropped: the list in 5 s through the server of a rule (r24: not in 121 s).
- **package:** the binary carries the GODEBUG defaults of upstream releases (`multipathtcp=0`, `tlssha1=1`), so listening sockets are no longer opened as MPTCP. The patch series is regrouped, one patch per feature in layers; the regrouping itself changes no code.

## r24 — 2026-11-12

sing-box 1.14.4 · podkop-exp 0.8.13

- **urltest:** the option `urls` takes several test URLs, one per round in turn, the same in every group; the delay of a member is the median of the last rounds, and a member that fails the URL of a round is tried again with a URL that answered through it before. One tester serves every group, and tests behind the same first server start 2 s apart.
- **urltest:** the option `mode`: `fastest` (the default, as before), `loss` (delays weighed by the loss a 256 KB probe counts from the packets of its own TCP connection) and `balance` (connections spread by source address over the best members).
- **REALITY, uTLS:** `fragment` and `record_fragment` act on a REALITY ClientHello, as on a uTLS one; before they were accepted and ignored. On a path that freezes connections by fingerprint: 15 of 15 connections with `record_fragment`, 0 of 15 without.
- **package:** the sing-box fork is exactly the upstream tag plus the patches of this repository, checked on every build.

## r22, r23 — not released

Built for podkop-exp only: 0.8.10 used r22, 0.8.11 and 0.8.12 used r23. Their changes (urltest with several URLs, the modes `loss` and `balance`) were first released in r24.

## r21 — 2026-11-03

sing-box 1.14.4 · podkop-exp 0.8.9

- **DNS:** new server types: `group` asks its servers in the order of the list, or the fastest by measured time first, and sets a failing one aside; `provider` asks the provider's DNS servers that netifd knows. A group of only local or private resolvers gets no provider fallback.
- **embedding:** for programs that embed sing-box (the Go backend of podkop-exp): per REALITY server, the cache file records whether ClientHellos went unanswered, the handshake failed or the first fingerprint candidate was refused; connections count their bytes and learn whether the remote side ended the stream; the URL test history keeps the last failure and the last download result.
- **urltest:** a failure cut short by the end of a round or by the caller no longer counts as a failure of the member.
- **Clash API:** `/proxies` names the `fallbacks` of a urltest group, so a client can tell a server that did not answer from a fallback that was not tested.
- **fixes:** a ws or httpupgrade dial ends with its context instead of waiting on a server that never answers the upgrade; `decode-link` accepts valid JSON with spaces and addresses in `extra` (a subscription of such XHTTP links was left without servers).

## r20 — 2026-10-30

sing-box 1.14.4 · podkop-exp 0.8.8

- **urltest:** a group may have `fallbacks` and no `outbounds`. A `block` fallback is never tested and refuses connections when nothing before it answers; while it is the choice, rounds come sooner than the interval (from 30 s, doubling), so the servers come back soon after the network that failed them.
- **urltest:** until a round has tested the members (a start, a replacement while running), no fallback is taken: the first member is the choice, as without fallbacks.
- **urltest:** at most four URL tests run at once in the whole process, whatever the number of groups. Stand with 120 servers on two rules: at most 6 test connections at once instead of 20.

## r19 — 2026-10-29

sing-box 1.14.4 · podkop-exp 0.8.7

- **embedding:** `Box.UpdateOutbounds` replaces outbounds of a running sing-box under their tags (used by the Go backend of podkop-exp): new connections take the new outbounds, open ones keep theirs, and a replaced outbound is closed once nothing uses it (after a day at most).
- **embedding:** a `detour` (the HTTP client of the lists, a DNS server, the download leg of XHTTP) finds the outbound of its tag at every dial, so a replacement reaches it.
- **protocols:** the `block` outbound is in `podkop-engine` too, not only in `podkop-engine-full`; a connection it refuses is logged at debug, as one the `reject` action refuses.

## r18 — 2026-10-27

sing-box 1.13.21, 1.14.4 · podkop-exp 0.8.5, 0.8.6 · the last release of the 1.13 line

- **package:** 1.14 moves to sing-box 1.14.4. Among upstream's changes: a repeated tag among the members of one group is a configuration error, the rule action `direct` is gone, and the Clash API on `0.0.0.0` listens on IPv4 only.
- **urltest:** sing-box 1.14.4 dials the member a URL test chose past the group; this build still dials through the group, so a member that fails or stays silent is tested out of turn and left at once (1.14).
- **lists:** the content of a remote rule-set lives in a file of its own beside cache.db, not inside it; lists of an earlier version are moved out and cache.db is compacted. 34 MB of lists: cache.db was 106 MB after the first update, now 32 KB plus the files. Lists of 1 MiB or more are updated one at a time.
- **transports:** xhttp closes the idle connections of its pool when sing-box closes those of an outbound nothing references, not after 5 minutes (1.14).
- **sniffing:** the first packet of a WireGuard tunnel is no longer taken for uTP, which made every such tunnel BitTorrent.
- **protocols:** hysteria, hysteria2 and tuic drop a uTLS fingerprint with a warning instead of failing every connection.

## r17 — 2026-10-25

sing-box 1.13.21, 1.14.3 · podkop-exp 0.8.4

- **REALITY, uTLS:** the fingerprint fallback tries the configured fingerprint without X25519MLKEM768 first, then `firefox` with it, then the configured one as is, and remembers the one that got an answer per server in cache.db for a day. On a path that freezes bursts of `chrome` ClientHellos (REALITY, bursts of 20): 18–20 of 20 instead of 0. The `fingerprints` list of the section is no longer read.
- **DNS:** with `ipv4_only` and the new option `dns.ipv6_if_no_ipv4`, an AAAA query goes out for a name that has no IPv4 address, so a site with IPv6 only opens; names with IPv4 and FakeIP names still get no AAAA.

## r16 — 2026-10-24

sing-box 1.13.21, 1.14.3

- **Clash API:** a dashboard update (`external_ui`) is unpacked into a directory of its own and replaces the old files only when complete: no space, a broken or an empty archive leaves the dashboard that was served, not an empty one.
- **lists:** an answer 304 "not modified" writes only the time of the check to cache.db, not the whole list again: one update of two big lists wrote 64 MB, now 141 KB.
- **lists:** a rule-set closed by a reload in the same process (`SIGHUP`, podkop-exp) stops reading its list instead of finishing beside the new instance; five reloads during reading peaked at 78 MB instead of 119–121 MB.
- **DNS:** when sing-box does not bind its sockets to a device (podkop-exp), the DNS fallback takes the provider's servers of every uplink and asks each through its own uplink. mwan3 with a broken wired provider: 8 of 8 answers instead of 0.

## r15 — 2026-10-19

sing-box 1.13.21, 1.14.3

- **package:** 1.14 moves to sing-box 1.14.3, which closes the idle connections of outbounds and DNS servers nothing references, such as unselected urltest members.
- **lists:** JSON rule-sets of domains and lists of subnets are built in one pass into compact structures, with the same result. aarch64 emulator with 256 MB: a JSON of 100,000 domains loads in 2 s at a 24 MB peak (r14: out of memory at 135 MB).
- **lists:** the rule-set format `text`: domains and addresses as plain text, one a line, local or remote; a list without a single entry (a block page) is an error (1.14).
- **protocols:** the `http` outbound is in `podkop-engine` too: a local HTTP proxy in "Outbound Config" is no longer refused.
- **embedding:** remote rule-sets can be updated on request and the start can go without lists on request; the command line is an importable package (1.14).
- **fixes:** xhttp: a write after the server ended the upload is the normal end of the connection, not an ERROR line, and a stream-up session whose upload answer is cut fails with a reason; sniffed packets go back to the pool when rule matching fails; a hung DoH connection is reset by its timeout again after the clock was set back.

## r14 — 2026-10-10

sing-box 1.13.21, 1.14.2

- **protocols:** VLESS Encryption of Xray for the vless outbound (option `encryption`), with Vision over it on any transport; `decode-link` passes the `encryption` of a link instead of refusing it.
- **DNS:** a DoH query in flight when the server closes the HTTP/2 connection without a GOAWAY (Quad9 does) is asked again on a new connection instead of failing with `unexpected EOF`. Every message of the DNS fallback is a warning, so podkop's default log level shows them.
- **sniffing:** a datagram that parses as DNS but is no query (DTLS, an NTP request) goes on to the other packet sniffers, so rules `protocol: dtls` and `protocol: ntp` match.
- **fixes:** input validation from upstream libraries: crafted UDP packets from one's own server could crash the Shadowsocks 2022, TUIC, Hysteria2 and Hysteria clients; Vision splits large padded records as 1.14 does (1.13).
- **package:** on OpenWrt 25.12, where apk keeps a foreign `/etc/init.d/sing-box`, the package puts its own script in place and keeps the old one in `/etc/sing-box/`; with the foreign script sing-box ran without the DNS fallback, the download check and 65536 descriptors. The init script passes on only a safe `memory_limit` (`off`, MiB or GiB) and a `urltest_download_url` without spaces.

## r13 — 2026-10-09

sing-box 1.13.21, 1.14.2

- **tools:** `sing-box tools decode-link` reads the links of every protocol of the build (vless, trojan, ss, socks, hysteria2, tuic; in `podkop-engine-full` also vmess, http, hysteria, anytls, naive) and prints only an outbound this sing-box accepts; an option without a link parameter is set as `sb.<path>=value`.
- **REALITY, uTLS:** the fingerprint fallback: a ClientHello that gets no acknowledgment is tried again with the next uTLS fingerprint; off by default, `experimental.utls_fallback` in config.json turns it on. The TLS option `spoof` of 1.14 is in 1.13 too and works with REALITY on both lines.
- **package:** a liveness probe: the failsafe service asks sing-box for podkop's test name every 20 s and kills a process that runs but has not answered for 49–72 s, so that procd starts it again (switch `liveness`); why the failsafe stopped podkop is kept in `/etc/sing-box/failsafe.last`.
- **urltest:** test results survive the loss of the default route (`ifdown wan` for 30 s no longer switches the group); a list download through a urltest group survives a switch of the group.
- **lists:** a local rule-set is not read while podkop replaces it; a remote one is refused before it is read when it is larger than 50 MB or is not a rule-set.
- **memory:** a connection with the `chrome` fingerprint holds 2.9 KB less after the handshake, with the other browser fingerprints 0.4–1.0 KB less.
- **fixes:** no crash on a REALITY `short_id` longer than 16 hex digits or on a server name with an empty label under `tls.fragment`; `tls.fragment` without `record_fragment` fragments on 1.13 too; VMess `auto` stays `auto` under TLS (Xray servers refused `zero`); a warning for a VLESS `flow` over a transport it does not work over; a data race in the connection list of the Clash API; the first DNS query of a UDP session could go unanswered when `hijack-dns` had no `sniff` before it.

## r12 — 2026-10-07

sing-box 1.13.21, 1.14.2

- **transports:** xhttp survives a network reset: in r11 an xhttp outbound stopped working until a restart after a change of the default interface or "close all connections" in the dashboard.
- **DNS:** the DNS fallback counts a failure of a server once per event and only for names the provider resolved, so one broken name or one DoH reset no longer moves the whole network to the provider's DNS; a network reset clears its state.
- **FakeIP:** new names get addresses from memory while the cache file cannot be written (no space, a read-only partition).
- **REALITY, uTLS:** `android` and `360` with REALITY are a configuration error; `edge`, `ios` and `qq` get a warning at start, since Xray-core 26.9.8+ servers refuse them.
- **package:** the failsafe service works whatever the order of installation and after an upgrade from r1–r3, with a switch `failsafe`; procd counts crashes less than 10 minutes apart, not an hour.
- **fixes:** an HTTP/2 frame of an unknown type from a DoH server or a proxy no longer crashes the process (1.13, golang.org/x/net updated); `sing-box check` refuses a bad xhttp `uplink_http_method` and a `download` without `server_port`.

## r11 — 2026-10-06

sing-box 1.13.21, 1.14.2

- **transports:** the client of Xray's XHTTP transport for VLESS and Trojan: modes packet-up, stream-up, stream-one and auto, HTTP/1.1, HTTP/2 and HTTP/3, TLS and REALITY, a separate download server, XMUX; option names as in sing-box-extended.
- **tools:** `sing-box tools decode-link` turns a `vless://` or `trojan://` share link into an outbound, with the `extra` of xhttp.
- **package:** `sing-box version` ends with a `Features:` line, by which podkop decides which options to write and to show.

## r10 — 2026-10-04

sing-box 1.13.21, 1.14.2

- **urltest:** `fallbacks`: outbounds the group takes, the first live one in their order, only while none of its `outbounds` answers; it returns as soon as one does. `download_url` per group: its own URL for the download check, `""` turns the check off for the group.
- **sniffing:** a crafted QUIC packet from the LAN no longer crashes sing-box (an upstream fix); a panicking sniffer fails its connection, not the process; a UDP sniff reads at most 16 packets.
- **Clash API:** log lines for `/logs` are formatted only while someone reads them; a busy `external_controller` address no longer fails the start, the listen is retried; the delay test of a group with a nested urltest does not wait for its download checks (1.14).
- **lists:** an unreachable remote rule-set logs its error once and then every 10 minutes with a count, not every 30 s.
- **fixes:** from upstream's stable branch: WebSocket and HTTPUpgrade clients lost bytes that came with the 101 answer, a repeated UDP sniff returned packets twice, a urltest switch closed connections under the lock of the group.
- **package:** the init script raises the descriptor limit to 65536 (4096 ran out at about 2000 connections, then DNS failed), gives sing-box 15 s to stop instead of 5 and keeps color codes out of the system log.

## r9 — 2026-10-04

sing-box 1.13.21, 1.14.2

- **package:** two packages, one installed: `podkop-engine` with what podkop uses (1.14 on x86_64: 24.3 MB instead of 29.2) and `podkop-engine-full` with every other outbound and, on 17 architectures, NaiveProxy.
- **memory:** the Go memory limit follows the memory the system can still give, so under load the collector runs before the OOM killer; `memory_limit` in `/etc/config/sing-box` sets a fixed limit or turns it off.
- **memory:** an idle connection no longer holds a 32 KiB buffer (5–30 KiB a connection instead of 37–63), the uTLS state is released after the handshake, and Vision in direct mode copies through splice (fork of sing-vmess).
- **DNS:** a timeout of one slow DoH query no longer resets the connection with the queries already answered (stand: 800 of 800 over one connection); a failing DNS server is logged once, then as a summary every 10 s.
- **urltest:** a connection that gets no answer for longer than usual for its server starts an out-of-turn test, and QUIC timeouts count as failures: a silent server is left in about 17 s instead of 41 s to 3 minutes.

## r8 — 2026-10-03

sing-box 1.13.21, 1.14.2

- **urltest:** before switching to a member, sing-box downloads 64 KiB through it and skips a member whose download stalls: a server behind a DPI that freezes connections after about 16 KB passes the usual probe. Switches `urltest_download_check` (on) and `urltest_download_url` in `/etc/config/sing-box`.
- **urltest:** each member is tested every interval, not every other one, and a member is left when its connections fail, not at the next test.
- **package:** without the resolved service and DNS transport the binary is about 15 % smaller; a config with `resolved` is refused as an unknown type.
- **fixes:** bounds on the CRYPTO frames of a QUIC Initial and on a remote rule-set download that stalls; plain UDP DNS queries are sent again while no answer has come; a direct dial back to the inbound a connection came in on is refused (a DNS loop); a failed HTTP/2 or gRPC-lite dial reports its error; 1.13 bounds the TLS handshake of a dial, as 1.14 does.

## r7 — 2026-10-02

sing-box 1.13.21, 1.14.2

- **FakeIP:** the address table lives in memory and cache.db is a copy written in the background, so neither a DNS answer nor a new connection waits for the file. A burst of 100 new names: the last answer in 2–5 ms wherever cache.db is (r6: about 125 ms on emulated router flash).
- **FakeIP:** an address unused for 24 hours is freed and cache.db stops growing; a new name never takes the address of a name in use. The cache.db of r6 is taken over as is.
- **FakeIP:** a connection to a FakeIP address without a record goes by the name the client sends (TLS SNI, HTTP Host, QUIC) instead of failing with `missing fakeip record`.
- **DNS:** the output queue of a UDP inbound holds 1024 packets instead of 64: bursts of 100 queries lost 0.2 % of the answers, and clients waited seconds for them.
- **fixes:** "Flush FakeIP" in the dashboard works; the Clash API answered it with an error 500 (1.13).

## r6 — 2026-09-30

sing-box 1.13.21, 1.14.2

- **FakeIP:** after a crash, an OOM kill or SIGKILL, addresses no longer start again from the beginning of the range, where devices with a cached address reached another site; a new name no longer waits 10 ms for a database write. GL-MT6000, a burst of 100 new names: all answers in 50–90 ms instead of about 1 s.
- **REALITY, uTLS:** the `randomized` fingerprint is consistent: X25519MLKEM768 is offered in the groups and the key shares together, and ALPN is always sent. In about half of the starts it gave `CurvePreferences includes unsupported curve`, failed REALITY on Xray 26.9.8+ or broke gRPC.
- **DNS:** queries from dnsmasq no longer wait behind one slow exchange (up to 1.6 s in a test) (1.14).
- **package:** at every crash of sing-box the failsafe logs the router's memory: MemTotal and MemAvailable, what sing-box took when the OOM killer took it, /tmp, cache.db and the largest processes.

## r5 — 2026-09-29

sing-box 1.13.21, 1.14.2 (1.14.2 goes from r2 to r5)

- **DNS:** the DNS fallback takes the provider's servers from netifd (ubus) for the interfaces on sing-box's output device, not from `resolv.conf.auto`, where OpenWrt also lists VPN tunnels, the LAN and backup modems; it asks all of them at once first, then the fastest, and reads them again when the uplink changes.
- **DNS:** 1.14 gets what 1.13 got in r4: a socket per UDP query, the DNS fallback and the failsafe service; a TCP or TLS connection carries at most 16 queries at once, others go over new connections (Yandex reset the connection under load).
- **memory:** queries dnsmasq forwards to sing-box no longer hold goroutines of their own: at 200 queries a second, about 20 goroutines instead of 3000 (1.14).
- **package:** on an upgrade from r1–r3 the switch `dns_fallback` (on) is added to `/etc/config/sing-box`; a value already set stays.

## r4 — 2026-09-29

sing-box 1.13.21 only (1.14.2 had no r3 and r4 releases)

- **DNS:** each UDP query to a server reached without a proxy goes from a socket of its own, as dnsmasq does: Yandex DNS (about 20 queries a second per socket) no longer loses answers under load.
- **DNS:** DoT connections idle for more than 8 s are closed before the server closes them silently, so queries after a pause no longer fail with EOF.
- **DNS:** the DNS fallback: when a server reached directly through the WAN does not answer, fails or answers SERVFAIL, the provider's DNS answers. Resolvers of podkop's VPN sections, local and private resolvers are never replaced; switch `dns_fallback` in `/etc/config/sing-box`.
- **package:** the failsafe service: when sing-box keeps crashing and procd stops restarting it, podkop is stopped, so dnsmasq returns to the regular servers and the network keeps internet and DNS.

## r3 — 2026-09-28

sing-box 1.13.21 only

- **lists:** in r2 a remote rule-set that kept answering 404, 403 or 5xx left an open connection behind at every retry, every 30 s; a failed download now closes its connection. 1.14 was not affected.

## r2 — 2026-09-28

sing-box 1.13.21, 1.14.2

- **lists:** when a remote rule-set cannot be downloaded at start (WAN not up yet, a wrong clock, the first urltest member dead), sing-box starts with an empty list instead of exiting, retries (5, 10, 20 s, then every 30 s) and, once the list comes, runs `podkop list_update` once.
- **urltest:** members are tested again when the default interface changes, as on 1.14, not after 3 minutes (1.13).
- **package:** `sing-box version` shows the package revision (`1.14.2-pdk-r2`).

## r1 — 2026-09-26

sing-box 1.12.25, 1.13.21, 1.14.2 · first release

- **REALITY, uTLS:** REALITY keeps the X25519MLKEM768 key share and announces client version 26.3.27, so it works with Xray-core 26.7+ and 26.9+ servers as the Xray client 26.9.9 does; a server on Xray 24.x–25.4 works only when its decoy site does not choose X25519MLKEM768. The uTLS fingerprints `firefox` and `safari` are Firefox 148 and Safari 26.3, as in Xray.
- **package:** the package `podkop-engine` installs as `sing-box` (`PROVIDES: sing-box`): ipk for OpenWrt 24.10 and older, apk for 25.12 and snapshot, 31 architectures per format. 1.14 is built without snell, the API service and `sing-box api`. 1.12.25 has only the REALITY and uTLS changes and was released only in r1.
