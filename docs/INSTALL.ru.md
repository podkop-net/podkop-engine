# Установка

[English](INSTALL.md)

Пакет ставит `/usr/bin/sing-box`, `/etc/init.d/sing-box` и `/etc/config/sing-box` — те же пути, что
пакет `sing-box` из OpenWrt, поэтому с ним он конфликтует и заменяет его. Кроме того, он ставит
службу failsafe `/etc/init.d/podkop-engine`.

- [Какой файл взять](#какой-файл-взять)
- [OpenWrt 24.10 и старше (opkg)](#openwrt-2410-и-старше-opkg)
- [OpenWrt 25.12 и snapshot (apk)](#openwrt-2512-и-snapshot-apk)
- [Переход между podkop-engine и podkop-engine-full](#переход-между-podkop-engine-и-podkop-engine-full)
- [Обновление](#обновление)
- [Откат на sing-box из OpenWrt](#откат-на-sing-box-из-openwrt)
- [Служба failsafe](#служба-failsafe)
- [NaiveProxy](#naiveproxy)

## Какой файл взять

Файлы — в [релизах](https://github.com/podkop-net/podkop-engine/releases), имя
`podkop-engine_<версия>_openwrt_<pkgarch>.ipk` (или `.apk`), например
`podkop-engine_1.14.4-r27_openwrt_aarch64_cortex-a53.ipk`.

- `<pkgarch>` — то, что печатает на роутере `opkg print-architecture` или `apk --print-arch`.
- В `podkop-engine` есть всё, что использует podkop. `podkop-engine-full` нужен, только если в
  «Outbound Config» другой протокол (vmess, snell, tor, ssh, shadowtls, anytls, hysteria, naive).
  Ставятся оба одинаково, меняется только имя файла.
- Для podkop 0.7.24 — 1.14.4-r26 и новее. Линия 1.13 больше не собирается.

Файл скачивайте на роутере через API GitHub: `wget` в OpenWrt (uclient-fetch) висит на прямой ссылке
скачивания github.com — строка заголовка там 9 КБ, больше, чем он читает. В описании релиза эта
команда уже с подставленными именами:

```sh
tag=v1.14.4-r27; n=podkop-engine_1.14.4-r27_openwrt_<pkgarch>.ipk
u=$(wget -qO- https://api.github.com/repos/podkop-net/podkop-engine/releases/tags/$tag | jsonfilter -e "@.assets[@.name='$n'].url") \
  && wget -O /tmp/pe.ipk --header='Accept: application/octet-stream' "$u"
```

Для apk впишите в `n` имя файла `.apk` и сохраняйте в `/tmp/pe.apk`.

## OpenWrt 24.10 и старше (opkg)

```sh
opkg update
# если стоит sing-box из OpenWrt (podkop от него зависит — отсюда --force-depends):
opkg remove --force-depends sing-box sing-box-tiny 2>/dev/null
opkg install /tmp/pe.ipk
service podkop restart
```

Без удаления opkg откажет: `The following packages conflict with podkop-engine: sing-box`. После
замены `opkg upgrade` sing-box из OpenWrt обратно не предлагает.

## OpenWrt 25.12 и snapshot (apk)

```sh
apk update
apk add --allow-untrusted /tmp/pe.apk
service podkop restart
```

apk заменяет установленный `sing-box` одной транзакцией. `--allow-untrusted` нужен, пока пакеты не
подписаны. apk закрепляет этот пакет в `/etc/apk/world`, и `apk upgrade` не возвращает sing-box из
OpenWrt.

Файл в `/etc`, изменённый на месте или не принадлежащий ни одному пакету, apk не перезаписывает:
оставляет его и кладёт файл пакета рядом с суффиксом `.apk-new`. С чужим `/etc/init.d/sing-box`
(после движка, поставленного руками, или правленого скрипта) sing-box работал бы без резервного
DNS, проверки загрузкой urltest и лимита в 65536 дескрипторов. С r14 пакет сам ставит свой скрипт на
место, прежний сохраняет в `/etc/sing-box/sing-box.init.before-podkop-engine` и пишет об этом
строку в журнал.

## Переход между podkop-engine и podkop-engine-full

Скачайте другой пакет, как выше (`n=podkop-engine-full_…`), затем:

```sh
# opkg
opkg remove --force-depends podkop-engine && opkg install /tmp/pe.ipk
# apk
apk add --allow-untrusted /tmp/pe.apk '!podkop-engine'
service podkop restart
```

Обратно — то же с именами наоборот. `/etc/config/sing-box` сохраняется.

## Обновление

Новый файл скачивается и ставится так же (`opkg install /tmp/pe.ipk` или
`apk add --allow-untrusted /tmp/pe.apk`). `/etc/config/sing-box`
сохраняется; опции, которые добавил новый выпуск, получают значения по умолчанию.

Проверить, что работает:

```sh
sing-box version   # sing-box version 1.14.4-pdk-r27 … Tags: with_quic,with_utls,with_clash_api,podkop_slim …
```

## Откат на sing-box из OpenWrt

```sh
# opkg: сначала остановить podkop и скачать пакет, потом удалять
service podkop stop && opkg update && cd /tmp && opkg download sing-box && opkg remove --force-depends podkop-engine && opkg install /tmp/sing-box_*.ipk; service podkop start
# apk: одной транзакцией
apk add sing-box '!podkop-engine'
```

На opkg порядок важен. Пока podkop работает, все DNS-запросы роутера идут в sing-box: если сначала
удалить podkop-engine, роутер останется без DNS и не скачает пакет. Если это уже случилось, DNS
возвращает `service podkop stop`. `apk del podkop-engine` отдельно не сработает: от него зависит
podkop. Если стоит `podkop-engine-full`, в этих командах — его имя.

## Служба failsafe

`/etc/init.d/podkop-engine` следит за sing-box. Упавший sing-box перезапускает procd. Если sing-box
падает раз за разом, procd сдаётся, и dnsmasq слал бы все запросы в пустоту; в этот момент служба
останавливает podkop — роутеру возвращается его DNS, интернет работает без прокси. Ещё служба раз в
20 с задаёт sing-box DNS-вопрос: sing-box, который работает, но перестал отвечать, завершается, и
это считается падением. Причина и память роутера пишутся в журнал и в
`/etc/sing-box/failsafe.last`. Когда причина устранена, podkop запускается снова: `service podkop
start`. Подробности и опции — в [FEATURES.ru.md](FEATURES.ru.md#failsafe-и-самопроверка).

## NaiveProxy

NaiveProxy (выход `naive` в `podkop-engine-full`) работает на cronet — сетевом стеке Chromium,
который sing-box выпускает не для всех архитектур. Бинарь с ним больше на 11 МБ (x86_64) — 17 МБ
(mipsel).

- **С NaiveProxy:** `aarch64_cortex-a53` `aarch64_cortex-a72` `aarch64_cortex-a76`
  `aarch64_generic` `arm_cortex-a15_neon-vfpv4` `arm_cortex-a5_vfpv4` `arm_cortex-a7_neon-vfpv4`
  `arm_cortex-a7_vfpv4` `arm_cortex-a8_vfpv3` `arm_cortex-a9_neon` `arm_cortex-a9_vfpv3-d16`
  `i386_pentium4` `loongarch64_generic` `mipsel_24kc` `mipsel_74kc` `riscv64_generic` `x86_64`
- **Без него:** `arm_arm1176jzf-s_vfp` `arm_arm926ej-s` `arm_cortex-a7` `arm_cortex-a9`
  `arm_fa526` `arm_xscale` `i386_pentium-mmx` `mips64_mips64r2` `mips64_octeonplus`
  `mips64el_mips64r2` `mips_24kc` `mips_4kec` `mips_mips32` `mipsel_24kc_24kf` `mipsel_mips32`
  `riscv64_riscv64`

Почему нет: cronet нет для MIPS big-endian и MIPS64; он собран под ARMv7 с VFP (не ARMv5/v6 и не ARM
без FPU), с программной плавающей точкой (не `mipsel_24kc_24kf`), под MIPS32r2 (не `mipsel_mips32`),
с SSE2 (не `i386_pentium-mmx`) и только для `riscv64_generic`. На этих архитектурах остальные
протоколы `podkop-engine-full` работают, а выход `naive` отвечает
`naive outbound is not included in this build`.
