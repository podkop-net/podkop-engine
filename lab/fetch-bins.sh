#!/bin/sh
# Бинарники для стенда: xray-core нескольких версий (сервер и эталонный клиент) и sing-box
# из собранных x86_64-ipk podkop-engine.
#   lab/fetch-bins.sh <каталог с .ipk> <lab/bin>
set -eu
PKGS=$(cd "${1:?dir with podkop-engine_*_openwrt_x86_64.ipk}" && pwd)
mkdir -p "${2:?output dir}"; BIN=$(cd "$2" && pwd)
# 24.11.21 и 25.4.30 — до поддержки MLKEM в REALITY (25.5.16), 26.7.28 — minClientVer по умолчанию,
# 26.9.9 — требует MLKEM, 26.11.9 — свежий на r28 (REALITY 4bb46b2); XRAY_EXTRA — добавить
# свежие версии без правки скрипта.
XRAY_VERSIONS=${XRAY_VERSIONS:-"24.11.21 25.4.30 25.5.16 25.10.15 26.7.28 26.9.9 26.11.9 $(printf '%s' "${XRAY_EXTRA:-}")"}
tmp=$(mktemp -d)
for v in $XRAY_VERSIONS; do
  [ -x "$BIN/xray-$v" ] && continue
  curl -fsSL -o "$tmp/x.zip" "https://github.com/XTLS/Xray-core/releases/download/v$v/Xray-linux-64.zip"
  unzip -o -q "$tmp/x.zip" xray -d "$tmp" && mv "$tmp/xray" "$BIN/xray-$v"
done
found=0
for ipk in "$PKGS"/podkop-engine_*_openwrt_x86_64.ipk; do
  [ -f "$ipk" ] || continue; found=$((found+1))
  v=$(basename "$ipk" | sed 's/^podkop-engine_\([^_]*\)_.*/\1/')
  rm -rf "$tmp/p" && mkdir -p "$tmp/p" && cd "$tmp/p"
  tar xzf "$ipk" 2>/dev/null || gzip -dc "$ipk" | tar x
  tar xzf data.tar.gz ./usr/bin/sing-box
  cp usr/bin/sing-box "$BIN/sing-box-podkop-engine-$v"
  cd - >/dev/null
done
rm -rf "$tmp"
[ "$found" -gt 0 ] || { echo "no podkop-engine_*_openwrt_x86_64.ipk in $PKGS" >&2; exit 1; }
ls -l "$BIN"
