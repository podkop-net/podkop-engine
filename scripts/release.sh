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
  arches=$(ls "$dir"/podkop-engine_*.ipk "$dir"/podkop-engine_*.apk | sed 's/.*_openwrt_\(.*\)\.[ai]pk$/\1/' | sort -u | tr '\n' ' ')
  f=podkop-engine_${v}-r${r}_openwrt
  # what is new: the entry "## r<N> — <date>" of CHANGELOG.ru.md and CHANGELOG.md, up to the next
  # entry; a release without both entries is not made
  entry() { awk -v h="## r$r" '$0 == h || index($0, h " ") == 1 { on = 1; next } on && /^## / { exit } on' "$1" | sed '/./,$!d'; }
  new_ru=$(entry CHANGELOG.ru.md); new_en=$(entry CHANGELOG.md)
  if [ -z "$new_ru" ] || [ -z "$new_en" ]; then
    echo "CHANGELOG.md and CHANGELOG.ru.md need the entry \"## r$r — <date>\" before the release" >&2
    exit 1
  fi
  blob=https://github.com/$repo/blob/$tag
  opkg_cmd="n=${f}_<pkgarch>.ipk; u=\$(wget -qO- https://api.github.com/repos/$repo/releases/tags/$tag | jsonfilter -e \"@.assets[@.name='\$n'].url\") && wget -O /tmp/pe.ipk --header='Accept: application/octet-stream' \"\$u\" && { opkg remove --force-depends sing-box sing-box-tiny 2>/dev/null; opkg install /tmp/pe.ipk; }"
  apk_cmd="n=${f}_<pkgarch>.apk; u=\$(wget -qO- https://api.github.com/repos/$repo/releases/tags/$tag | jsonfilter -e \"@.assets[@.name='\$n'].url\") && wget -O /tmp/pe.apk --header='Accept: application/octet-stream' \"\$u\" && apk add --allow-untrusted /tmp/pe.apk"
  full_ru=; full_en=
  if [ "$n_full" -gt 0 ]; then
    full_ru="; \`podkop-engine-full\` — плюс остальные выходы для «Outbound Config» и NaiveProxy (не на всех архитектурах: [INSTALL.ru.md](${blob}/docs/INSTALL.ru.md#naiveproxy))"
    full_en="; \`podkop-engine-full\` adds every other outbound for \"Outbound Config\" and NaiveProxy (not on every architecture: [INSTALL.md](${blob}/docs/INSTALL.md#naiveproxy))"
  fi
  cat > "$dir/NOTES.md" <<EOF
**Что нового в r$r**

$new_ru

sing-box **$v** для podkop на OpenWrt, ревизия **r$r**: неофициальная сборка, не связана с проектом sing-box. Go $GO_VERSION, \`sing-box version\` → \`$v-pdk-r$r\`. Все изменения — [CHANGELOG.ru.md](${blob}/CHANGELOG.ru.md), патчи — [PATCHES.md](${blob}/docs/PATCHES.md).

**Пакеты** (ставится один): \`podkop-engine\` — то, что использует podkop${full_ru}.

**Установка** (\`<pkgarch>\` — \`opkg print-architecture\` / \`apk --print-arch\`; подробнее — [INSTALL.ru.md](${blob}/docs/INSTALL.ru.md)). Для \`podkop-engine-full\` замените имя файла.
\`\`\`sh
# OpenWrt 24.10 и старше (opkg)
$opkg_cmd
# OpenWrt 25.12 и snapshot (apk)
$apk_cmd
\`\`\`

---

**What's new in r$r**

$new_en

sing-box **$v** for podkop on OpenWrt, revision **r$r**: an unofficial build, not affiliated with the sing-box project. Go $GO_VERSION, \`sing-box version\` → \`$v-pdk-r$r\`. All changes: [CHANGELOG.md](${blob}/CHANGELOG.md); patches: [PATCHES.md](${blob}/docs/PATCHES.md).

**Packages** (install one): \`podkop-engine\` has what podkop uses${full_en}.

**Install** (\`<pkgarch>\`: \`opkg print-architecture\` / \`apk --print-arch\`; more in [INSTALL.md](${blob}/docs/INSTALL.md)). For \`podkop-engine-full\`, change the file name.
\`\`\`sh
# OpenWrt 24.10 and older (opkg)
$opkg_cmd
# OpenWrt 25.12 and snapshot (apk)
$apk_cmd
\`\`\`

Architectures ($n_ipk ipk, $n_apk apk): $arches

Compatibility: as the Xray client 26.9.9 (Xray servers 25.5.16+; 24.x–25.4.30 with the fingerprint fallback, or when the cover site does not choose X25519MLKEM768).
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
