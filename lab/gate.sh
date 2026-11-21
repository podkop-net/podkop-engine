#!/bin/sh
# Гейт выпуска: стенд REALITY на двух вариантах сайта-прикрытия и сверка с ожиданием.
#   lab/gate.sh [lab/bin]
# Ожидание для sing-box-podkop-engine-* и xray-клиента: PASS везде, кроме сервера
# xray ≤ 25.4.30 при dest с X25519MLKEM768 (REALITY без MLKEM; так же ведёт себя xray 26.9.9).
# Второй проход (с r28): клиенты sing-box-podkop-engine-* с finalmask s1 (ClientHello записями,
# двумя TCP-кусками, как лечит podkop «нет TLS»): ожидание то же — сервер REALITY разрезанный
# hello принимает.
set -u
LAB=$(cd "$(dirname "$0")" && pwd)
BIN=$(cd "${1:-$LAB/bin}" && pwd)
FPS=${FINGERPRINTS:-"chrome firefox safari"}
clients=$(cd "$BIN" && ls sing-box-podkop-engine-* 2>/dev/null | tr '\n' ' ')
[ -n "$clients" ] || { echo "GATE: no sing-box-podkop-engine-* in $BIN"; exit 1; }
newest_xray=$(cd "$BIN" && ls xray-* | sed 's/^xray-//' | sort -V | tail -1)

docker build -q -t pe-lab -f "$LAB/Dockerfile" "$LAB" >/dev/null
docker build -q -t pe-lab-bookworm -f "$LAB/Dockerfile.bookworm" "$LAB" >/dev/null

bad=0; rows=0
for pass in plain s1; do
for img in pe-lab pe-lab-bookworm; do
  if [ $pass = plain ]; then
    echo "##### dest: $img"
    docker run --rm -v "$BIN:/lab/bin:ro" -e SINGBOX_BINS="$clients xrayc-$newest_xray" -e FINGERPRINTS="$FPS" "$img" > /tmp/gate-$img.txt
  else
    echo "##### dest: $img, finalmask $pass"
    docker run --rm -v "$BIN:/lab/bin:ro" -e SINGBOX_BINS="$clients" -e FINGERPRINTS="$FPS" -e FINALMASK=$pass "$img" > /tmp/gate-$img.txt
  fi
  cat /tmp/gate-$img.txt
  while read -r xv client fp res _; do
    case $res in PASS|FAIL) ;; *) continue;; esac
    rows=$((rows+1)); expect=PASS
    if [ "$img" = pe-lab ]; then
      case $xv in 24.*|25.[0-4].*) expect=FAIL;; esac
    fi
    if [ "$res" != "$expect" ]; then
      echo "MISMATCH: dest=$img xray=$xv client=$client fp=$fp got=$res expected=$expect"; bad=$((bad+1))
    fi
  done < /tmp/gate-$img.txt
done
done
[ $rows -gt 0 ] || { echo "GATE: no results"; exit 1; }
[ $bad -eq 0 ] && echo "GATE: OK ($rows checks)" || { echo "GATE: $bad mismatch(es)"; exit 1; }
