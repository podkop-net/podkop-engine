#!/bin/sh
# Черновики релизов GitHub: по одному на ветку sing-box (тег v<версия>-r<N>), в каждом —
# .ipk и .apk всех архитектур, SHA256SUMS и описание. Существующий релиз не перезаписывается:
# опубликованные файлы не должны меняться, для пересборки поднимите SB_<ветка>_RELEASE.
#   GH_REPO=owner/repo scripts/release.sh <каталог с пакетами> [ветки...]
#   DRY_RUN=1 — ничего не создавать, показать описание и список файлов.
# Последняя ветка из LINES помечается как Latest.
set -eu
DIST=${1:?dir with packages}; shift
. ./versions.env
[ $# -gt 0 ] || set -- $LINES
newest=$(echo $LINES | tr ' ' '\n' | sort -V | tail -1)
repo=${GH_REPO:?GH_REPO=owner/repo}

for LINE in "$@"; do
  key=$(echo "$LINE" | tr . _)
  v=; r=; eval "v=\${SB_${key}_VERSION}; r=\${SB_${key}_RELEASE}"
  tag="v$v-r$r"
  if [ -z "${DRY_RUN:-}" ] && gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
    echo "release $tag already exists: bump SB_${key}_RELEASE in versions.env to publish a rebuild" >&2
    exit 1
  fi
  dir=$(mktemp -d)
  cp "$DIST"/podkop-engine_"$v"-r"$r"_openwrt_*.ipk "$DIST"/podkop-engine_"$v"-r"$r"_openwrt_*.apk "$dir"/
  # podkop-engine-full: from the lines whose patches have the tag podkop_full
  cp "$DIST"/podkop-engine-full_"$v"-r"$r"_openwrt_*.[ai]pk "$dir"/ 2>/dev/null || true
  (cd "$dir" && sha256sum -- *.ipk *.apk > SHA256SUMS)
  n_ipk=$(ls "$dir"/podkop-engine_*.ipk | wc -l); n_apk=$(ls "$dir"/podkop-engine_*.apk | wc -l)
  n_full=$(ls "$dir"/podkop-engine-full_*.[ai]pk 2>/dev/null | wc -l)
  # NaiveProxy in podkop-engine-full: the pkgarchs of naive.pkgarchs (sdk-build.sh fails a
  # build where it is listed but missing), every other one of this release has none
  full_arches=$(ls "$dir"/podkop-engine-full_*.[ai]pk 2>/dev/null | sed 's/.*_openwrt_\(.*\)\.[ai]pk$/\1/' | sort -u)
  # an if, not "grep && printf": the status of a loop is that of its last command, and an
  # arch missing from the list as the last one ended the script under "set -e" with no message
  [ -r openwrt/podkop-engine/naive.pkgarchs ] || { echo "openwrt/podkop-engine/naive.pkgarchs is missing" >&2; exit 1; }
  naive_yes=$(for a in $full_arches; do if grep -qx "$a" openwrt/podkop-engine/naive.pkgarchs; then printf '`%s` ' "$a"; fi; done)
  naive_no=$(for a in $full_arches; do if ! grep -qx "$a" openwrt/podkop-engine/naive.pkgarchs; then printf '`%s` ' "$a"; fi; done)
  arches=$(ls "$dir"/podkop-engine_*.ipk "$dir"/podkop-engine_*.apk | sed 's/.*_openwrt_\(.*\)\.[ai]pk$/\1/' | sort -u | tr '\n' ' ')
  patches=$(for pf in "patches/v$LINE"/*.patch; do printf -- '- `%s` %s\n' "$(basename "$pf" | cut -c1-4)" "$(awk '/^Subject: /{s=$0; while ((getline l) > 0 && l ~ /^ /) s = s l; sub(/^Subject: \[PATCH[^]]*\] /, "", s); print s; exit}' "$pf")"; done)
  f=podkop-engine_${v}-r${r}_openwrt
  cat > "$dir/NOTES.md" <<EOF
sing-box **$v** для podkop на OpenWrt, ревизия пакета **r$r**. Неофициальная сборка, не связана с проектом sing-box.

Патчи к \`v$v\`:
$patches

Теги сборки: \`with_quic,with_utls,with_clash_api,podkop_slim\`. Go $GO_VERSION. \`sing-box version\` → \`$v-pdk-r$r\`.
$(if [ "$n_full" -gt 0 ]; then cat <<FULL

**Два пакета, ставится один из них:**
- \`podkop-engine\` — то, что использует podkop: входы tproxy, direct, mixed; выходы direct, socks, shadowsocks, trojan, vless, hysteria2, tuic, selector, urltest, http$( [ "$LINE" = 1.14 ] && printf ', block'). Остальные типы в «Outbound Config» отвергаются с подсказкой поставить \`podkop-engine-full\`.
- \`podkop-engine-full\` — то же плюс все остальные выходы: vmess, snell (1.14), tor (нужен пакет tor), ssh, shadowtls, anytls, hysteria и NaiveProxy (кроме архитектур ниже). Теги — те же плюс \`podkop_full\` (и \`with_naive_outbound,with_musl\`, где есть NaiveProxy).

**NaiveProxy в \`podkop-engine-full\` есть не на всех архитектурах.** Он работает на cronet (сетевом стеке Chromium), который sing-box выпускает не для всех процессоров; бинарь с NaiveProxy больше на 11 МБ (x86_64) — 17 МБ (mipsel).
- есть: $naive_yes
- **нет:** $naive_no

Причины: mips big-endian и mips64 (cronet для них нет), armv5/armv6 и arm без FPU (cronet собран под ARMv7 с VFP), \`mipsel_24kc_24kf\` (плавающая точка в железе, cronet — soft-float), \`mipsel_mips32\` (cronet собран под MIPS32r2), \`i386_pentium-mmx\` (нет SSE2), \`riscv64_riscv64\` (sing-box выпускает cronet только для \`riscv64_generic\`). На этих архитектурах остальные протоколы \`podkop-engine-full\` работают, а выход naive отвечает \`naive outbound is not included in this build\`.
FULL
fi)

**Установка** (\`<pkgarch>\` — \`opkg print-architecture\` / \`apk --print-arch\`; подробнее — [docs/INSTALL.md](https://github.com/$repo/blob/main/docs/INSTALL.md)):

OpenWrt 24.10 и старше (opkg):
\`\`\`sh
# podkop-engine-full: то же с именем файла podkop-engine-full_${v}-r${r}_openwrt_<pkgarch>.ipk
n=${f}_<pkgarch>.ipk; u=\$(wget -qO- https://api.github.com/repos/$repo/releases/tags/$tag | jsonfilter -e "@.assets[@.name='\$n'].url") && wget -O /tmp/pe.ipk --header='Accept: application/octet-stream' "\$u" && { opkg remove --force-depends sing-box sing-box-tiny 2>/dev/null; opkg install /tmp/pe.ipk; }
\`\`\`
OpenWrt 25.12 и snapshot (apk):
\`\`\`sh
# podkop-engine-full: то же с именем файла podkop-engine-full_${v}-r${r}_openwrt_<pkgarch>.apk
n=${f}_<pkgarch>.apk; u=\$(wget -qO- https://api.github.com/repos/$repo/releases/tags/$tag | jsonfilter -e "@.assets[@.name='\$n'].url") && wget -O /tmp/pe.apk --header='Accept: application/octet-stream' "\$u" && apk add --allow-untrusted /tmp/pe.apk
\`\`\`

Файл берётся через API GitHub: wget в OpenWrt (uclient-fetch) не дочитывает ответ github.com на прямую ссылку скачивания (строка заголовка 9 КБ при его пределе 4 КБ) и висит до таймаута.

Архитектуры ($n_ipk ipk, $n_apk apk): $arches

Совместимость: как Xray-клиент 26.9.9 (Xray-сервер 25.5.16+; с 24.x–25.4 — только если сайт-прикрытие не выбирает X25519MLKEM768).
EOF
  latest=--latest=false; [ "$LINE" = "$newest" ] && latest=--latest
  if [ -n "${DRY_RUN:-}" ]; then
    echo "### DRY_RUN: $tag $latest"; cat "$dir/NOTES.md"; ls "$dir"; rm -rf "$dir"; continue
  fi
  # the tag is made when the draft is published: from this commit, not from whatever the
  # default branch has by then
  gh release create "$tag" -R "$repo" --draft $latest --target "${GITHUB_SHA:-$(git rev-parse HEAD)}" --title "podkop-engine $v-r$r" \
    --notes-file "$dir/NOTES.md" "$dir"/*.ipk "$dir"/*.apk "$dir/SHA256SUMS"
  echo "draft $tag: $n_ipk ipk + $n_apk apk, podkop-engine-full: $n_full"
  rm -rf "$dir"
done
