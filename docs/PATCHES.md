# podkop-engine patches

podkop-engine is upstream sing-box at a release tag plus the patches in `patches/v<line>/`, and
nothing else. The 1.14 line is `v1.14.4` plus the 69 patches of `patches/v1.14`: the branch
`podkop-engine-1.14` of podkop-net/sing-box at `209086dbd08a50faf48f13c80febbb30f1caf942`
(`SB_1_14_FORK_COMMIT` in `versions.env`, release r28), the commit podkop-experimental pins in its
`go.mod`. `scripts/check-fork.sh [-C <sing-box clone>]` applies the patches to the tag in a
scratch index and compares the tree with that commit (CI runs it before every build). The 1.12
line is `v1.12.25` plus 2 patches, with no fork commit. By hand, in a clone of SagerNet/sing-box:
`git checkout -b pe-1.14 v1.14.4 && git am -3 <podkop-engine>/patches/v1.14/*.patch`; the OpenWrt
package applies the same files with quilt. Each entry below says what a patch changes; the patch
has the code, its header the reasons and the measurements. "since rN" is the podkop-engine release
in which the feature first shipped, on any line (r22 and r23 were never released; their changes
first shipped in r24).

## How the series is organized

Since r25 the 1.14 series is one patch per feature, cut by layer; the file number is
layer × 100 + place in the layer.

| Layer | Patches | What it holds |
|---|---|---|
| 00 | 0001–0002 | build: what a build registers (tags `podkop_slim`, `podkop_full`), forks of libraries in `go.mod` |
| 01 | 0101–0102 | upstream changes carried back to the tag (0102: sing-box 1.15's certificate pin, since r28) |
| 02 | 0201–0215 | hooks: the few lines of upstream files that a module of layer 03 needs, one patch per module |
| 03 | 0301–0317 | own modules: new files only |
| 04 | 0401–0423 | behaviour changes in upstream files, with new files beside them |
| 05 | 0501–0505 | added in r26: CPU and size (log lines, goroutine stacks, QUIC suites, CLI tools); upstream lines and new files in one patch |
| 06 | 0601–0603 | added in r27: the BitTorrent sniffers and the loss of members over QUIC; same form as 05 |
| 07 | 0701–0702 | added in r28: Xray's finalmask fragment and Xray's verification of the certificate; same form as 05 |

Every patch ends with three trailers: `Pdk-Feature:` (the feature; a module of layer 03 and its
hooks in layer 02 share it), `Pdk-Zone:` (`core`, `protocols`, `groups`, `tools`, `build`,
`other`) and `Pdk-Layer:`. The patches cut in r25 also list the commits of the earlier series they
were made of (branch `archive/r25-1.14-commits` of podkop-net/sing-box).

Rules (`docs/RELEASE.md`): a fix of a feature goes into its patch (`git commit --fixup`,
`git rebase --autosquash`); a new feature is a new patch in its layer; files come from
`git format-patch --no-renames` (quilt reads no git renames). A move to a new tag is
`git rebase --onto <tag> v1.14.4`, checked with `git range-diff`; layer 03 adds only new files, so
conflicts come from the patches that edit upstream files. Only the whole series is checked: a few
lines of one feature sit in the patch of another (noted below), so not every intermediate tree
builds. Since r28, 0701 and 0702 also hold the lines of the link decoder (0307) and of the
Features line (0308) for what they add.

## 1.14.4 — 69 patches

### Layer 00: build

#### 0001 include: the podkop_slim and podkop_full sets of protocols and services
`build-slim` · since r1 (`podkop_full` since r9) · [patch](../patches/v1.14/0001-include-the-podkop_slim-and-podkop_full-sets-of-prot.patch)
- `podkop_slim` (package `podkop-engine`) registers what podkop uses: inbounds `tproxy`, `direct`,
  `mixed`; outbounds `direct`, `block` (since r19), `selector`, `urltest`, `socks`, `shadowsocks`,
  `trojan`, `vless`, `http` (since r15), `hysteria2`, `tuic`; no QUIC DNS servers, no services
  `api`, `ssm-api`, Hysteria2 realm, OOM killer, no Cloudflare Origin CA provider.
- A type left out is a stub: a configuration that names it fails with "… is not included in this
  build (podkop_slim)", for an outbound of the full set naming `podkop-engine-full`.
- `podkop_full` (package `podkop-engine-full`) adds back `vmess`, `snell`, `naive` (with
  `with_naive_outbound`), `tor`, `ssh`, `shadowtls`, `anytls`, `hysteria`.
- Every build loses the `resolved` service (here) and DNS server (in 0214). The call of
  `urltestgroup.RegisterURLTest` is here, its import in 0410.

#### 0002 go.mod: sing-vmess of the podkop-engine fork
`gomod-vmess` · since r9 · [patch](../patches/v1.14/0002-go.mod-sing-vmess-of-the-podkop-engine-fork.patch)
- `replace github.com/sagernet/sing-vmess => github.com/FiyeroT/sing-vmess v0.2.9-pdk.2`: under
  Vision in direct mode the copy loop reads the connection itself (splice, no buffer while idle;
  since r9), plus upstream's a0c5854, the close after a direct write.

### Layer 01: upstream fixes

#### 0101 ja3: test a list that runs past its extension
`backport-ja3` · since r10 · [patch](../patches/v1.14/0101-ja3-test-a-list-that-runs-past-its-extension.patch)
- The test of upstream 07512b109 for `common/ja3`. The fix was a backport from r10; sing-box 1.14.3
  (r15) has it, and only the test is left.

#### 0102 tls: certificate_sha256, a pin of the whole server certificate
`backport-certificate-sha256` · since r28 · [patch](../patches/v1.14/0102-tls-certificate_sha256-a-pin-of-the-whole-server-cer.patch)
- Upstream e7ad8a875 of sing-box 1.15.0-alpha.13, carried back as it is: the outbound TLS option
  `certificate_sha256`, the SHA-256 of the server's whole certificate (base64, a list), and the
  inbound `client_certificate_sha256`. A pinned server is taken without the roots, a self-signed
  one too; with `certificate` or `certificate_path` it is refused.
- Upstream pins the leaf; 0702 takes a pinned CA of the chain as well, as Xray does.

### Layer 02: hooks in upstream files

Each patch holds the call sites of one layer-03 module; the module's entry says what it does.

- **0201** `dns-udp` → 0301: `dns/transport/udp.go`. [patch](../patches/v1.14/0201-dns-udp-hooks-in-upstream-files-a-socket-per-query-a.patch)
- **0202** `dns-nat` → 0302: `route/dns.go`; also the `dns.IsLoggedFailure` checks of 0304. [patch](../patches/v1.14/0202-route-hooks-in-upstream-files-the-DNS-of-a-NAT-sessi.patch)
- **0203** `listener-udp` → 0303: `common/listener/listener.go`, `listener_udp.go`; the queue of 64
  becomes `udpOutputQueueSize` = 1024 here, the whole change. [patch](../patches/v1.14/0203-listener-hooks-in-upstream-files-an-output-queue-of-.patch)
- **0204** `dns-log` → 0304: `dns/client.go`, `dns/router.go`; also the `ipv6IfNoIPv4` field of
  0310. [patch](../patches/v1.14/0204-dns-hooks-in-upstream-files-a-failed-exchange-logged.patch)
- **0205** `box-memory` → 0305: `box.go`; also drops the `Close` from the error path of `Start`,
  which 0420 puts back. [patch](../patches/v1.14/0205-box-hooks-in-upstream-files-the-Go-memory-limit-foll.patch)
- **0206** `xhttp` → 0306: `constant/v2ray.go`, `go.mod`, `option/v2ray_transport.go`,
  `transport/v2ray/transport.go` (type `xhttp`, client only). [patch](../patches/v1.14/0206-xhttp-hooks-in-upstream-files-the-client-of-Xray-s-X.patch)
- **0207** `version` → 0308: `cmd/sing-box/cmd_version.go`. [patch](../patches/v1.14/0207-version-hooks-in-upstream-files-list-the-features-of.patch)
- **0208** `ruletext` → 0309: `constant/rule.go`, `route/rule/rule_set_local.go`,
  `rule_set_remote.go`; also the switch of local binary sets to `srs.ReadSets` of 0419. [patch](../patches/v1.14/0208-rule-set-hooks-in-upstream-files-the-format-text.patch)
- **0209** `dns-ipv6` → 0310: `dns/client.go`, `dns/router.go`, `option/dns.go`. [patch](../patches/v1.14/0209-dns-hooks-in-upstream-files-ipv6_if_no_ipv4.patch)
- **0210** `hysteria-utls` → 0311: `protocol/hysteria/outbound.go`; hysteria2 and tuic get the line
  in 0409. [patch](../patches/v1.14/0210-hysteria-hysteria2-tuic-hooks-in-upstream-files-a-uT.patch)
- **0211** `cachefile-files` → 0312: `experimental/cachefile/cache.go`. [patch](../patches/v1.14/0211-cachefile-hooks-in-upstream-files-the-content-of-a-r.patch)
- **0212** `route-chain` → 0313: `route/conn.go`, `route/route.go`; also the call of 0315. [patch](../patches/v1.14/0212-route-hooks-in-upstream-files-a-chain-with-a-URL-tes.patch)
- **0213** `hot-swap` → 0314: `box.go`, `common/dialer/detour.go`. [patch](../patches/v1.14/0213-box-hooks-in-upstream-files-outbounds-replaced-while.patch)
- **0214** `dns-group` → 0316: `constant/dns.go`, `dns/router.go`, `include/registry.go` (types
  `group`, `provider`; the `resolved` DNS server leaves the registry). [patch](../patches/v1.14/0214-dns-hooks-in-upstream-files-the-transports-group-and.patch)
- **0215** `probesock` → 0317: `common/dialer/default.go`, `common/dialer/resolve.go`. [patch](../patches/v1.14/0215-probesock-hooks-in-upstream-files-the-TCP-of-a-probe.patch)

### Layer 03: own modules

#### 0301 dns/udp: a socket per query, a query sent again while no answer came
`dns-udp` · since r4 · hooks: 0201 · [patch](../patches/v1.14/0301-dns-udp-a-socket-per-query-a-query-sent-again-while-.patch)
- A plain UDP DNS server reached without a proxy (no `detour`, or a detour to `direct`) gets a
  socket of its own for each query, random port and ID, at most 256 at once; through a proxy the
  shared session stays.
- While no answer has come, the same datagram is sent again 1 s and 3 s after the first; the
  caller's deadline cuts the schedule short.

#### 0302 route: the DNS of a NAT session answered off the reading loop
`dns-nat` · since r5 · hooks: 0202 · [patch](../patches/v1.14/0302-route-the-DNS-of-a-NAT-session-answered-off-the-read.patch)
- DNS hijacked from a UDP session of an inbound's NAT table (`direct`, `mixed`, `socks`) is
  answered by a packet handler of the session, as in sing-box 1.13, not by a loop per session that
  kept three goroutines, a timer and buffers for 10 s after each answer; the exchange runs off the
  loop that reads the inbound.
- Without a `sniff` action before `hijack-dns`, the opening packet is read before the handler is
  set and the queue 20 ms more, so that no query is left without an answer.

#### 0303 listener: an output queue of 1024 UDP packets
`listener-udp` · since r7 · hooks: 0203 · [patch](../patches/v1.14/0303-listener-an-output-queue-of-1024-UDP-packets.patch)
- The output queue of a UDP listener holds 1024 packets instead of 64 (a burst of 70 DNS answers
  lost some). This patch is the test; the change is in 0203.

#### 0304 dns: a failed exchange logged once per server, with a count
`dns-log` · since r9 · hooks: 0204 · [patch](../patches/v1.14/0304-dns-a-failed-exchange-logged-once-per-server-with-a-.patch)
- The first failure of a server is logged at once with its query; while it goes on failing, one
  line every 10 s counts the failures and shows the last one. A query its caller gave up is no
  failure; callers do not log a failure again.

#### 0305 box: the Go memory limit follows the memory the system can still give
`box-memory` · since r9 · hooks: 0205 · [patch](../patches/v1.14/0305-box-the-Go-memory-limit-follows-the-memory-the-syste.patch)
- The soft memory limit of Go is set to the memory of Go now plus what the system can still give
  (`MemAvailable` or the room under the cgroup limit, the smaller) minus the most pages of the
  binary ever resident; computed again after every garbage collection, never below what cannot be
  freed plus the smallest heap goal (4 MiB at GOGC=100).
- `GOMEMLIMIT` or `experimental.debug.memory_limit` switch it off. Linux only, not Android.

#### 0306 xhttp: the client of Xray's XHTTP transport
`xhttp` · since r11 · hooks: 0206 · [patch](../patches/v1.14/0306-xhttp-the-client-of-Xray-s-XHTTP-transport.patch)
- V2Ray transport `xhttp`, client side, as Xray-core v26.9.9 puts it on the wire: `mode` `auto`
  (default), `packet-up`, `stream-up`, `stream-one`; HTTP/1.1, HTTP/2, HTTP/3 (BBR, Chrome QUIC
  profile); TLS and REALITY. Option names as in sing-box-extended.
- Options: `host`, `path`, `headers`, the `x_padding_*`, `session_*`, `seq_*`, `uplink_*` fields,
  `sc_*` limits, `download` (the download leg via another server), `xmux` (`max_concurrency`,
  `max_connections`, `c_max_reuse_times`, `h_max_request_times`, `h_max_reusable_secs`,
  `h_keep_alive_period`); server fields are read and ignored; what Xray refuses fails `sing-box check`.
- Browser-like request headers: Chrome's, unless `User-Agent` names `firefox`, `safari`, `edge`,
  `curl` or `golang`.
- `Close` is a reset; idle pooled connections close with those of an unreferenced outbound (since
  r18). Also defines `tls.QUICClientOptions` of 0311.

#### 0307 tools decode-link: share links to outbounds
`decode-link` · since r11 · [patch](../patches/v1.14/0307-tools-decode-link-share-links-to-outbounds.patch)
- `sing-box tools decode-link [link]` (or stdin) prints the outbound of a share link as JSON
  (`--compact`): `vless`, `trojan`, `ss`, `socks`, `hysteria2`/`hy2`, `tuic`, `http`/`https`; with
  every outbound built in also `vmess`, `hysteria`, `anytls`, `naive+https`/`naive+quic`.
- The outbound is built as `sing-box check` builds it, so this binary accepts what is printed.
  Exit 0 printed (warnings on stderr), 2 the link cannot be used, 1 anything else; messages never
  repeat the link.
- `sb.<option path>` sets an option a link has no parameter for (`sb.tls.fragment=1`); the `extra`
  of XHTTP links and the `encryption` of VLESS links are read. Link keys: `docs/LINKS.md`.
- Since r28 links also give `finalmask` (`fm`), `certificate_sha256` (`pcs`, `pinSHA256`) and
  `certificate_server_name` (`vcn`); those lines are in 0701 and 0702.

#### 0308 version: list the features of this build
`version` · since r11 · hooks: 0207 · [patch](../patches/v1.14/0308-version-list-the-features-of-this-build.patch)
- `sing-box version` ends with
  `Features: urltest.fallbacks,urltest.download_url,transport.xhttp,tools.decode-link,tls.utls-fallback`;
  a name is never removed or given another meaning.

#### 0309 rule-set: the format text
`ruletext` · since r15 · hooks: 0208 · [patch](../patches/v1.14/0309-rule-set-the-format-text.patch)
- `"format": "text"`, remote or local: a domain or IP/CIDR a line, `#` and `//` comments. A domain
  (also `.x` or `+.x`) matches itself and its subdomains, an address by destination.
- Other lines are left out with one warning; a list without a single item (a block page) is an
  error. Names go into the trie of 0418, addresses into a `cidrset` (0419).

#### 0310 dns: ipv6_if_no_ipv4
`dns-ipv6` · since r17 · hooks: 0209 · [patch](../patches/v1.14/0310-dns-ipv6_if_no_ipv4.patch)
- `dns.ipv6_if_no_ipv4` (default off): under `ipv4_only` an AAAA question goes out when the A
  question of the name, through the same server, got no A record; a lookup of such a name takes
  its IPv6 addresses. FakeIP servers are left out; A and AAAA share one exchange through the cache.

#### 0311 hysteria, hysteria2, tuic: a uTLS fingerprint is dropped with a warning
`hysteria-utls` · since r18 · hooks: 0210 · [patch](../patches/v1.14/0311-hysteria-hysteria2-tuic-a-uTLS-fingerprint-is-droppe.patch)
- On `hysteria`, `hysteria2` and `tuic` a uTLS fingerprint is dropped with a warning: quic-go
  builds the ClientHello, and every connection failed (`unsupported usage for uTLS`).
- This patch is the test; the code is in 0306 (`tls.QUICClientOptions`), 0210 and 0409.

#### 0312 cachefile: the content of a remote rule-set in a file of its own
`cachefile-files` · since r18 · hooks: 0211 · [patch](../patches/v1.14/0312-cachefile-the-content-of-a-remote-rule-set-in-a-file.patch)
- The content of a remote rule-set lives in `<cache file>.rule-sets/<tag>-<hash>`, the bucket
  `rule_set_file` keeps the rest (in bbolt a list took three times its size). Written as `.new`,
  synced, renamed, then recorded: a file whose size differs from its record is downloaded again.
- Lists of an earlier version are moved into files at start and the database compacted; an
  earlier version finds no record and downloads the list.

#### 0313 route: a chain with a URL test is dialed through the URL test
`route-chain` · since r18 · hooks: 0212 · [patch](../patches/v1.14/0313-route-a-chain-with-a-URL-test-is-dialed-through-the-.patch)
- sing-box 1.14.4 dials the member a group selected, past the group; here a chain is dialed
  through its first URL test group, which judges the dials of its members itself.
  This patch is the test; the change is in 0212.

#### 0314 box: outbounds replaced while the box runs
`hot-swap` · since r19 · hooks: 0213 · [patch](../patches/v1.14/0314-box-outbounds-replaced-while-the-box-runs.patch)
- Go API `Box.UpdateOutbounds`: builds and starts outbounds and puts them in place of those of
  their tags, adds and removes tags. Connections routed later use the new objects, earlier ones
  keep their chain.
- A replaced outbound closes when no listed connection uses it, after 2 minutes at least and
  24 hours at most; a replaced urltest group hands its choice to its successor.
- A `detour` finds the outbound of its tag at every dial. An update that leaves an outbound
  depending on one replaced or removed, or over the limit of kept outbounds (`ErrTooManyKept`), is
  refused; a refused or failed update changes nothing.
- Since r28 a `balance` group gets its balancer back when the update that replaced it is undone
  (a later start stage failed); before, it balanced no more.

#### 0315 route: a connection a block outbound refused is logged at debug
`route-block-log` · since r19 · [patch](../patches/v1.14/0315-route-a-connection-a-block-outbound-refused-is-logge.patch)
- A dial error of a `block` outbound is logged at debug, as the `reject` action is. The call is in
  0212.

#### 0316 dns: the transports group and provider
`dns-group` · since r21 · hooks: 0214 · [patch](../patches/v1.14/0316-dns-the-transports-group-and-provider.patch)
- DNS server `group`: `servers` (tags), `strategy` `order` (default) or `fastest` (smoothed answer
  time). NOERROR and NXDOMAIN are answers, another rcode moves on, an error or timeout is a
  failure; an attempt waits 4 × the smoothed time, 1.5–3 s.
- After a timeout with more than one candidate left, the rest are asked together (since r25). A
  member that fails twice is set aside and probed after 30 s, up to every 5 minutes.
- With `SING_BOX_DNS_FALLBACK`, a query every member failed goes to the provider's servers.
- DNS server `provider` (no options): the provider's servers netifd knows, as 0404 reads them. Both
  types expose their state to an embedding program (`adapter.DNSGroupTransport`,
  `adapter.DNSProviderTransport`).

#### 0317 probesock: the TCP of a probe connection, for the loss of a member
`probesock` · since r24 · hooks: 0215 · [patch](../patches/v1.14/0317-probesock-the-TCP-of-a-probe-connection-for-the-loss.patch)
- A loss probe (urltest `loss`, `balance`) dials its TCP connection with a capture: a packet socket
  with a BPF filter for that connection (headers only; needs CAP_NET_RAW), counting
  retransmissions and reordering (told by the least RTT). Linux only.
- Its receive window is held small during the probe, then let grow to the system maximum; DNS
  lookups of a probe dial do not inherit the probe.
- Since r28 the far end cannot hold the probe or grow its memory: the counter keeps a bounded
  number of holes and fills (past either the probe is not counted), and the drain after the stop
  ends at the first packet stamped after it, at a limit at the latest.

### Layer 04: behaviour changes in upstream files

#### 0401 tls: uTLS and REALITY clients as Xray and the browsers do
`utls-reality` · since r1 · [patch](../patches/v1.14/0401-tls-uTLS-and-REALITY-clients-as-Xray-and-the-browser.patch)
- REALITY keeps the X25519MLKEM768 key share (Xray-core v26.9.8+ servers reject a ClientHello
  without it) and announces client version 26.3.27.
- `firefox` = Firefox 148, `safari` = Safari 26.3 (Xray-core's specs from
  refraction-networking/utls@aa6edf4); `random` picks chrome, firefox or safari; `randomized`
  offers X25519MLKEM768 with its key share and always sends ALPN; chrome, edge, ios, qq, 360 and
  android are built from their specification.
- After the handshake the ClientHello, the key-share private keys and the extensions are released;
  TLS dialer connections get the badtls read waiter (no buffer while idle), which reads a pending
  alert after data as crypto/tls does.
- With REALITY, `android` and `360` are an error (TLS 1.2 hellos), `edge`, `ios`, `qq` a warning;
  a `short_id` over 16 hex digits is an error; `alpn` applies only to `randomized`.
- Already creates the outcome writer of 0421.

#### 0402 rule-set: the download, the start and the update of remote rule-sets
`rule-set` · since r2 · [patch](../patches/v1.14/0402-rule-set-the-download-the-start-and-the-update-of-re.patch)
- A remote rule-set whose first download fails starts empty, retried after 5, 10, 20 s, then every
  30 s; then `SING_BOX_RULESET_RECOVERED_HOOK` runs once (tags in `SING_BOX_RULESET_TAGS`). With
  `SING_BOX_RULE_SET_START_EMPTY`, a set with nothing cached starts empty at once.
- A fetch is cut after 30 s without data; the start waits 30 s at most. A declared length over
  50 MiB or a binary set without the `.srs` magic is refused before it is read, naming size,
  `Content-Type` and first bytes.
- An answer 304 writes only the time (bucket `rule_set_checked`); the download is an external
  connection, which a URL test switching members does not cut.
- Updates run 5 at a time, lists of 1 MiB and more one at a time; a failing set logs once, then a
  count every 10 minutes. `Router.UpdateRuleSets` (Go API) updates every remote set now; a set
  closed while it reads stops.

#### 0403 dns: the TCP, TLS and HTTPS transports under loss
`dns-transport` · since r5 · [patch](../patches/v1.14/0403-dns-the-TCP-TLS-and-HTTPS-transports-under-loss.patch)
- A pipelined TCP or TLS connection carries at most 16 queries in flight, more get a connection of
  their own (Yandex DNS over TLS resets one with about 20).
- DoH resets its transport on a timeout only when no later query was answered (by the monotonic
  clock), and asks a query again once when the server closed HTTP/2 without a GOAWAY.

#### 0404 dns: the provider's DNS as the fallback of a server reached through the WAN
`dns-provider` · since r4 · [patch](../patches/v1.14/0404-dns-the-provider-s-DNS-as-the-fallback-of-a-server-r.patch)
- With `SING_BOX_DNS_FALLBACK` (the init script sets it when podkop is installed), a query a
  directly reached server fails (timeout, refused or reset, TLS or HTTP error; SERVFAIL retried
  but not counted) goes to the provider's DNS servers.
- Only a plain socket to a public address or name qualifies: no detour other than `direct`, no
  `bind_interface`, `routing_mark`, bind address or netns. Proxied, VPN and private resolvers
  behave as without the patch; members of a `group` (0316) have no fallback of their own.
- Provider servers come from netifd over ubus: of the device sing-box binds to, or of every
  uplink, each asked through its uplink, the fastest first; read again at most once in 30 s.
- The server gets 3.5 s, the provider 3 s, provider answers live 60 s at most. Two failures in a
  row (only for names the provider resolved) set the server aside, probed after 30 s up to every
  5 minutes. Every message is a warning.

#### 0405 fakeip: a store that answers from memory and saves in the background
`fakeip` · since r6 (the store in memory since r7) · [patch](../patches/v1.14/0405-fakeip-a-store-that-answers-from-memory-and-saves-in.patch)
- `TableStore` takes the place of upstream's store in the FakeIP transport (upstream's files stay
  as they are): the whole table in memory, saved to the cache file in the background.
- New names are answered while the file cannot be written; after a crash or kill, addresses that
  may have been given out are held back (the saved position runs 1024 ahead).
- A record unused for 24 h is removed; at most 65536 records a range. `Peek` tells an address
  without giving one; the Clash API FakeIP flush resets the store in memory too.

#### 0406 route: a FakeIP address without a record goes by the sniffed domain
`fakeip-route` · since r7 · [patch](../patches/v1.14/0406-route-a-FakeIP-address-without-a-record-goes-by-the-.patch)
- A connection to a FakeIP address whose record is gone goes by the domain a `sniff` rule finds
  (TLS, HTTP, QUIC); without one it is refused after the rules, with a warning that says why.

#### 0407 sniff: bounded, panic-safe, buffers given back
`sniff` · since r8 · [patch](../patches/v1.14/0407-sniff-bounded-panic-safe-buffers-given-back.patch)
- The CRYPTO frames of a QUIC Initial are bounded (65535 bytes); a UDP sniff reads 16 packets at
  most; the TLS sniffer stops the server handshake once the ClientHello is parsed.
- A panicking sniffer fails its connection, not the process; its stack is logged once a minute.
- A datagram that is no DNS query goes on to the other sniffers (DTLS, NTP); a WireGuard handshake
  initiation is not uTP; sniffed buffers go back when matching the rules fails.

#### 0408 route: no direct dial back to the inbound a connection came in on
`route-loop` · since r8 · [patch](../patches/v1.14/0408-route-no-direct-dial-back-to-the-inbound-a-connectio.patch)
- A `direct` inbound without an override hands out its own listen address; when no rule hijacks
  the connection, a `direct` dial back to that same inbound is refused instead of looping.
- Refusals are counted per inbound: the first logged, then one line every 10 s.

#### 0409 transports: the dial and the close of v2ray transports
`transport` · since r8 · [patch](../patches/v1.14/0409-transports-the-dial-and-the-close-of-v2ray-transport.patch)
- A failed HTTP/2 dial (`http`, gRPC lite) frees the write waiting for the handshake, with its
  error; QUIC streams and gRPC lite wait for data without a buffer (`common/readwait`).
- The end of the dial context ends the upgrade of `ws` and `httpupgrade` (since r21).
- `Close` of a client transport is a reset (stated and tested). Also has the hysteria2 and tuic
  lines of 0311.

#### 0410 urltest: the group of this fork, in a package of its own
`urltest` · since r8 · [patch](../patches/v1.14/0410-urltest-the-group-of-this-fork-in-a-package-of-its-o.patch)
- `protocol/group/urltestgroup` serves the type `urltest` in place of upstream's group (whose file
  stays as it is), for the Clash API and the daemon too.
- Members are tested every interval; one tester for all groups, at most 4 URL tests at once.
  `urls` (since r24): one URL a round in turn, the delay a median of the last rounds.
- A member is left when its connections fail or get no answer (tested out of turn); failures of
  the router's own network do not count against members.
- A download of 64 KiB through a member before a switch (since r8; the option `download_url`
  since r10); absent =
  `SING_BOX_URLTEST_DOWNLOAD_URL`, `""` = off. `fallbacks` (since r10): used in order while none
  of `outbounds` passes; fallbacks only and `block` as one since r20.
- `mode` (since r24): `fastest` (default); `loss`, delays weighed by the loss of probes through
  `loss_url` every `loss_interval` (30m; 256 KiB, 1 MiB before a switch); `balance`, connections
  spread by source over at most `balance_size` (3, max 16) best members under `loss_threshold`
  (1 %); a device may move after `balance_idle` (5m) without connections.
- Since r28: a balance holds 4096 devices at most (past that the idle ones go, and a new device
  goes by the member its address falls on); a test, a download check or a loss probe reads 64 KB
  of response headers at most (net/http: 10 MB); the prober drops the times of first servers
  that have passed, so replaced outbounds are not kept.

#### 0411 log: entries for the Clash API formatted only while read; a platform writer's level
`log` · since r10 · [patch](../patches/v1.14/0411-log-entries-for-the-Clash-API-formatted-only-while-r.patch)
- With the Clash API on, entries are formatted for `/logs` only while someone reads them (it cost
  each log call some ten times the call). A platform log writer may name its level and ask for no
  colours.

#### 0412 clashapi, trafficcontrol: a failed listen, a failed UI, records of connections
`clashapi` · since r10 · [patch](../patches/v1.14/0412-clashapi-trafficcontrol-a-failed-listen-a-failed-UI-.patch)
- A failed listen of `external_controller` does not fail the start; it is retried after 5 s,
  doubling up to a minute.
- `external_ui` is unpacked into `.external-ui-update` and replaces the served files only when
  complete; a failed unpack leaves the old UI.
- The close time goes into the kept copy, not the record `/connections` reads (a data race); a
  tracker drops the sniffer state and DNS answers. Also has lines of 0421 in `tracker.go`.

#### 0413 tlsspoof: the forged ClientHello the way the connection goes, REALITY takes it
`tlsspoof` · since r13 · [patch](../patches/v1.14/0413-tlsspoof-the-forged-ClientHello-the-way-the-connecti.patch)
- The forged ClientHello of `tls.spoof` goes out on a raw socket with the mark, device, source
  address and TTL of the connection, so it follows `routing_mark`, `bind_interface`,
  `auto_detect_interface`.
- A connection that has carried data (a tunnel) or is no TCP connection of its own
  (`tcp_fast_open`, a multiplexed transport) gets an error that says so.
- REALITY takes `spoof` and `spoof_method`; it authenticates by the real hello.

#### 0414 tls: the fingerprint fallback
`tls-fp-fallback` · since r13 · [patch](../patches/v1.14/0414-tls-the-fingerprint-fallback.patch)
- Off by default; on with `experimental.utls_fallback.enabled` or, without that section, any value
  of `SING_BOX_UTLS_FALLBACK`. `fingerprints` is read and ignored (since r17).
- A uTLS client tries its fingerprint without the X25519MLKEM768 key share, then `firefox`, then the
  fingerprint as it is (order since r17), and keeps the first the server takes and the path passes.
- An unacknowledged ClientHello (Linux: the socket is watched) gives the connection up; a REALITY
  server answering as to a stranger moves on at once; 4 handshakes a dial at most.
- The choice is kept per local address and in the cache file for 24 h; one dial probes, the others
  wait 5 s at most; when the cause is not the hello, it rests 30 s, doubling to 10 minutes.

#### 0415 vless: VLESS Encryption of Xray for the outbound; a flow where it cannot work
`vless` · since r13 (encryption since r14) · [patch](../patches/v1.14/0415-vless-VLESS-Encryption-of-Xray-for-the-outbound-a-fl.patch)
- `encryption` of the `vless` outbound: Xray's VLESS Encryption, client side, written as Xray does
  (`mlkem768x25519plus.<mode>.<1rtt|0rtt>[.<padding>].<key>`; empty or `none`: plain VLESS); code
  derived from Xray-core v26.9.30 (MPL-2.0). Vision works over it with any transport.
- Without it, `flow` over `ws`, `grpc`, `http`, `quic` or `httpupgrade` is a warning, over `xhttp`
  an error.

#### 0416 vmess: the security auto is not zero under TLS
`vmess` · since r13 · [patch](../patches/v1.14/0416-vmess-the-security-auto-is-not-zero-under-TLS.patch)
- `security: "auto"` stays AES-128-GCM or ChaCha20-Poly1305 under TLS; upstream sent `zero`, which
  Xray-core refuses. Only in `podkop-engine-full`.

#### 0417 tlsfragment: fragment and record_fragment, also on the ClientHello of REALITY
`record-fragment` · since r13 (REALITY since r24) · [patch](../patches/v1.14/0417-tlsfragment-fragment-and-record_fragment-also-on-the.patch)
- `fragment` and `record_fragment` act on the REALITY ClientHello too (upstream ignored them there).
- The wait for a fragment's acknowledgment ends when the connection closes; a server name with an
  empty label (`.example.org`) is cut where the label stands.

#### 0418 domainset: the names of rule-sets in a compact trie
`domainset` · since r15 · [patch](../patches/v1.14/0418-domainset-the-names-of-rule-sets-in-a-compact-trie.patch)
- `domain` and `domain_suffix` of rule-sets go into a compact trie (`common/domainset`) with the
  answers of sing's matcher and a fraction of its memory, also on 32-bit.
- The source format is read in one pass, names not copied; the build stops when the set closes.
  Compiling `.srs` writes what `domain.NewMatcher(...).Write` writes.

#### 0419 cidrset: the CIDR lists of rule-sets as ranges
`cidrset` · since r15 · [patch](../patches/v1.14/0419-cidrset-the-CIDR-lists-of-rule-sets-as-ranges.patch)
- `ip_cidr` and `source_ip_cidr` of rule-sets are sorted, merged ranges (`common/cidrset`): 8 bytes
  an IPv4 range, 32 an IPv6 one (netipx: 48). `srs.ReadSets` reads `.srs` lists into them.

#### 0420 box: StartWithoutClose leaves a box whose start failed to its caller
`box-start` · since r16 · [patch](../patches/v1.14/0420-box-StartWithoutClose-leaves-a-box-whose-start-faile.patch)
- Go API `Box.StartWithoutClose`: a box whose start failed is left to the caller to close (and to
  bound how long that takes); `Start` closes as before. The removal from `Start` is in 0205.

#### 0421 detector: what a block detector reads of each server
`detector` · since r21 · [patch](../patches/v1.14/0421-detector-what-a-block-detector-reads-of-each-server.patch)
- The cache file keeps for each REALITY server flags of what its handshakes met (`DetectNoAnswer`,
  `DetectRefused`: a server since Xray-core v26.9.8, `DetectFailed`), with fingerprint and time,
  written only on a change.
- Routed connections count bytes both ways and learn whether the remote side ended the stream
  (`adapter.RemoteEOFMarker`). The download results come from the URL test history of 0410.
- `adapter/experimental.go` here also declares cache methods of 0402 and 0414.
- Since r28 the outcome of one server is written four times at once, then once in ten seconds
  (the latest state): a path that let some handshakes through and not others wrote the cache
  file, on flash, for every connection.

#### 0422 http client: fallback clients, through which a remote rule-set repeats a failed download
`http-client-fallback` · since r25 · [patch](../patches/v1.14/0422-http-client-fallback-clients-through-which-a-remote-.patch)
- `fallback` of a client in `http_clients`: other shared clients. A remote rule-set whose download
  fails (error, status, stall, not a rule-set) repeats it through each in turn; fallbacks of a
  fallback are not followed, other users of the client do not fall back.

#### 0423 http client: outbounds, the ways a downloader takes in the order of what it knows of them
`http-client-downloader` · since r26 · [patch](../patches/v1.14/0423-http-client-outbounds-the-ways-a-downloader-takes-in.patch)
- `outbounds` of a client in `http_clients` (not with `detour` or `fallback`): the ways its
  downloads may take; users that do not know the downloader take the first.
- For a host: the way that brought its last file, the first of the list, ways that brought other
  hosts' files (fastest first), ways the URL tests passed (lowest delay first), unknown ways, ways
  that failed for the host.
- The next way starts beside the others after 4 s without progress or a body paused 1 s (3 s after
  1 MiB), three at once at most; the first list that parses wins.
- What was learned (`DownloadMemory`) lives with the box, or longer when the embedding program
  keeps it.

### Layer 05: CPU and size (r26)

#### 0501 route, dns: the debug line of a matched rule built only when it is logged
`rule-match-log` · since r26 · [patch](../patches/v1.14/0501-route-dns-the-debug-line-of-a-matched-rule-built-onl.patch)
- `Rule.String` of a matched rule was built on every connection and DNS query at any log level;
  now a `MatchLine` is formatted only when the entry is kept. The text is unchanged.

#### 0502 dns: the question of the exchange debug line formatted only when it is logged
`dns-question-line` · since r26 · [patch](../patches/v1.14/0502-dns-the-question-of-the-exchange-debug-line-formatte.patch)
- `exchange <question>` is formatted only when logged (`dns.QuestionLine`): it took 3.3 % of the
  CPU at DNS saturation on a Cortex-A53; a dropped line allocates 2 times instead of 7.

#### 0503 cmd: the network quality, STUN and schema tools left out of the slim engine
`slim-tools` · since r26 · [patch](../patches/v1.14/0503-cmd-the-network-quality-STUN-and-schema-tools-left-o.patch)
- `schema`, `tools networkquality` and `tools stun` build only with `!podkop_slim || podkop_full`;
  podkop runs none. 328 KB less of the arm64 binary, 459 KB of the mipsle one.

#### 0504 warm: the deep paths of a new UDP session and of its DNS exchange on goroutines kept warm
`warm-goroutines` · since r26 · [patch](../patches/v1.14/0504-warm-the-deep-paths-of-a-new-UDP-session-and-of-its-.patch)
- `common/warm` keeps a goroutine that ran a function for 10 s and hands it the next one with its
  grown stack; none waiting, a new goroutine starts. Used by new `direct` sessions, 0302, 0301
  and the A question of 0310.
- arm64 at DNS saturation: 32 % more queries a second, 24 % less CPU a query; at most 8 workers.

#### 0505 go.mod: quic-go of the podkop-engine fork, Chrome's QUIC suites in the order of the CPU
`quic-chrome-suites` · since r26 · [patch](../patches/v1.14/0505-go.mod-quic-go-of-the-podkop-engine-fork-Chrome-s-QU.patch)
- quic-go of podkop-net `v0.61.0-sing-box-mod.12-pdk.1`: the Chrome QUIC ClientHello (hysteria2,
  xhttp over HTTP/3) puts ChaCha20 first without AES hardware, as Chrome. Before, hysteria2 on an
  MT7621 moved a third less and cost 40 % more CPU a GB than on 1.13.

### Layer 06: BitTorrent and the loss over QUIC (r27)

#### 0601 sniff: uTP only at the start of a connection, and the DHT of BitTorrent
`sniff-bittorrent` · since r27 · [patch](../patches/v1.14/0601-sniff-uTP-only-at-the-start-of-a-connection-and-the-.patch)
- uTP is taken only from a SYN (version 1, timestamp difference 0, extensions ending with the
  packet), as Xray does; about one random packet in 6,400 passed the old check.
- DHT (KRPC, BEP 5), a new packet sniffer before uTP, reports `bittorrent`: a client's socket,
  whose first packet is a DHT query, is now sniffed.

#### 0602 go.mod: quic-go and sing-quic of the podkop-engine forks, the statistics of a QUIC connection
`quic-stats` · since r27 · [patch](../patches/v1.14/0602-go.mod-quic-go-and-sing-quic-of-the-podkop-engine-fo.patch)
- quic-go `pdk.2` adds `ConnectionStats` (the peer's 1-RTT packets that came, the numbers that did
  not); sing-quic of podkop-net `v0.7.2-pdk.1` is upstream 7e0a5869a5f4 plus
  `Client.ConnectionStats` for the hysteria2 and tuic clients.

#### 0603 urltest: the loss of members over QUIC (hysteria2, tuic)
`urltest-quic-loss` · since r27 · [patch](../patches/v1.14/0603-urltest-the-loss-of-members-over-QUIC-hysteria2-tuic.patch)
- `hysteria2` and `tuic` members tell the counts of their QUIC connection
  (`adapter.QUICStatsOutbound`); before, they were chosen by delay alone.
- The probe downloads `loss_url` in windows of 20 KiB (its `bytes` parameter or ranges) and counts
  only on an unchanged connection, after the reorder wait of RFC 9002, with no UDP receive drops
  on the host.
- Over QUIC 1 % of loss costs ×1.03 at 20 ms and ×1.44 at 100 ms (TCP: ×2.85, ×1.57); on a netem
  stand the count was within 0.5 points for 0.5–5 % loss, a new connection on a clean path reads
  about 0.2 %.

### Layer 07: Xray's finalmask and certificate verification (r28)

#### 0701 finalmask: Xray's fragment mask on the TCP connections of an outbound; fm and pcs in links
`finalmask` · since r28 · [patch](../patches/v1.14/0701-finalmask-Xray-s-fragment-mask-on-the-TCP-connection.patch)
- The dial option `finalmask` `{"tcp": [{"type": "fragment", …}]}`: Xray's fragment mask on every
  TCP connection the outbound opens itself, beneath TLS, REALITY and every transport. `packets`
  `tlshello` (the ClientHello cut into TLS records), `N-M` or empty, `length`/`lengths`,
  `delay`/`delays`, `max_split`; masks in a list are chained as in Xray. Ranges are drawn as Xray
  draws them. A pause ends at close and at the write deadline; through `detour` it does nothing.
  Feature name `dialer.finalmask`.
- Measured on routers of three ISPs (podkop-exp `lab/runs/2026-11-21-fmcheck*`): where the
  ClientHello of the servers is dropped, records of 11–24 bytes written in two TCP pieces (the
  first of 100–200 bytes) passed 165 of 168 times over edge, ios, qq, chrome, firefox and safari;
  in one write a 508-byte hello (edge, ios) fits one packet and was dropped (0 of 28). REALITY
  servers (the engine's own, Xray 26.3.27) take the cut hello.
- The link decoder: `fm` fragment masks become `finalmask` (delays dropped; a `tlshello` with
  delays still goes a record a write); in Hysteria 2 links salamander becomes `obfs` (gecko with a
  `packetSize`), `udphop` and `quicParams.udpHop` the port hopping; `realm` is refused
  (`hysteria-realm`). `pcs` and `pinSHA256` become `certificate_sha256`.

#### 0702 tls: the server's certificate verified as Xray verifies it: other names, a pinned CA
`certificate-server-name` · since r28 · [patch](../patches/v1.14/0702-tls-the-server-s-certificate-verified-as-Xray-verifi.patch)
- `tls.certificate_server_name` (a list): the certificate is verified for any of these names in
  place of `server_name`, which is still sent (Xray's `verifyPeerCertByName`, `vcn` of links).
  Refused with `insecure`; not with REALITY, naive, or the apple and windows engines.
- `certificate_sha256` (0102) also takes a pinned CA of the chain above the leaf, the chain then
  verified to it by the names (Xray's `pinnedPeerCertSha256`); a pinned leaf is taken by itself.
  With a pin or names `disable_sni` no longer also verifies the server name against the roots.
- The decoder keeps a pin with `insecure`, maps `vcn`, reads both in the XHTTP download, and gives
  naive neither. Feature names `tls.certificate_sha256`, `tls.certificate_server_name`.

## 1.12.25 — 2 patches

The first two patches of the original series, without trailers; on 1.14 both are in 0401.

#### 0001 reality: keep X25519MLKEM768 key share, announce client version 26.3.27 (1.12.x backport)
since r1 · [patch](../patches/v1.12/0001-reality-keep-X25519MLKEM768-key-share-announce-clien.patch)
- REALITY keeps X25519MLKEM768 in the groups and key shares (servers since Xray-core v26.9.8
  reject a ClientHello without it) and announces 26.3.27 instead of 1.8.1; the key is the plain
  X25519 share or the X25519 part of the hybrid one.

#### 0002 utls: firefox -> Firefox 148, safari -> Safari 26.3 (as Xray-core)
since r1 · [patch](../patches/v1.12/0002-utls-firefox-Firefox-148-safari-Safari-26.3-as-Xray-.patch)
- `firefox` and `safari` are Xray-core's specs (refraction-networking/utls@aa6edf4); Firefox
  reuses the hybrid X25519 key for the classical share. `random` picks chrome, firefox or safari.

## Features → patches

| Feature | Patches | Summary |
|---|---|---|
| `build-slim` | 0001 | `podkop_slim` and `podkop_full` sets of protocols |
| `gomod-vmess` | 0002 | sing-vmess from the fork |
| `backport-ja3` | 0101 | the ja3 test of upstream 07512b109 |
| `backport-certificate-sha256` | 0102 | `certificate_sha256` of sing-box 1.15 |
| `dns-udp` | 0201, 0301 | a UDP socket per DNS query, resent at 1 s and 3 s |
| `dns-nat` | 0202, 0302 | DNS of NAT sessions answered by a handler |
| `listener-udp` | 0203, 0303 | UDP output queue of 1024 packets |
| `dns-log` | 0204, 0304 | a failed DNS exchange logged once per server |
| `box-memory` | 0205, 0305 | Go memory limit from the memory the system can give |
| `xhttp` | 0206, 0306 | the XHTTP transport client |
| `version` | 0207, 0308 | the `Features:` line of `sing-box version` |
| `decode-link` | 0307 | `sing-box tools decode-link` |
| `ruletext` | 0208, 0309 | rule-set format `text` |
| `dns-ipv6` | 0209, 0310 | `dns.ipv6_if_no_ipv4` |
| `hysteria-utls` | 0210, 0311 | uTLS fingerprint dropped on QUIC protocols |
| `cachefile-files` | 0211, 0312 | remote rule-sets in files beside the cache file |
| `route-chain` | 0212, 0313 | a chain dialed through its URL test |
| `hot-swap` | 0213, 0314 | `Box.UpdateOutbounds` |
| `route-block-log` | 0315 | `block` refusals at debug |
| `dns-group` | 0214, 0316 | DNS server types `group` and `provider` |
| `probesock` | 0215, 0317 | packet capture of loss probe connections |
| `utls-reality` | 0401 | REALITY and uTLS hellos as Xray and the browsers |
| `rule-set` | 0402 | start, download and update of remote rule-sets |
| `dns-transport` | 0403 | TCP/TLS pipelining cap, DoH under loss |
| `dns-provider` | 0404 | the provider's DNS as a fallback |
| `fakeip` | 0405 | FakeIP table in memory, saved in the background |
| `fakeip-route` | 0406 | the sniffed domain for a FakeIP address without a record |
| `sniff` | 0407 | bounded, panic-safe sniffers |
| `route-loop` | 0408 | no `direct` loop back to the inbound |
| `transport` | 0409 | dial and close of v2ray transports |
| `urltest` | 0410 | the urltest group of the fork |
| `log` | 0411 | log formatting only for readers |
| `clashapi` | 0412 | Clash API listen, UI update, connection records |
| `tlsspoof` | 0413 | `tls.spoof` along the connection's route, with REALITY |
| `tls-fp-fallback` | 0414 | uTLS fingerprint fallback |
| `vless` | 0415 | VLESS Encryption, flow checks |
| `vmess` | 0416 | `security: auto` under TLS |
| `record-fragment` | 0417 | `fragment`, `record_fragment` on REALITY |
| `domainset` | 0418 | domain trie of rule-sets |
| `cidrset` | 0419 | CIDR ranges of rule-sets |
| `box-start` | 0420 | `Box.StartWithoutClose` |
| `detector` | 0421 | per-server handshake outcomes for a block detector |
| `http-client-fallback` | 0422 | fallback HTTP clients for rule-set downloads |
| `http-client-downloader` | 0423 | download ways of an HTTP client (`outbounds`) |
| `rule-match-log` | 0501 | matched-rule debug line built lazily |
| `dns-question-line` | 0502 | DNS exchange debug line built lazily |
| `slim-tools` | 0503 | no networkquality, STUN, schema in podkop-engine |
| `warm-goroutines` | 0504 | warm goroutines for the DNS paths |
| `quic-chrome-suites` | 0505 | quic-go fork: Chrome's QUIC suite order |
| `sniff-bittorrent` | 0601 | uTP by SYN only, DHT sniffer |
| `quic-stats` | 0602 | quic-go and sing-quic forks: QUIC connection statistics |
| `urltest-quic-loss` | 0603 | loss of hysteria2 and tuic members |
| `finalmask` | 0701 | Xray's fragment mask in the dialer; `fm`, `pcs` in links |
| `certificate-server-name` | 0702 | `certificate_server_name`, a pinned CA; `vcn` in links |
