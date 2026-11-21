# Benchmarks

[Русский](BENCHMARKS.ru.md)

podkop-engine against vanilla sing-box of the same version, and each release against the one
before. The newest comparison (r28 against r27) comes first, then r27 against 1.14.4, then the
earlier ones, which show what a patch did when it was made.

How the newest one was measured: both binaries are built the same way (Go 1.26.8, static,
`-trimpath`, the tags of the package; the engine adds `podkop_slim`, so the comparison includes
what the slim set leaves out). Each test runs 5 rounds per binary, the two taking turns; the
tables give medians. A difference is reported when the Mann–Whitney p is 0.008 (the smallest
possible with 5 + 5 rounds). For CPU per DNS query and per connection it must also lie outside the
run of r27 against itself on that host (the A/A ratio: x86_64 1.05 and 0.93, arm64 0.99 and 1.00).
Differences at p 0.03–0.1 are shown with their p. A single result that neither the other host nor a
related test repeats is not counted; it is named below the table.

## r28 against r27 (2026-11-21)

The same two hosts, harness and rules as below; both arms are engine builds (r27 and r28, the
same Go, flags and tags), so this shows what r28 changed. Proxy downloads go to the test server
over the internet (REALITY on Xray 26.9.9, hysteria2 on sing-box).

| Test | x86_64: r27 → r28 | arm64: r27 → r28 |
|---|---|---|
| DNS, a name of the lists (FakeIP) at 500 queries/s, CPU per query | the same | the same (103 µs both) |
| DNS, FakeIP at saturation: queries a second | the same (12 050 → 11 800, p 0.55) | 15 740 → 14 840 (−6 %, p 0.008; a rerun of 8 rounds: −3 %, p 0.010), see below |
| DNS, a name asked of an upstream server at 500/s, CPU per query | 256 → 244 µs (−5 %, p 0.008; not repeated on arm64) | the same |
| Connections through the mixed inbound, CPU per connection | the same | the same; at 100 a second −2 % (p 0.016) |
| Idle, 30 s after the start: RSS / anonymous memory | the same | the same |
| Lists of 100 000 entries (domains and subnets in `.srs`, domains in source JSON): start, CPU, memory | the same | the same |
| Proxy traffic, CPU per GB: hysteria2, REALITY with and without Vision, Trojan, Shadowsocks AES and ChaCha20 | the same (a noisy path that day: 1–12 MB/s) | the same (14–20 MB/s) |
| REALITY with Vision, with the `finalmask` podkop sets against a dropped ClientHello (r28 alone) | not measured: the path was too noisy | the same: 17.6 → 17.2 MB/s, the same CPU per GB |
| Static binary | 35.33 → 35.39 MB | 32.96 → 33.10 MB |

- **DNS at saturation on arm64** came out 3–6 % slower with r28 in two runs. r28 changes no file
  on that path (`dns/`, `route/`, FakeIP, the direct inbound, `log/`), the CPU profiles of the two
  arms have the same shape, x86_64 shows no difference, and neither does FakeIP at 500 queries a
  second. It is taken for an effect of the build (where the code lands in the binary), not a change
  of r28, and not counted. The same holds for the two small gains (DNS of an upstream server on
  x86_64, connections at 100/s on arm64).
- **finalmask** cuts the ClientHello once per connection; downloads with and without it do not
  differ.

## r27 against sing-box 1.14.4 (2026-11-17)

Two hosts: **x86_64**, one core of an AMD Ryzen 9 7950X3D shared by sing-box and the load, AES;
**arm64**, Neoverse, sing-box on one of 4 cores and the load on two others, AES. This is why the
saturation figures of the two hosts differ. The load runs on the same host; proxy downloads go to a test server over the
internet. Routers (MT7621, Filogic 820) are [not measured yet](#not-measured).

| Test | x86_64: vanilla → r27 | arm64: vanilla → r27 |
|---|---|---|
| REALITY to an Xray 26.9.9 server | **refused (0 of 10) → works (10 of 10)** | **refused (0 of 10) → works (10 of 10)** |
| Proxy traffic, CPU per GB: hysteria2, Trojan, Shadowsocks, REALITY on Xray 26.6.27 | the same | the same, except REALITY without flow: +25 % (p 0.008, not repeated; see below) |
| DNS, a name of the lists (FakeIP) at 500 queries/s, CPU per query | 116 → 113 µs, the same | 101 → 97 µs (−4 %) |
| DNS, FakeIP at saturation: queries a second | 8 788 → 12 110 (**+38 %**) | 10 060 → 18 120 (**+80 %**) |
| DNS, FakeIP at saturation: CPU per query | 72 → 39 µs (−46 %) | 99 → 55 µs (−44 %) |
| DNS, a name asked of an upstream server at 500/s, CPU per query | 153 → 209 µs (**+37 %**, see below) | 161 → 219 µs (**+36 %**) |
| Connections through the mixed inbound, CPU per connection | the same | the same |
| Idle, 30 s after the start: RSS / anonymous memory | 35.9 → 32.6 MB / the same | 33.0 → 30.5 MB / the same |
| A list of 100 000 domains in source JSON: start | 0.37 → 0.02 s | 0.68 → 0.05 s |
| The same list: anonymous memory | −21 % | −20 % |
| A list of 100 000 subnets in `.srs`: start; anonymous memory | 0.03 → 0.02 s; −15 % (p 0.056) | 0.05 → 0.03 s; −32 % |
| A list of 100 000 domains in `.srs` | start the same; anonymous memory +15 % (p 0.095) | the same |
| Static binary | 40.6 → 35.3 MB | 37.9 → 33.0 MB (mipsle: 42.9 → 37.6 MB) |

- **Proxy traffic** costs the same CPU: the relay code is upstream's. The downloads were limited by
  the path (11 MB/s on x86_64, 17–22 MB/s on arm64), so CPU per GB is the figure to compare.
  REALITY without flow on arm64 came out 25 % more CPU per GB with r27 on a noisy path; neither the
  x86_64 host nor Vision showed it, so it is not counted as a difference.
- **DNS at saturation** is faster because the engine keeps the goroutines of a new UDP session warm
  (r26).
- **A name asked of an upstream DNS server costs more** in the engine: it sends each query from a
  UDP socket of its own (r4), where vanilla sends every query over one socket. CPU profiles put the
  price at about 55 µs per query. The engine does this for providers that limit the queries of one
  source socket (Yandex DNS: about 20 a second). Names of the lists, answered from FakeIP, do not
  pay it.
- **Lists**: JSON lists of domains are built in one pass (r15). Domain lists in `.srs` load equally
  fast in both; subnet lists in `.srs` start a third faster (tens of milliseconds).

## Earlier comparisons (September – early November 2026)

These compare a podkop-engine release of that time with vanilla sing-box of the same version,
or with the code of upstream for one part. They show what a patch did when it was made. Later
releases changed some of these parts again.

### Size

Binaries built with the same Go 1.26.8, MiB, 2026-10-02:

| Build | x86_64 | arm64 | armv7 | mipsle |
|---|---|---|---|---|
| sing-box 1.13.21 of OpenWrt 25.12, full | 45.6 | 42.4 | 41.9 | 48.3 |
| sing-box 1.14.2 of upstream, all features | 87.7 | 82.0 | 77.5 | 97.5 |
| podkop-engine 1.14.2-r7 | 32.7 | 30.3 | 30.0 | 34.5 |

Since r9 the slim package also leaves out every outbound podkop does not write (1.14 on x86_64:
24.3 MB instead of 29.2).

### Memory of a running sing-box

x86 stand, the same podkop configuration, 2026-10-02:

| | idle, with the list russia_inside | after 3000 FakeIP names and 60 000 queries |
|---|---|---|
| sing-box 1.12.22 of OpenWrt, tiny / full | 30.1 / 37.7 MB | |
| sing-box 1.13.21 of OpenWrt, tiny / full | 32.5 / 40.3 MB | 39–43 / 47–50 MB |
| podkop-engine 1.13.21-r7 | 30 MB | 41–44 MB |
| podkop-engine 1.14.2-r7 | 34–35 MB | 41–44 MB |

Of these 30–45 MB of RSS, 22–28 MB are pages of the binary; private memory is 5–7 MB idle and
13–18 MB after the load. Every sing-box has a virtual size of 1.2–1.3 GB (Go reservations): LuCI's
process list shows that as hundreds of percent.

### FakeIP

x86 stand, cache file in /tmp, 2026-10-02. "Upstream" is a build with the FakeIP code of upstream
1.14.2; r7 is the in-memory store of podkop-engine.

| | upstream | r7 |
|---|---|---|
| New names a second | 95 | 80 000–100 000 |
| CPU per new name | 460–680 µs | 38–50 µs |
| A burst of 100 new names, the last answer | about 1040 ms | 2.1–4.8 ms |
| The same with the cache file on emulated SPI-NAND | about 1170 ms | 1.6–4.0 ms |
| Written to the cache file for 30 000 names | 1.0 GB | 150–165 MB |

### DNS

- The first DNS query of a new UDP session, x86, 150 s with 4 DNS clients under HTTP load,
  `hijack-dns` without `sniff` before it (2026-10-09): vanilla 1.13.21 left 41 of 42 306 queries
  unanswered, podkop-engine r13 0 of 56 346 (1.13) and 0 of 56 591 (1.14). podkop's own config
  (sniff first) is not affected.
- A DoH server that closes its HTTP/2 connection without a GOAWAY (Quad9), pauses of 0–90 s
  between queries (2026-10-10): `unexpected EOF` in 1 of 13 queries with both vanilla 1.13.21 and
  r13; r14 asks such a query again on a new connection.

### Lists

Loading a rule-set of the source format (JSON), x86, 2026-10-18; "upstream" is the code of
upstream that built the list:

| | upstream | podkop-engine |
|---|---|---|
| 100 000 CIDRs: growth of the process, time | +37–42 MB, 0.35 s | +3 MB, 13–15 ms |
| 1 000 000 CIDRs: the same | +346–392 MB, 3.3 s | +19 MB, 0.13 s |
| 100 000 domains: time and memory allocated while loading (Go benchmark) | 390 ms, 277 MB | 24 ms, 23 MB |

On an aarch64 emulator with 256 MB, a JSON list of 100 000 domains ran out of memory before r15
(at 135–139 MB) and loads in 2 s since.

### urltest with a failing server

x86 stand, four Xray VLESS REALITY Vision servers at 20, 80, 110 and 150 ms, page loads and a
6 Mbit/s video through a selector over a urltest group with a 30 s interval; vanilla sing-box
1.14.4 against podkop-engine r21 (2026-11-03). The share is the time spent on the first server.

| What the first server did | vanilla: share / pages failed / video stalled | r21 |
|---|---|---|
| went dead | 17 % / 6.6 % / 29 s | 12 % / 1.1 % / 29 s |
| 3 % loss | 89 % / 0 / 33 % | 89–94 % / 0 / 30–35 % |
| 10 % loss | 78 % / 0 / 79 % | 61 % / 0.4 % / 66 % |
| slow | 23 % / 7.2 % / 25 % | 28 % / 5.3 % / 32 % |

Vanilla cannot connect to Xray 26.9.9 (below), so these runs used Xray 26.6.27 servers; r21 gave
the same results on both.

### Compatibility with Xray servers (REALITY)

Matrix of Xray server versions × 11 cover sites, `chrome` fingerprint, 2026-10-25 and 2026-11-01:

| Xray server | vanilla sing-box 1.12.25–1.14.4 | podkop-engine |
|---|---|---|
| 26.7.11 and newer | refused: it announces client version 1.8.1, below the default `minClientVer`; 26.9.9 and newer also refuse a ClientHello without X25519MLKEM768 | works |
| 25.5.16 – 26.6.27 | works | works |
| 24.11 – 25.4.30, cover site that chooses X25519MLKEM768 | works | refused, unless the fingerprint fallback (r17) sends its first ClientHello without X25519MLKEM768 |

A DPI path that freezes bursts of ClientHellos with X25519MLKEM768 (2026-10-25): the engine's
`chrome` got 0 of 20 through and froze for 40–41 s; vanilla, whose ClientHello has no
X25519MLKEM768, got 43–100 % through. With the fingerprint fallback (r17) the engine gets 18–20 of
20 through.

## Not measured

- Routers: MT7621 (no AES) and Filogic 820 runs of the same tests are prepared and are run by the
  owner; their results will be added here.
- Memory under heavy proxy traffic, days of uptime, IPv6.
