# Development

How this repository is laid out, how to build a package locally and what the checks are. The
series of patches is described in [PATCHES.md](PATCHES.md), the release steps in
[RELEASE.md](RELEASE.md) (in Russian).

## Layout

| Path | What |
|---|---|
| `patches/v1.14`, `patches/v1.12` | the patches to the upstream tag (`git format-patch --no-renames`); 1.13 was in the tree until r25 (removed in r26; its last release is r18) |
| `versions.env` | everything the build depends on: the lines (`LINES`), the upstream versions and sha256 of their archives, the revision of the package, the fork commit, Go, lld, the SDK releases |
| `openwrt/podkop-engine/Makefile` | the package; `BUILD_VARIANT` gives `podkop-engine` (tag `podkop_slim`) and `podkop-engine-full` (`podkop_full`) |
| `openwrt/podkop-engine/files/` | `sing-box.init` and `sing-box.conf` (from OpenWrt's `net/sing-box`), `lists-recovered` (the hook run when the lists come after a start without them), `failsafe` and `podkop-engine.init` (the failsafe service), `podkop-engine.uci-defaults` (new options after an upgrade), `config.json` (a minimal config both packages accept) |
| `openwrt/podkop-engine/naive.pkgarchs` | the pkgarchs for which sing-box publishes cronet (NaiveProxy in `podkop-engine-full`) |
| `scripts/sdk-build.sh` | the build in an OpenWrt SDK image, one or several lines |
| `scripts/gen-matrix.py` | pkgarch → SDK image, for CI |
| `scripts/check-fork.sh` | the fork commit equals the upstream tag plus the patches |
| `scripts/release.sh` | the release drafts: packages, `SHA256SUMS` and the notes from the CHANGELOG entry |
| `lab/` | the package test in OpenWrt and the REALITY stand (Xray servers and clients against sing-box) |
| `.github/workflows/build.yml` | run by hand: build → test → release drafts |
| `.github/workflows/fork.yml` | `check-fork.sh`, on a push or pull request that changes the patches, `versions.env`, `check-fork.sh` or `fork.yml`, and as the first job of `build.yml` |

The same Go is used for every build: `lang/golang` of openwrt/packages, pinned in `versions.env`
(Go 1.26.8). `.ipk` packages are built in the SDK of OpenWrt 24.10, `.apk` in the SDK of 25.12;
the `.apk` installs on snapshot too.

## Build one architecture

```sh
docker run --rm -v "$PWD:/src:ro" -v "$PWD/out:/out" \
  openwrt/sdk:x86-64-v24.10.8 sh /src/scripts/sdk-build.sh 1.14
```

NaiveProxy in `podkop-engine-full` links only with lld: the cronet objects carry CREL
relocations GNU ld does not take. For the architectures of `naive.pkgarchs` the script downloads
Chromium's clang package (about 70 MB, `LLD_URL` in `versions.env`, cached in `dl/`) and takes
lld from it. CI runs the container with `--user root` to hand the cached `dl/` to `buildbot`.

## Checks

```sh
# the package in OpenWrt with podkop, and `sing-box check` on a config built by podkop's code
# (-e PKG=podkop-engine-full for the second package)
docker run --rm -v "$PWD/out:/pkgs:ro" -v "$PWD/lab/podkop-check:/t:ro" -v "$PWD/lab:/lab:ro" \
  openwrt/rootfs:x86-64-24.10.8 sh /lab/pkg-test.sh
# the REALITY stand: Xray 24.11 … 26.9 servers × a cover site with and without ML-KEM,
# compared with what is expected
lab/fetch-bins.sh out lab/bin && lab/gate.sh lab/bin
```

`build.yml` runs both: it installs the x86_64 packages in OpenWrt 24.10, 25.12 and snapshot with
podkop and runs the stand before it makes the drafts. `lab/switch-test.sh` switches an
OpenWrt container between the two packages.

Measurements against vanilla sing-box are in [BENCHMARKS.md](BENCHMARKS.md).
