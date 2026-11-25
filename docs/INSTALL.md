# Install

[Русский](INSTALL.ru.md)

The package installs `/usr/bin/sing-box`, `/etc/init.d/sing-box` and `/etc/config/sing-box`, the
same paths as OpenWrt's `sing-box` package. So it conflicts with that package and replaces it.
It also installs the failsafe service `/etc/init.d/podkop-engine`.

- [Choose the file](#choose-the-file)
- [OpenWrt 24.10 and older (opkg)](#openwrt-2410-and-older-opkg)
- [OpenWrt 25.12 and snapshot (apk)](#openwrt-2512-and-snapshot-apk)
- [Switch between podkop-engine and podkop-engine-full](#switch-between-podkop-engine-and-podkop-engine-full)
- [Upgrade](#upgrade)
- [Back to OpenWrt's sing-box](#back-to-openwrts-sing-box)
- [Failsafe service](#failsafe-service)
- [NaiveProxy](#naiveproxy)

## Choose the file

Files are in the [releases](https://github.com/podkop-net/podkop-engine/releases), named
`podkop-engine_<version>_openwrt_<pkgarch>.ipk` (or `.apk`), for example
`podkop-engine_1.14.4-r29_openwrt_aarch64_cortex-a53.ipk`.

- `<pkgarch>` is what `opkg print-architecture` or `apk --print-arch` prints on the router.
- `podkop-engine` has what podkop uses. Take `podkop-engine-full` only if your "Outbound Config"
  needs another protocol (vmess, snell, tor, ssh, shadowtls, anytls, hysteria, naive). Both are
  installed the same way; only the file name differs.
- For podkop 0.7.24, take 1.14.4-r26 or newer. The 1.13 line is no longer built.

Download the file on the router through the GitHub API. OpenWrt's `wget` (uclient-fetch) hangs
on a direct download link of github.com: the header line is 9 KB, more than it reads. The
release notes have this command with the names filled in:

```sh
tag=v1.14.4-r29; n=podkop-engine_1.14.4-r29_openwrt_<pkgarch>.ipk
u=$(wget -qO- https://api.github.com/repos/podkop-net/podkop-engine/releases/tags/$tag | jsonfilter -e "@.assets[@.name='$n'].url") \
  && wget -O /tmp/pe.ipk --header='Accept: application/octet-stream' "$u"
```

For apk, put the `.apk` file name in `n` and write `/tmp/pe.apk`.

## OpenWrt 24.10 and older (opkg)

```sh
opkg update
# when OpenWrt's sing-box is installed (podkop depends on it, hence --force-depends):
opkg remove --force-depends sing-box sing-box-tiny 2>/dev/null
opkg install /tmp/pe.ipk
service podkop restart
```

Without the removal opkg refuses: `The following packages conflict with podkop-engine: sing-box`.
After the replacement, `opkg upgrade` does not offer OpenWrt's sing-box back.

## OpenWrt 25.12 and snapshot (apk)

```sh
apk update
apk add --allow-untrusted /tmp/pe.apk
service podkop restart
```

apk replaces the installed `sing-box` in one transaction. `--allow-untrusted` is needed while the
packages are not signed. apk pins this package in `/etc/apk/world`, so `apk upgrade` does not
bring OpenWrt's sing-box back.

apk does not overwrite a file in `/etc` that was edited or belongs to no package. It keeps such a
file and puts the package's one beside it as `.apk-new`. A foreign `/etc/init.d/sing-box` (left
by an engine installed by hand, or by an edited script) would run sing-box without the DNS
fallback, the urltest download check and the limit of 65536 descriptors. Since r14 the package
puts its own script in place by itself, keeps the old one as
`/etc/sing-box/sing-box.init.before-podkop-engine` and logs a line about it.

## Switch between podkop-engine and podkop-engine-full

Download the other package as above (`n=podkop-engine-full_…`), then:

```sh
# opkg
opkg remove --force-depends podkop-engine && opkg install /tmp/pe.ipk
# apk
apk add --allow-untrusted /tmp/pe.apk '!podkop-engine'
service podkop restart
```

Back: the same with the names swapped. `/etc/config/sing-box` is kept.

## Upgrade

Download the newer file and install it the same way (`opkg install /tmp/pe.ipk`, or
`apk add --allow-untrusted /tmp/pe.apk`).
`/etc/config/sing-box` is kept; options that a new release adds get their defaults.

Check what runs:

```sh
sing-box version   # sing-box version 1.14.4-pdk-r29 … Tags: with_quic,with_utls,with_clash_api,podkop_slim …
```

## Back to OpenWrt's sing-box

```sh
# opkg: stop podkop and download the package first, remove after
service podkop stop && opkg update && cd /tmp && opkg download sing-box && opkg remove --force-depends podkop-engine && opkg install /tmp/sing-box_*.ipk; service podkop start
# apk: one transaction
apk add sing-box '!podkop-engine'
```

With opkg the order matters. While podkop runs, every DNS query of the router goes to sing-box:
removing podkop-engine first leaves the router without DNS, so it cannot download the package.
If that happened, `service podkop stop` gives the DNS back. `apk del podkop-engine` alone does not
work, because podkop depends on it. With `podkop-engine-full` installed, use that name in these
commands.

## Failsafe service

`/etc/init.d/podkop-engine` watches sing-box. procd restarts a sing-box that crashed. When
sing-box crashes again and again, procd gives up and dnsmasq would be left sending every query to
nothing; at that moment the service stops podkop, so the router gets its DNS back and works without
the proxy. The service also asks sing-box a DNS question every 20 s; a sing-box that is running
but stopped answering is ended and counts as a crash. The reason and the memory of the router are
logged and written to `/etc/sing-box/failsafe.last`. Start podkop again with `service podkop start`
once the cause is fixed. Details and the options: [FEATURES.md](FEATURES.md#failsafe-and-liveness-probe).

## NaiveProxy

NaiveProxy (the `naive` outbound of `podkop-engine-full`) is built on cronet, Chromium's network
stack, which sing-box publishes for some architectures only. It makes the binary 11 MB (x86_64) to
17 MB (mipsel) larger.

- **With NaiveProxy:** `aarch64_cortex-a53` `aarch64_cortex-a72` `aarch64_cortex-a76`
  `aarch64_generic` `arm_cortex-a15_neon-vfpv4` `arm_cortex-a5_vfpv4` `arm_cortex-a7_neon-vfpv4`
  `arm_cortex-a7_vfpv4` `arm_cortex-a8_vfpv3` `arm_cortex-a9_neon` `arm_cortex-a9_vfpv3-d16`
  `i386_pentium4` `loongarch64_generic` `mipsel_24kc` `mipsel_74kc` `riscv64_generic` `x86_64`
- **Without:** `arm_arm1176jzf-s_vfp` `arm_arm926ej-s` `arm_cortex-a7` `arm_cortex-a9`
  `arm_fa526` `arm_xscale` `i386_pentium-mmx` `mips64_mips64r2` `mips64_octeonplus`
  `mips64el_mips64r2` `mips_24kc` `mips_4kec` `mips_mips32` `mipsel_24kc_24kf` `mipsel_mips32`
  `riscv64_riscv64`

Why not: there is no cronet for big-endian MIPS and MIPS64; cronet is built for ARMv7 with VFP
(not ARMv5/v6 or ARM without an FPU), with soft float (not `mipsel_24kc_24kf`), for MIPS32r2 (not
`mipsel_mips32`), with SSE2 (not `i386_pentium-mmx`), and for `riscv64_generic` only. On these
architectures the other protocols of `podkop-engine-full` work, and the `naive` outbound answers
`naive outbound is not included in this build`.
