# podkop-engine

[Русский](README.ru.md)

An unofficial build of [sing-box](https://github.com/SagerNet/sing-box) for
[podkop](https://github.com/itdoginfo/podkop) on OpenWrt. **The project is not affiliated with
sing-box or its authors.** The package has another name because the license of sing-box does not
let derivative works use its name. It still installs `/usr/bin/sing-box` and declares
`PROVIDES: sing-box`, so podkop's dependency on `sing-box` is met.

Who uses it:

- **podkop 0.7.x** runs on it once you install it in place of OpenWrt's `sing-box`; for podkop
  0.7.24 take 1.14.4-r26 or newer. XHTTP links and URLTest fallbacks in podkop work only with this build.
- **[podkop-exp](https://github.com/podkop-net/podkop-experimental)** builds the same code into its
  own backend; it needs no package.

## What it adds to sing-box

- **Current Xray servers.** REALITY sends the X25519MLKEM768 key share and the client behaves as
  Xray 26.9.9. The uTLS fingerprints match Xray's (`firefox` = Firefox 148, `safari` = Safari
  26.3), and `randomized` is consistent.
- **Answers to DPI.** The fingerprint fallback (off by default; podkop-exp turns it on) tries other
  ClientHellos when one gets no answer, and remembers the one that works. `tls.spoof` (upstream's forged ClientHello) also works with
  REALITY, and so do `fragment` and `record_fragment`.
- **Protocols of Xray:** the XHTTP transport and VLESS Encryption. `sing-box tools decode-link`
  turns share links of every protocol into outbounds.
- **Starts without lists.** A remote rule-set that does not download no longer stops sing-box: it
  starts with an empty list and keeps trying. A list that does not come directly can come
  through other outbounds (`http_clients`).
- **Big lists in little memory.** Domains are kept in a compact trie and CIDRs as ranges. Lists
  live in files beside the cache file, not inside it.
- **DNS that keeps answering.** A socket per query, queries sent again, the provider's DNS as the
  fallback (of every uplink in podkop-exp), groups of servers asked in order or fastest first. AAAA is given when a
  name has no IPv4 (`ipv6_if_no_ipv4`).
- **urltest:** fallback outbounds (also `block`), a download check before a switch, several test
  URLs with a median, the modes `loss` and `balance` (for QUIC members too), at most 4 tests at
  once.
- **Outbounds replaced while sing-box runs**, so a changed subscription cuts no open connection
  (for programs that embed the engine, such as podkop-exp).
- **FakeIP** answers from memory and saves in the background. A connection to a FakeIP address
  without a record goes by the sniffed domain.
- **Memory:** the Go memory limit follows the memory the system can still give. Idle TLS, QUIC
  and gRPC connections wait for data without holding a buffer.
- **Sniffers:** BitTorrent is recognized by uTP and the DHT, and a WireGuard tunnel is no longer
  taken for BitTorrent. A crafted packet cannot crash sing-box: a sniffer that fails ends only its
  connection.
- **A block detector** reads what each server does and reports it to podkop-exp's dashboard.
- **Two smaller packages** (below), and a failsafe service. If sing-box keeps crashing, the
  service stops podkop so that the router gets its DNS back.
- **Fixes** in DNS, the v2ray transports, the Clash API and more: see the [changelog](CHANGELOG.md).

Every option is described in [docs/FEATURES.md](docs/FEATURES.md); the measured effect against
vanilla sing-box is in [docs/BENCHMARKS.md](docs/BENCHMARKS.md).

## Packages

Two packages; install one of them.

| | `podkop-engine` | `podkop-engine-full` |
|---|---|---|
| Inbounds | tproxy, direct, mixed | the same |
| Outbounds | direct, socks, shadowsocks, trojan, vless, hysteria2, tuic, http, selector, urltest, block | the same, plus vmess, snell, tor (needs the tor package), ssh, shadowtls, anytls, hysteria, naive (NaiveProxy, [not on every architecture](docs/INSTALL.md#naiveproxy)) |
| Package, r29: x86_64 / aarch64_cortex-a53 / mipsel_24kc | 9.8 / 8.8 / 8.8 MB | 15.6 / 14.3 / 15.4 MB |

Not in either package, compared with a full sing-box: other server inbounds, TUN,
WireGuard and Tailscale inside sing-box (WireGuard and AmneziaWG work in podkop as OpenWrt
interfaces), DoQ, DoH3 and DHCP DNS servers, ACME, services (the API, SSM API, OOM killer and others). A config with a type
the package lacks fails `sing-box check` with a clear message, for example
`vmess outbound is not included in this build (podkop_slim), install podkop-engine-full or rebuild
with -tags podkop_full`.

## Install

Pick the file for your architecture (`opkg print-architecture` or `apk --print-arch`) from the
[latest release](https://github.com/podkop-net/podkop-engine/releases/latest). The release notes
have a one-line command for opkg and apk. Switching between the packages, upgrades and going back
to OpenWrt's sing-box are in [docs/INSTALL.md](docs/INSTALL.md).

## Versions

- Tags are `v<sing-box version>-r<revision>`, for example `v1.14.4-r29`. The revision is the
  release of podkop-engine; one revision covers every line built in it.
- **1.14** is the line that is maintained (sing-box 1.14.4, 71 patches). 1.12.25 had one release
  (r1, two patches). The 1.13 line ended with `v1.13.21-r18`.
- `sing-box version` prints `1.14.4-pdk-r29` and a `Features:` line with what this build adds.
- The fork is the upstream tag plus [the patches](docs/PATCHES.md) and nothing else: branch
  `podkop-engine-1.14` of [podkop-net/sing-box](https://github.com/podkop-net/sing-box).
- Built with Go 1.26.8 from openwrt/packages, `.ipk` in the SDK of OpenWrt 24.10 and `.apk` in the
  SDK of 25.12, for every architecture OpenWrt builds sing-box for.

## Compatibility with servers

The client behaves as Xray-core 26.9.9: it works with Xray servers 25.5.16 and newer. With Xray
24.x–25.4.30, the first ClientHello of the fingerprint fallback (without X25519MLKEM768) is
accepted; without the fallback, such a server refuses the connection when its cover site chooses
X25519MLKEM768 (most large sites do). Updating Xray on the server cures it.

## Documentation

| | |
|---|---|
| [docs/INSTALL.md](docs/INSTALL.md) | install, switch packages, upgrade, remove; the failsafe service; NaiveProxy architectures |
| [CHANGELOG.md](CHANGELOG.md) | what changed in each release, r1 … r29 |
| [docs/FEATURES.md](docs/FEATURES.md) | the options and tools this build adds, with examples |
| [docs/PATCHES.md](docs/PATCHES.md) | every patch to sing-box and what it changes |
| [docs/BENCHMARKS.md](docs/BENCHMARKS.md) | measurements against vanilla sing-box |
| [docs/LINKS.md](docs/LINKS.md) | the share links `decode-link` reads, key by key (in Russian) |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | the layout of this repository, building, checks |
| [docs/RELEASE.md](docs/RELEASE.md) | how a release is made (in Russian) |

## License

GPL-3.0-or-later (`LICENSE`); the license of sing-box is in `LICENSE.sing-box`. The packaging is
based on `net/sing-box` of openwrt/packages.
