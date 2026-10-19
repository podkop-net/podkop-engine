#!/bin/sh
# Проверка пакета podkop-engine в образе OpenWrt (x86_64):
#   установка пакета -> установка podkop (зависимость sing-box закрывается PROVIDES) ->
#   `sing-box version` -> конфиг из podkop.uci кодом podkop -> `sing-box check`.
#
#   docker run --rm -v <каталог с пакетом>:/pkgs:ro -v <repo>/lab/podkop-check:/t:ro \
#     openwrt/rootfs:x86-64-24.10.8 sh /t/../pkg-test.sh        (ipk)
#     openwrt/rootfs:x86-64-25.12.5 ...                          (apk)
#
# PKG=podkop-engine-full checks the full package instead: every outbound type loads, and
# NaiveProxy on x86_64; podkop-engine must refuse those types with a message naming the
# full package.
set -eu
PKG=${PKG:-podkop-engine}
PODKOP_VERSION=${PODKOP_VERSION:-0.7.22}
REL=https://github.com/itdoginfo/podkop/releases/download/$PODKOP_VERSION
fail() { echo "FAIL: $*"; exit 1; }
# The package feed and GitHub drop a download now and then (podkop pulls a dozen packages
# from the feed): what needs the network is tried up to four times, lists updated between.
retry() {
  n=0
  until "$@"; do
    n=$((n + 1)); [ $n -lt 4 ] || return 1
    sleep 5
    if command -v apk >/dev/null 2>&1; then apk update -q >/dev/null 2>&1 || true; else opkg update >/dev/null 2>&1 || true; fi
  done
}
mkdir -p /var/lock /tmp/pk

if command -v apk >/dev/null 2>&1; then
  pkg=$(ls /pkgs/${PKG}_*.apk 2>/dev/null | head -1); [ -n "$pkg" ] || fail "no $PKG .apk in /pkgs"
  retry apk update -q || fail "apk update"
  retry apk add -q --allow-untrusted "$pkg" || fail "apk add $PKG"
  retry wget -q -O /tmp/pk/podkop.apk "$REL/podkop-$PODKOP_VERSION-r1.apk" || fail "download of podkop"
  retry apk add -q --allow-untrusted /tmp/pk/podkop.apk || fail "apk add podkop"
  apk list -I 2>/dev/null | grep -E '^(podkop|sing-box)' || true
else
  pkg=$(ls /pkgs/${PKG}_*.ipk 2>/dev/null | head -1); [ -n "$pkg" ] || fail "no $PKG .ipk in /pkgs"
  retry opkg update >/dev/null 2>&1 || fail "opkg update"
  retry opkg install "$pkg" >/tmp/pk/opkg.log 2>&1 || { cat /tmp/pk/opkg.log; fail "opkg install $PKG"; }
  retry wget -q -O /tmp/pk/podkop.ipk "$REL/podkop-v$PODKOP_VERSION-r1-all.ipk" || fail "download of podkop"
  retry opkg install /tmp/pk/podkop.ipk >/tmp/pk/opkg.log 2>&1 || { cat /tmp/pk/opkg.log; fail "opkg install podkop"; }
  opkg list-installed | grep -E '^(podkop|sing-box)' || true
fi

# the failsafe service is enabled whatever the order of installation (here: before podkop)
[ -L /etc/rc.d/S95podkop-engine ] || fail "failsafe service is not enabled"
v=$(sing-box version | head -1)
echo "$v"
echo "$v" | grep -qE -- '-pdk-r[0-9]+$' || fail "unexpected version string"
sing-box version | grep -q 'podkop_slim' || fail "podkop_slim tag missing"
sing-box api >/dev/null 2>&1 && fail "api CLI must be absent"
sing-box check -c /etc/sing-box/config.json || fail "the shipped config does not pass check"

# r11 on lines 1.13 and 1.14: the features line, and a share link with the xhttp transport
# becomes an outbound that passes check; a link that cannot be used exits with status 2
case "$v" in
*" 1.12."*) ;;
*)
  sing-box version | grep -q '^Features: .*urltest.fallbacks.*transport.xhttp.*tools.decode-link' || fail "features line missing"
  L='vless://6f1c9a0e-3b52-4c1e-9a55-2d4a1b0f7c11@203.0.113.20:443?type=xhttp&security=tls&sni=e.example.com&path=%2Fx&mode=packet-up#t'
  o=$(sing-box tools decode-link --compact "$L") || fail "decode-link"
  printf '{"outbounds": [%s]}\n' "$o" > /tmp/pk/xhttp.json
  jq -e '.outbounds[0].transport.type == "xhttp"' /tmp/pk/xhttp.json >/dev/null || fail "decode-link: no xhttp transport"
  sing-box check -c /tmp/pk/xhttp.json || fail "the decoded xhttp outbound does not pass check"
  s=0; sing-box tools decode-link --compact "$(echo "$L" | sed 's/&mode=/\&flow=xtls-rprx-vision\&mode=/')" >/tmp/pk/bad.out 2>/tmp/pk/bad.err || s=$?
  [ "$s" = 2 ] && [ ! -s /tmp/pk/bad.out ] && grep -q '^error: ' /tmp/pk/bad.err || fail "decode-link: bad link, status $s"
  echo "features, xhttp and decode-link OK"
  # r13: every kind of link the build has, each built before it is printed; the options by
  # path and what a link may not set; the switch of the liveness probe; the fingerprint
  # fallback, which has no switch here
  # (told by the name r13 added to the features line, tls.utls-fallback: the revision of
  # the package starts from 1 again with every new version of sing-box)
  if sing-box version | grep -q '^Features: .*[ ,]tls\.utls-fallback\(,\|$\)'; then
    for l in 'ss://MjAyMi1ibGFrZTMtYWVzLTI1Ni1nY206ZG1DbHkvWmgxNVd3OStzK0dGWGlGVElrcHc3Yy9xQ0lTYUJyYWk3V2hoWT0@203.0.113.20:8388#s' \
             'hysteria2://password@203.0.113.20:443,5000-6000/?sni=e.example.com&obfs=salamander&obfs-password=x#h' \
             'tuic://6f1c9a0e-3b52-4c1e-9a55-2d4a1b0f7c11:password@203.0.113.20:443?congestion_control=bbr&alpn=h3#t' \
             'socks5://user:pass@203.0.113.20:1080#k' \
             'vless://6f1c9a0e-3b52-4c1e-9a55-2d4a1b0f7c11@203.0.113.20:443?security=tls&sni=e.example.com&type=ws&sb.tls.fragment=1&sb.multiplex.enabled=1#v'; do
      o=$(echo "$l" | sing-box tools decode-link --compact 2>/tmp/pk/dl.err) || { cat /tmp/pk/dl.err; fail "decode-link: $(echo "$l" | cut -d: -f1)"; }
      printf '{"outbounds": [%s]}\n' "$o" > /tmp/pk/link.json
      sing-box check -c /tmp/pk/link.json || fail "decoded $(echo "$l" | cut -d: -f1) outbound does not pass check"
    done
    V='vmess://6f1c9a0e-3b52-4c1e-9a55-2d4a1b0f7c11@203.0.113.20:443?type=ws&security=tls&sni=e.example.com#m'
    s=0; echo "$V" | sing-box tools decode-link --compact >/tmp/pk/vm.out 2>/tmp/pk/vm.err || s=$?
    if [ "$PKG" = podkop-engine-full ]; then
      [ "$s" = 0 ] || { cat /tmp/pk/vm.err; fail "full: vmess link, status $s"; }
    else
      [ "$s" = 2 ] && [ ! -s /tmp/pk/vm.out ] && grep -q 'install podkop-engine-full' /tmp/pk/vm.err || fail "main: vmess link, status $s"
    fi
    # before the "#": what follows it is the name of the link
    s=0; echo "$V" | sed 's/^vmess/vless/; s/#/\&sb.detour=direct#/' | sing-box tools decode-link --compact >/tmp/pk/deny.out 2>/tmp/pk/deny.err || s=$?
    [ "$s" = 2 ] && [ ! -s /tmp/pk/deny.out ] && grep -q 'not for a link to set' /tmp/pk/deny.err || fail "decode-link: sb.detour, status $s"
    uci -q get sing-box.main.liveness >/dev/null || fail "/etc/config/sing-box has no option liveness"
    # the fingerprint fallback has no switch in the package: experimental.utls_fallback of
    # config.json turns it on, and nothing here sets its environment variable
    ! grep -q 'utls_fallback' /etc/config/sing-box || fail "/etc/config/sing-box has an option of the fingerprint fallback"
    ! grep -rq 'SING_BOX_UTLS_FALLBACK' /etc/init.d/sing-box /etc/init.d/podkop-engine /usr/libexec/podkop-engine || fail "the package sets the fingerprint fallback"
    # and the binary takes the option that does turn it on
    printf '{"experimental": {"utls_fallback": {"enabled": true, "fingerprints": ["safari", "firefox"]}}, "outbounds": [%s]}\n' "$o" > /tmp/pk/fb.json
    sing-box check -c /tmp/pk/fb.json || fail "experimental.utls_fallback is not accepted"
    sh -n /usr/libexec/podkop-engine/failsafe || fail "failsafe script"
    echo "r13: links of every kind, option paths, switches OK"
  fi
  # r14: a VLESS link with the encryption of Xray becomes an outbound that passes check; the
  # init script passes on only a memory limit and a download address that are safe to pass
  # (lines 1.13.21 and 1.14.2 have these from revision 14, a later sing-box from its first)
  r14=1
  case "$v" in *" 1.13.21-pdk-r"*|*" 1.14.2-pdk-r"*) [ "${v##*-pdk-r}" -ge 14 ] || r14=0 ;; esac
  if [ "$r14" = 1 ]; then
    E='vless://6f1c9a0e-3b52-4c1e-9a55-2d4a1b0f7c11@203.0.113.20:443?encryption=mlkem768x25519plus.native.0rtt.AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA&flow=xtls-rprx-vision&type=xhttp&security=tls&sni=e.example.com&path=%2Fx&mode=auto#e'
    o=$(echo "$E" | sing-box tools decode-link --compact 2>/tmp/pk/enc.err) || { cat /tmp/pk/enc.err; fail "decode-link: VLESS Encryption"; }
    printf '{"outbounds": [%s]}\n' "$o" > /tmp/pk/enc.json
    jq -e '.outbounds[0].encryption | startswith("mlkem768x25519plus.native.0rtt.")' /tmp/pk/enc.json >/dev/null || fail "decode-link: no encryption in the outbound"
    sing-box check -c /tmp/pk/enc.json || fail "the outbound with VLESS Encryption does not pass check"
    s=0; echo "$E" | sed 's/\.0rtt\./.2rtt./' | sing-box tools decode-link --compact >/tmp/pk/bad.out 2>/tmp/pk/bad.err || s=$?
    [ "$s" = 2 ] && [ ! -s /tmp/pk/bad.out ] && grep -q '^error: ' /tmp/pk/bad.err || fail "decode-link: bad encryption, status $s"
    # what start_service of the init script would give sing-box as its environment
    initenv() {
      ( set +eu
        . /lib/functions.sh
        procd_open_instance() { :; }; procd_close_instance() { :; }
        procd_set_param() { if [ "$1" = env ]; then shift; printf '%s\n' "$@"; fi; }
        logger() { echo "log: $*" >&2; }
        initscript=/etc/init.d/sing-box; . /etc/init.d/sing-box; start_service ) 2>/tmp/pk/init.log
    }
    enabled=$(uci -q get sing-box.main.enabled || echo 0)
    uci set sing-box.main.enabled=1
    for m in 64MiB 1GiB off; do
      uci set sing-box.main.memory_limit="$m"; uci commit sing-box
      initenv | grep -qx "GOMEMLIMIT=$m" || fail "memory_limit $m is not passed on"
    done
    for m in 64 0 0MiB 1B 65536KiB 1TiB 64mib ' 64MiB' 99999999999999999999GiB "junk here
64MiB"; do
      uci set sing-box.main.memory_limit="$m"; uci commit sing-box
      initenv > /tmp/pk/init.env; ! grep -q '^GOMEMLIMIT' /tmp/pk/init.env || fail "memory_limit '$m' is passed on"
      grep -q "log: .*memory_limit '$(printf '%s' "$m" | head -1)" /tmp/pk/init.log && grep -q "ignored: use off" /tmp/pk/init.log || fail "memory_limit '$m': no line in the log"
    done
    uci -q delete sing-box.main.memory_limit
    for u in 'https://example.com/a b' 'ftp://example.com/f' 'example.com/f' 'https://' "x y
https://example.com/f"; do
      uci set sing-box.main.urltest_download_url="$u"; uci commit sing-box
      initenv > /tmp/pk/init.env; ! grep -q 'SING_BOX_URLTEST_DOWNLOAD_URL\|^b$\|^y$' /tmp/pk/init.env || fail "urltest_download_url '$u' is passed on"
      grep -q "log: .*urltest_download_url '$(printf '%s' "$u" | head -1)" /tmp/pk/init.log && grep -q "ignored, no download check" /tmp/pk/init.log || fail "urltest_download_url '$u': no line in the log"
    done
    for u in 'http://example.com/f?bytes=65536' 'HTTPS://Example.com/f%20g'; do
      uci set sing-box.main.urltest_download_url="$u"; uci commit sing-box
      initenv | grep -qx "SING_BOX_URLTEST_DOWNLOAD_URL=$u" || fail "the download address $u is not passed on"
    done
    uci -q delete sing-box.main.urltest_download_url; uci set sing-box.main.enabled=0; uci commit sing-box
    initenv | grep -q . && fail "a disabled service gets an environment"
    uci set sing-box.main.enabled=1; uci commit sing-box
    initenv > /tmp/pk/init.env
    grep -qx 'SING_BOX_URLTEST_DOWNLOAD_URL=https://speed.cloudflare.com/__down?bytes=65536' /tmp/pk/init.env || fail "the default download address is not passed on"
    grep -qx 'SING_BOX_DNS_FALLBACK=ubus' /tmp/pk/init.env || fail "no DNS fallback in the environment with podkop installed"
    uci set sing-box.main.enabled="$enabled"; uci commit sing-box
    echo "r14: VLESS Encryption link, init script environment OK"
  fi
  ;;
esac

# the http outbound is in both packages since r15: a local HTTP proxy set as a raw outbound
# (opera-proxy and the like)
printf '{"outbounds": [{"tag": "x", "type": "http", "server": "127.0.0.1", "server_port": 18080}]}\n' > /tmp/pk/one.json
sing-box check -c /tmp/pk/one.json || fail "$PKG refuses the http outbound"

# the outbounds only podkop-engine-full has (raw outbound configurations in podkop)
TLS='"server": "203.0.113.20", "server_port": 443, "tls": {"enabled": true, "server_name": "e.example.com"}'
for o in '"type": "vmess", "server": "203.0.113.20", "server_port": 443, "uuid": "6f1c9a0e-3b52-4c1e-9a55-2d4a1b0f7c11"' \
         "\"type\": \"anytls\", $TLS, \"password\": \"p\"" \
         "\"type\": \"naive\", $TLS, \"username\": \"u\", \"password\": \"p\""; do
  printf '{"outbounds": [{"tag": "x", %s}]}\n' "$o" > /tmp/pk/one.json
  if [ "$PKG" = podkop-engine-full ]; then
    sing-box check -c /tmp/pk/one.json || fail "full: $o"
  else
    sing-box check -c /tmp/pk/one.json >/tmp/pk/check.log 2>&1 && fail "main accepts: $o"
    grep -q 'install podkop-engine-full' /tmp/pk/check.log || { cat /tmp/pk/check.log; fail "main: no hint for $o"; }
  fi
done
if [ "$PKG" = podkop-engine-full ]; then
  sing-box version | grep -q 'podkop_full' || fail "podkop_full tag missing"
  sing-box version | grep -q 'with_naive_outbound' || fail "NaiveProxy missing on x86_64"
else
  sing-box version | grep -q 'podkop_full' && fail "main has podkop_full"
fi
echo "$PKG: outbound types as expected"

# конфиг podkop: настоящий /usr/bin/podkop без диспетчера команд -> библиотека
cp /t/podkop.uci /etc/config/podkop
mkdir -p /etc/sing-box /tmp/sing-box
n=$(grep -n '^case "\$1" in' /usr/bin/podkop | tail -1 | cut -d: -f1)
head -n $((n-1)) /usr/bin/podkop > /tmp/pk/lib.sh
printf 'config_load "podkop"\nsing_box_init_config\n' >> /tmp/pk/lib.sh
rm -f /etc/sing-box/config.json
sh /tmp/pk/lib.sh >/tmp/pk/podkop.log 2>&1 || true
[ -s /etc/sing-box/config.json ] || { tail -5 /tmp/pk/podkop.log; fail "podkop config not generated/checked"; }
echo "podkop config OK: $(jq -r '[.outbounds[].type]|join(",")' /etc/sing-box/config.json)"
echo PASS
