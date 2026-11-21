#!/bin/bash
# Матрица совместимости: xray-core (VLESS + REALITY + Vision) <-> sing-box (клиент).
#
# Переменные окружения (списки через пробел):
#   XRAY_VERSIONS  версии xray из /lab/bin/xray-<ver>          (по умолчанию все найденные)
#   SINGBOX_BINS   имена бинарников sing-box из /lab/bin       (по умолчанию все sing-box-*);
#                  xrayc-<ver> — клиентом будет xray-<ver>
#   FINGERPRINTS   utls fingerprint клиента                    (по умолчанию chrome)
#   MIN_CLIENT_VER значение realitySettings.minClientVer; пусто = не задавать (дефолт xray)
#   KEY_SHARE      reality.key_share клиента (только sing-box-lx: hybrid|classical)
#   FINALMASK      finalmask клиента sing-box: merged (ClientHello записями по 11–24 байта, одной
#                  записью в сокет, как fm провайдеров) или s1 (то же двумя TCP-кусками, первый
#                  100–200 байт); пусто = без маски. В строках результата клиент — <имя>+fm-<маска>
#   SHOW=true      realitySettings.show (xray печатает, почему отверг клиента)
#   VERBOSE=1      печатать хвосты логов на каждом FAIL
set -u
BIN=/lab/bin
WORK=/tmp/lab
mkdir -p "$WORK"

XRAY_VERSIONS=${XRAY_VERSIONS:-$(ls $BIN | sed -n 's/^xray-//p' | sort -V)}
SINGBOX_BINS=${SINGBOX_BINS:-$(ls $BIN | grep '^sing-box-' | sort)}
FINGERPRINTS=${FINGERPRINTS:-chrome}
MIN_CLIENT_VER=${MIN_CLIENT_VER:-}
UUID=6f1c9a0e-3b52-4c1e-9a55-2d4a1b0f7c11
SNI=reality.test
SID=0123456789abcdef

[ -e /run/nginx/nginx.pid ] || nginx || { echo "nginx failed"; exit 1; }

# ключи REALITY генерирует самый свежий xray (формат вывода у 26.x одинаковый)
KEYGEN=$(ls $BIN/xray-* | sort -V | tail -1)
KEYS=$($KEYGEN x25519)
PRIV=$(echo "$KEYS" | sed -n 's/^PrivateKey: //p')
PUB=$(echo "$KEYS" | sed -n 's/^Password (PublicKey): //p')

xray_config() {
  local mcv=""
  [ -n "$MIN_CLIENT_VER" ] && mcv="\"minClientVer\": \"$MIN_CLIENT_VER\","
  cat <<EOF
{
  "log": {"loglevel": "debug"},
  "inbounds": [{
    "listen": "127.0.0.1", "port": 443, "protocol": "vless",
    "settings": {"clients": [{"id": "$UUID", "flow": "xtls-rprx-vision"}], "decryption": "none"},
    "streamSettings": {
      "network": "raw", "security": "reality",
      "realitySettings": {
        "dest": "127.0.0.1:8443", $mcv "show": ${SHOW:-false},
        "serverNames": ["$SNI"], "privateKey": "$PRIV", "shortIds": ["$SID"]
      }
    }
  }],
  "outbounds": [{"protocol": "freedom",
    "settings": {"finalRules": [{"action": "allow", "ip": ["127.0.0.0/8"]}]}}]
}
EOF
}

finalmask_json() {
  case ${FINALMASK:-} in
    merged) echo ', "finalmask": {"tcp": [{"type": "fragment", "packets": "tlshello", "length": "11-24", "delay": "0"}]}';;
    s1) echo ', "finalmask": {"tcp": [{"type": "fragment", "packets": "1-1", "length": "100-200", "max_split": "2"}, {"type": "fragment", "packets": "tlshello", "length": "11-24", "delay": "0"}]}';;
  esac
}

singbox_config() {
  cat <<EOF
{
  "log": {"level": "debug", "timestamp": false},
  "inbounds": [{"type": "mixed", "listen": "127.0.0.1", "listen_port": 1080}],
  "outbounds": [{
    "type": "vless", "tag": "proxy", "server": "127.0.0.1", "server_port": 443,
    "uuid": "$UUID", "flow": "xtls-rprx-vision",
    "tls": {
      "enabled": true, "server_name": "$SNI",
      "utls": {"enabled": true, "fingerprint": "$1"},
      "reality": {"enabled": true, "public_key": "$PUB", "short_id": "$SID"${KEY_SHARE:+, \"key_share\": \"$KEY_SHARE\"}}
    }$(finalmask_json)
  }]
}
EOF
}

# xray в роли клиента: элемент SINGBOX_BINS вида xrayc-<версия>
xray_client_config() {
  cat <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{"listen": "127.0.0.1", "port": 1080, "protocol": "socks", "settings": {"udp": false}}],
  "outbounds": [{
    "protocol": "vless",
    "settings": {"vnext": [{"address": "127.0.0.1", "port": 443,
      "users": [{"id": "$UUID", "flow": "xtls-rprx-vision", "encryption": "none"}]}]},
    "streamSettings": {"network": "raw", "security": "reality",
      "realitySettings": {"serverName": "$SNI", "fingerprint": "$1", "password": "$PUB", "shortId": "$SID"}}
  }]
}
EOF
}

wait_port() { for _ in $(seq 50); do [ -n "$(netstat -ltn 2>/dev/null | grep ":$1 ")" ] && return 0; sleep 0.1; done; return 1; }

printf '%-10s %-28s %-11s %-6s %s\n' XRAY SING-BOX FP RESULT DETAIL
pass=0; fail=0
for xv in $XRAY_VERSIONS; do
  xray_config > $WORK/xray.json
  for sb in $SINGBOX_BINS; do
    for fp in $FINGERPRINTS; do
      case $sb in
        xrayc-*) xray_client_config "$fp" > $WORK/sb.json; CLIENT="$BIN/xray-${sb#xrayc-} run -c $WORK/sb.json";;
        *)       singbox_config "$fp" > $WORK/sb.json;       CLIENT="$BIN/$sb run -c $WORK/sb.json";;
      esac
      $BIN/xray-$xv run -c $WORK/xray.json > $WORK/xray.log 2>&1 & XP=$!
      wait_port 443
      $CLIENT > $WORK/sb.raw 2>&1 & SP=$!
      wait_port 1080
      body=$(curl -s --max-time 8 -x socks5h://127.0.0.1:1080 http://127.0.0.1:8080/ 2>/dev/null)
      sed 's/\x1b\[[0-9;]*m//g' $WORK/sb.raw > $WORK/sb.log
      if [ "$body" = "HELLO-THROUGH-TUNNEL" ]; then
        res=PASS; detail="tunnel ok"; pass=$((pass+1))
      else
        res=FAIL; fail=$((fail+1))
        # сервер не признал клиента -> отдал handshake decoy-сайта (у нас самоподписанный,
        # поэтому x509; с реальным сайтом-донором sing-box пишет "reality verification failed")
        if grep -q 'certificate signed by unknown authority\|reality verification failed' $WORK/sb.log; then
          detail="REJECTED by server (decoy handshake)"
        else
          detail=$(grep -iE 'error|FATAL' $WORK/sb.log | tail -1 | sed 's/.*: //' | cut -c1-90)
        fi
        srv=$(grep -oE 'REALITY: processed invalid connection.*' $WORK/xray.log | grep -v 'failed to read client hello' | tail -1 | sed 's/.*: //')
        [ -n "$srv" ] && detail="$detail | xray: $srv"
      fi
      label=$sb
      case $sb in xrayc-*) ;; *) [ -n "${FINALMASK:-}" ] && label="$sb+fm-$FINALMASK";; esac
      printf '%-10s %-28s %-11s %-6s %s\n' "$xv" "$label" "$fp" "$res" "$detail"
      if [ "$res" = FAIL ] && [ "${VERBOSE:-0}" = 1 ]; then
        echo "  --- xray.log (REALITY):"; grep -i reality $WORK/xray.log | tail -3 | sed 's/^/  /'
        echo "  --- sb.log:"; grep -iE 'error|reality' $WORK/sb.log | tail -3 | sed 's/^/  /'
      fi
      kill $SP $XP 2>/dev/null; wait $SP $XP 2>/dev/null
    done
  done
done
echo "TOTAL: pass=$pass fail=$fail"
