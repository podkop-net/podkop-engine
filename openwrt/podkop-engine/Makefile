# podkop-engine: sing-box с патчами для podkop (REALITY под Xray-core 26.9+,
# отпечатки firefox/safari как у Xray, сборка без api/snell).
# Основан на net/sing-box из openwrt/packages (GPL-2.0). version.mk и patches/
# кладёт сюда scripts/sdk-build.sh для выбранной ветки sing-box.

# Отличия от net/sing-box: нет +kmod-tun (TUN podkop не использует, у него tproxy,
# а kmod-nft-tproxy тянет сам podkop) и +kmod-inet-diag (нужен только find_process).

# Two packages from one source (BUILD_VARIANT): podkop-engine keeps podkop's protocols
# (tag podkop_slim), podkop-engine-full adds every other outbound (podkop_full) and, where
# sing-box publishes cronet for the architecture (naive.pkgarchs), NaiveProxy.

include $(TOPDIR)/rules.mk
include $(CURDIR)/version.mk

PKG_NAME:=podkop-engine
PKG_VERSION:=$(SB_VERSION)
PKG_RELEASE:=$(SB_RELEASE)

PKG_SOURCE:=sing-box-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/SagerNet/sing-box/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=$(SB_HASH)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(if $(BUILD_VARIANT),$(PKG_NAME)-$(BUILD_VARIANT)/)sing-box-$(PKG_VERSION)

PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=podkop-engine

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/sagernet/sing-box
GO_PKG_BUILD_PKG:=$(GO_PKG)/cmd/sing-box
GO_PKG_TAGS:=with_quic,with_utls,with_clash_api,podkop_slim,badlinkname,tfogo_checklinkname0
GO_PKG_LDFLAGS:=-checklinkname=0
GO_PKG_LDFLAGS_X:=$(GO_PKG)/constant.Version=$(PKG_VERSION)-pdk-r$(PKG_RELEASE)

# NaiveProxy links the static libcronet.a of cronet-go, whose objects carry CREL
# relocations: GNU ld cannot link them, lld of LLVM 19+ can. Without it (PODKOP_ENGINE_LLD,
# or /usr/lib/llvm-<19+>/bin/ld.lld) the full package is built without NaiveProxy.
NAIVE_PKGARCHS:=$(shell cat $(CURDIR)/naive.pkgarchs)
PODKOP_ENGINE_LLD?=$(lastword $(sort $(wildcard /usr/lib/llvm-19/bin/ld.lld /usr/lib/llvm-[2-9][0-9]/bin/ld.lld)))
NAIVE:=$(if $(and $(filter full,$(BUILD_VARIANT)),$(filter $(ARCH_PACKAGES),$(NAIVE_PKGARCHS)),$(PODKOP_ENGINE_LLD)),1)

ifeq ($(BUILD_VARIANT),full)
  GO_PKG_TAGS:=$(GO_PKG_TAGS),podkop_full
endif
ifeq ($(NAIVE),1)
  GO_PKG_TAGS:=$(GO_PKG_TAGS),with_naive_outbound,with_musl
  # the last -fuse-ld wins over OpenWrt's -fuse-ld=bfd; -B lets gcc find ld.lld there.
  # Debug sections are dropped on input (the package strips them anyway): on MIPS the Go
  # linker marks .debug_* PROGBITS and gcc/clang SHT_MIPS_DWARF, which lld will not merge.
  TARGET_LDFLAGS+=-fuse-ld=lld -B$(dir $(PODKOP_ENGINE_LLD)) -Wl,--strip-debug
endif

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/podkop-engine/Default
  SECTION:=net
  CATEGORY:=Network
  URL:=https://github.com/SagerNet/sing-box
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
  USERID:=sing-box=5566:sing-box=5566
  PROVIDES:=sing-box
endef

define Package/podkop-engine
  $(call Package/podkop-engine/Default)
  TITLE:=sing-box for podkop (REALITY for Xray-core 26.9+, podkop's protocols)
  VARIANT:=main
  CONFLICTS:=sing-box sing-box-tiny
endef

define Package/podkop-engine-full
  $(call Package/podkop-engine/Default)
  TITLE:=sing-box for podkop (REALITY for Xray-core 26.9+, every outbound)
  VARIANT:=full
  # one way only: both ways make a recursive dependency in Kconfig; apk treats a conflict as
  # mutual, and opkg will not put a second /usr/bin/sing-box over the first anyway
  CONFLICTS:=sing-box sing-box-tiny podkop-engine
endef

define Package/podkop-engine/description
  Unofficial build of sing-box for podkop, not affiliated with the sing-box project.
  Patched REALITY client (X25519MLKEM768 key share, Xray-core 26.9+ servers),
  Firefox 148 / Safari 26.3 uTLS fingerprints. Only what podkop uses: inbounds
  tproxy, direct and mixed; outbounds direct, socks, shadowsocks, trojan, vless,
  hysteria2, tuic, selector and urltest, and http for a local HTTP proxy.
  Other outbounds: podkop-engine-full.
  Build tags: with_quic,with_utls,with_clash_api,podkop_slim.
endef

define Package/podkop-engine-full/description
  Unofficial build of sing-box for podkop, not affiliated with the sing-box project.
  As podkop-engine, plus every other outbound for raw outbound configurations:
  vmess, snell (1.14), tor, ssh, shadowtls, anytls, hysteria and NaiveProxy
  (x86_64, i386_pentium4, aarch64, armv7 with VFP, mipsel_24kc/74kc, riscv64, loongarch64).
  Build tags: with_quic,with_utls,with_clash_api,podkop_slim,podkop_full
  (+ with_naive_outbound,with_musl where NaiveProxy is built).
endef

define Package/podkop-engine/conffiles
/etc/config/sing-box
/etc/sing-box/
endef

Package/podkop-engine-full/conffiles=$(Package/podkop-engine/conffiles)

# CLI `sing-box api ...` (gRPC-клиент, ~5 МБ) podkop не нужен: убираем по маске,
# чтобы новые файлы upstream уходили тоже. Регистрацию api/snell снимает тег podkop_slim.
# From r15 the mask matches nothing on any line: 1.12 and 1.13 have no api command, and on
# 1.14 its files are in cmd/sing-box/cli behind the build constraint !podkop_slim. It stays
# for an upstream that puts them back in cmd/sing-box.
define Build/Prepare
	$(call Build/Prepare/Default)
	$(RM) $(PKG_BUILD_DIR)/cmd/sing-box/cmd_api*.go
endef

# The stock config of sing-box (a shadowsocks server) needs an inbound neither package
# has; podkop writes its own config anyway.
define Package/podkop-engine/install
	$(INSTALL_DIR) $(1)/usr/bin/
	$(INSTALL_BIN) $(GO_PKG_BUILD_BIN_DIR)/sing-box $(1)/usr/bin/sing-box

	$(INSTALL_DIR) $(1)/etc/sing-box
	$(INSTALL_DATA) ./files/config.json $(1)/etc/sing-box/config.json

	$(INSTALL_DIR) $(1)/etc/config/
	$(INSTALL_CONF) ./files/sing-box.conf $(1)/etc/config/sing-box
	$(INSTALL_DIR) $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/sing-box.init $(1)/etc/init.d/sing-box
	$(INSTALL_BIN) ./files/podkop-engine.init $(1)/etc/init.d/podkop-engine
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/podkop-engine.uci-defaults $(1)/etc/uci-defaults/99-podkop-engine
	$(INSTALL_DIR) $(1)/usr/libexec/podkop-engine
	$(INSTALL_BIN) ./files/lists-recovered $(1)/usr/libexec/podkop-engine/lists-recovered
	$(INSTALL_BIN) ./files/failsafe $(1)/usr/libexec/podkop-engine/failsafe
endef

Package/podkop-engine-full/install=$(Package/podkop-engine/install)

$(eval $(call BuildPackage,podkop-engine))
$(eval $(call BuildPackage,podkop-engine-full))
