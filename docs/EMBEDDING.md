# Programs that embed the engine

podkop-engine is also a Go library. [podkop-experimental](https://github.com/podkop-net/podkop-experimental)
(podkop-exp) builds the fork into its own backend instead of running `/usr/bin/sing-box`: its
`go.mod` replaces `github.com/sagernet/sing-box` with a commit of
[podkop-net/sing-box](https://github.com/podkop-net/sing-box) that is a release of podkop-engine
(`SB_1_14_FORK_COMMIT` of a tag `v1.14.x-rN`, or of a pre-release `-rcN`; podkop-exp's
`sdk/check-engine.sh` refuses any other commit).

This page is the contract between the engine and such a program: everything it relies on beyond
upstream sing-box, as of r29 (fork `f866c9d89834`). The API of upstream sing-box (`box.New`,
`adapter`, `option`, the registries, the Clash API as upstream has it) is upstream's contract and is
not repeated here. The options of a configuration are described in [FEATURES.md](FEATURES.md), the
patches in [PATCHES.md](PATCHES.md).

## The rule

Nothing on this page changes without a release note. A symbol removed or renamed, a signature, a
meaning, an option, an environment variable, the format of a key, the text of an error that a
program reads: each change is a line under **embedding:** in the entry of the release in
[CHANGELOG.md](../CHANGELOG.md) (**встраивание:** in CHANGELOG.ru.md) that names it and says what
an embedding program has to change, and this page changes in the same commit. Additions are noted
the same way. A patch that would change one of these quietly is cut differently, or waits for a
release that says so.

podkop-exp holds its side in its code and tests: `src/backend/engine/fork.go` asserts every symbol
of the next section at compile time, `imports_test.go` keeps the imports of sing-box inside its
package `engine`, `doors_test.go` lists its files that use the Clash API or set the environment of
the engine, and `TestProbeErrorClass` holds the error texts. They fail when podkop-exp moves its
pin, not when the engine changes: the note is what tells it to look. The engine's own side is held by
`embedder_test.go` (0802, since r29).

## Go API of the fork

"Patch" is the file of `patches/v1.14` that brings it; "since" is the first release that had it in
this form.

| API | Patch | Since | What podkop-exp does with it |
|---|---|---|---|
| `(*box.Box).StartWithoutClose() error` | 0420 | r16 | starts an instance; a start that fails leaves the box to the caller to close |
| `(*box.Box).UpdateOutbounds(outbounds []option.Outbound, remove []string, limit int) (box.OutboundUpdate, error)`, `box.OutboundUpdate{Added, Replaced, Removed, Kept}`, `box.ErrTooManyKept` | 0314 | r19 | replaces servers while the box runs ([FEATURES.md](FEATURES.md#outbounds-replaced-while-sing-box-runs)) |
| `(*route.Router).UpdateRuleSets(ctx) (rule.RuleSetUpdateSummary, error)`, `rule.RuleSetUpdateSummary{Total, Loaded, Failed}` | 0402 | r15 | updates the lists on request |
| `(*fakeip.TableStore).Peek(domain string, isIPv6 bool) (netip.Addr, bool)` (package `dns/transport/fakeip`) | 0405 | r25 | the FakeIP address of a name, without giving one |
| `adapter.CacheFile.LoadDetectOutcome(key string) (flags byte, fingerprint string, at time.Time, loaded bool)`; the flags `adapter.DetectNoAnswer`, `DetectRefused`, `DetectFailed` | 0421 | r21 | the block detector: what the handshakes with a server met (key: [below](#the-key-of-a-servers-record)) |
| `(*trafficcontrol.Manager).DetectFlows() map[string]trafficcontrol.DetectFlowSample`, `ForgetDetectFlows(tags []string)`; `DetectFlowSample{Cuts []DetectFlow, LastBigAt, LastDataAt}`, `DetectFlow{Download, Upload, CreatedAt, ClosedAt, PendingSince}`; `(*trafficcontrol.TrackerMetadata).PendingSince() time.Time` | 0421 | r21 | the block detector: the closed and the open connections of each outbound |
| `(*urltest.HistoryStorage).LoadURLTestFailure(tag string) (time.Time, bool)`, `LoadDownloadResult(tag string) (urltest.DownloadResult, bool)`, `urltest.DownloadResult{At, Received, Stopped}` | 0410 | r21 | the block detector and the page: the last failed URL test, the last download check |
| `httpclient.DownloadMemory`, `httpclient.NewDownloadMemory()`, `(*DownloadMemory).Forget(way string)`, `SetExcluded(tags []string)` | 0423 | r26 | what the downloaders learned of the ways, kept for the process across instances |
| `adapter.HTTPDownloaders` (`ResolveDownloader(*option.HTTPClientOptions) (HTTPDownloader, error)`), implemented by `*httpclient.Manager`; `adapter.HTTPDownloader` (`Ways(host string) ([]string, bool)`, `Record(host, way string, err error, took time.Duration, bytes int64)`) | 0423 | r26 | downloads subscriptions and mask lists itself, through the ways of a client |
| `log.PlatformWriterLevel` (`Level() log.Level`), `log.PlatformWriterColors` (`DisableColors() bool`) | 0411 | r15 | implemented by its platform writer (`box.Options.PlatformLogWriter`): lines of the configured level only, without colours |
| `option.UTLSFallbackOptions{Enabled, Fingerprints}` | 0414 | r13 | a copy of an outbound for a probe is built with the fallback off |
| `sharelink.Decode(link string) (*sharelink.Outbound, []string, error)`; `(*sharelink.Outbound).Secrets() []string`, `Unplain() []string`; `sharelink.OneLine(message string) string`, `sharelink.PlainMessage(message string, secrets []string) string` | 0307 | r11 (`Decode`), r13 (`Secrets`, `Unplain`), r15 (`OneLine`, `PlainMessage`) | reads the links of servers and subscriptions; errors without what a link keeps secret |
| `ruletext.ReadAddresses(content []byte) (option.PlainRuleSetCompat, ruletext.Skipped, error)`, `ruletext.Skipped{Count, First}` | 0309 | r15 | checks a list written as text, and reads its addresses |
| `domainset.ReadSource(content []byte)`, `domainset.ReadSourceAddresses(content []byte)`, both `(option.PlainRuleSetCompat, error)` | 0418 | r15, r16 | reads a rule set of the source format as sing-box does |
| `srs.ReadSets(reader io.Reader) (option.PlainRuleSetCompat, error)` | 0419 | r15 | reads a binary rule set as sing-box does |
| `option.DefaultHeadlessRule.DomainSet` (`*succinct.Set`) | 0418 | r15 | tells a rule with domains |
| `option.DefaultHeadlessRule.IPRanges`, `.SourceIPRanges` (`*cidrset.Set`: `Len() int`, `Ranges() []netipx.IPRange`, `Ranges4() []uint64`) | 0419 | r15 (`Ranges4` r16) | the addresses of rule sets for the sets of its firewall |
| `constant.RuleSetFormatText` (`"text"`) | 0208 | r15 | the format of lists written as text |
| `constant.V2RayTransportTypeXHTTP` (`"xhttp"`) | 0206 | r11 | tells XHTTP servers apart |
| `tls.ErrRealityVerification` | 0414 | r29 | tells a server whose certificate is not the one REALITY expects, by its type |
| `adapter.DetectOutcomeKey(fingerprint, serverName string, destination M.Socksaddr) string` | 0421 | r29 | the key of the record of a server |
| `rule.RemoteStart{Empty bool}` | 0402 | r29 | the empty start of remote rule sets for a box, without the environment |
| `urltest.ContextWithTest(ctx) context.Context` | 0410 | r29 | marks its own dials through a group as tests |

How the program reaches them, which decides how a change shows up:

- **By name** (most of the table): a change does not build.
- **By a run-time check of an interface** on an object sing-box made: `UpdateRuleSets` on
  `service.FromContext[adapter.Router]`, `Peek` on the store of `adapter.DNSTransportManager`'s
  FakeIP, `adapter.HTTPDownloaders` on `service.FromContext[adapter.HTTPClientManager]`. A change
  still builds and the feature is quietly gone; podkop-exp's `fork.go` turns it back into a build
  error.
- **Implemented by the program**, asked by sing-box: `log.PlatformWriterLevel`,
  `log.PlatformWriterColors`. A change makes sing-box stop asking; the program gets every line,
  coloured.
- **In the context**, given by the program before `box.New`: the history of the URL tests
  (`service.ContextWithPtr(*urltest.HistoryStorage)`, upstream) and the download memory
  (`service.ContextWithPtr(*httpclient.DownloadMemory)`, which `httpclient.NewManager` takes),
  both kept for the process; `service.ContextWithPtr(&rule.RemoteStart{Empty: true})`, the start of
  the remote rule sets (r29); and, for a probe, `service.ContextWith[*option.UTLSFallbackOptions]`
  with `Enabled: false` and `service.ContextWith[adapter.CacheFile](ctx, nil)` on a context
  extended from the box's, before `OutboundRegistry.CreateOutbound` and the start stages of the
  copy.
  This relies on an outbound looking these up in its context when it is made and started; a
  change of the type looked up builds and is quietly ignored.

## Options only the fork reads

What podkop-exp writes into the configurations it builds and checks with sing-box (`plan`, checked
by its `engine.Check`):

| Option | Patch | Since |
|---|---|---|
| `experimental.utls_fallback` (`enabled`) | 0414 | r13 |
| `dns.ipv6_if_no_ipv4` | 0310 | r17 |
| DNS server types `group` (`servers`, `strategy`) and `provider` | 0316 | r21 |
| `http_clients[].outbounds` | 0423 | r26 |
| rule-set `format: "text"` | 0309 | r15 |
| urltest `fallbacks`, `download_url` | 0410 | r10 |
| urltest `urls`, `mode` (`loss`, `balance`), `loss_url`, `loss_interval`, `loss_threshold` | 0410, 0603 | r24 |
| urltest `idle_timeout` of a fallback group in mode `loss` or `balance` | 0410 | r29 (bounds its loss probes) |
| `tls.spoof` on a REALITY client | 0413 | r13 |
| `tls.record_fragment` on a REALITY client | 0417 | r24 |

Through the links it reads (and the Xray JSON it turns into links), podkop-exp also relies on the
outbounds the decoder makes: the transport `xhttp` (0306, r11), VLESS `encryption` (0415, r14),
`finalmask` (0701, r28), `tls.certificate_sha256` (0102, r28), `tls.certificate_server_name`
(0702, r28) and the `sb.*` parameters of the decoder (0307). That dialect is
[LINKS.md](LINKS.md). The service type `podkop-bittorrent` in its configurations is podkop-exp's
own, registered through the registries of `box.Context`; the engine knows nothing of it.

## Environment

Read with `os.Getenv`; the full list is in [FEATURES.md](FEATURES.md#environment-of-sing-box). Those
podkop-exp sets:

| Variable | Read | Set by podkop-exp | Patch | Since |
|---|---|---|---|---|
| `SING_BOX_RULE_SET_START_EMPTY` | at each start of a remote rule set, unless `rule.RemoteStart` is in the context of the box (r29) | no longer set (the context says it) | 0402 | r15 |
| `SING_BOX_DNS_FALLBACK` | once, when the process starts | its init script: `ubus` while `podkop.settings.dns_fallback` is on (the default) | 0404 | r4 (1.14: r5) |
| `GOMEMLIMIT` | by Go; set, the engine leaves its own limit off | its init script, from `podkop.settings.memory_limit` | 0305 | r9 |

`SING_BOX_UTLS_FALLBACK` (read once at the start) is not set: podkop-exp always writes
`experimental.utls_fallback`, which wins over it. `SING_BOX_URLTEST_DOWNLOAD_URL` and
`SING_BOX_RULESET_RECOVERED_HOOK` belong to the init script of the package and are not used. A
variable read once at the start cannot be set by the program itself with `os.Setenv`: it goes into
the environment of the process.

## Formats and texts

### The key of a server's record

The handshake outcomes in the cache file (`LoadDetectOutcome`) are kept under

```
<fingerprint> <server name> <destination>
```

joined by single spaces: the uTLS fingerprint as configured (`tls.utls.fingerprint`), the
`tls.server_name` of the outbound and the server as dialed, `host:port` (`M.Socksaddr.String()`,
IPv6 in brackets). The REALITY client records under it, and the fingerprint fallback keeps its
choice under the same key (`common/tls`: `reality_client.go`, `utls_fallback.go`). The key is made by
`adapter.DetectOutcomeKey` (since r29; its form is unchanged). podkop-exp builds it from the
outbounds of its configuration (`engine.ServersOf`).

### Error texts podkop-exp reads

podkop-exp tells the kind of a failed probe and cleans the errors of a check by their text:

| Text | Where | podkop-exp |
|---|---|---|
| `reality verification failed` | `common/tls` (the text; the type is `tls.ErrRealityVerification` since r29, XHTTP keeps it) | a server whose certificate is not the one REALITY expects; read by its type since r29 |
| `timeout: no recent network activity`, `timeout: handshake did not complete in time` | quic-go (the errors of the podkop-net fork; XHTTP over HTTP/3 passes on the text, not the type) | a QUIC handshake nothing answers |
| `lookup ` | the errors of `dns.Router.Lookup` | a name that did not resolve |
| `outbounds[0].`, `initialize outbound[0]: `, `create client transport: ` | the errors of `box.New` and of the outbounds | cut from the front of the error of a check of one outbound |
| `unknown field `, `Go struct field ` | the JSON decoder of sing | the option a check refused |

In the log, the prefix of the level (`^[A-Z]+\[[0-9]+\] `) is cut from each line of the platform
writer, and the logins of the `mixed`, `socks` and `http` inbounds are masked by their text
(`authentication failed, username=` or `Proxy-Authorization=`, and `inbound/<type>[<tag>]: [<user>]
inbound connection`).

### The version

The package sets `constant.Version` to `<sing-box version>-pdk-r<N>` (`1.14.4-pdk-r29`); podkop-exp
sets it with its ldflags to `<sing-box version>-pdk-<12 hex digits of the fork commit>`
(`1.14.4-pdk-f866c9d89834`) and reads both up to `-pdk-`.

## Clash API

podkop-exp's commands (latency tests, the choice of a selector, the update of the dashboard) use
the Clash API of the configuration that runs, at the address and with the key it configured:
`GET /proxies`, `GET /proxies/{name}`, `GET /proxies/{name}/delay`, `GET /group/{name}/delay` (a
round of the URL test of the fork's group: 0410, 0603), `PUT /proxies/{name}` and
`POST /upgrade/ui`, with `Authorization: Bearer <secret>`. What these answer for the urltest group
of the fork (`fallbacks`, `mode`, `loss`, `balance` in `/proxies`) is part of this contract; since r29
`/proxies` has no `balance` for a group in mode balance that is not in use (an empty list: in use, and
no member in it).

## Build profile

What podkop-exp copies by hand from the package (`openwrt/podkop-engine/Makefile`):

- **Tags** `with_quic,with_utls,with_clash_api,podkop_slim,badlinkname,tfogo_checklinkname0` and
  `-ldflags=-checklinkname=0` (podkop-exp's `podkop/Makefile`). `podkop_slim` decides what the
  registries hold (0001; `podkop_full` beside it adds the protocols of `podkop-engine-full`);
  without it they hold what upstream registers for the other tags, the set podkop-exp's CI tests
  most of its packages with.
- **GODEBUG** `multipathtcp=0,tlssha1=1`: the package sets `runtime.godebugDefault` with `-X`,
  podkop-exp has a `godebug` block in its `go.mod`.
- **The `replace` lines** of the fork's `go.mod` (sing-vmess, quic-go and sing-quic of
  podkop-net/FiyeroT): a replace counts only in the main module, so the program repeats each one;
  podkop-exp's `sdk/check-engine.sh` compares them with the fork's.
- **Go** 1.26.8, the `lang/golang` of openwrt/packages (`versions.env`).
- The versions of `sing`, `sing-tun`, `nftables` and `netlink` the program requires end up shared
  with the engine (minimal version selection takes the higher one); nothing checks them.
