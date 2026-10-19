# Выпуск (пока вручную)

## Когда

- вышел новый тег в одной из веток sing-box (1.12.x, 1.13.x, 1.14.x) или новая ветка;
- вышел Xray-core, меняющий REALITY (как 26.9.8) — прогнать стенд, даже если sing-box не менялся;
- изменились наши патчи.

## Шаги

1. **Перенести патчи на новый тег** (в клоне SagerNet/sing-box). Учётка git в клоне и здесь —
   `FiyeroT <me@fiyero.xyz>` (`git config user.name FiyeroT; git config user.email me@fiyero.xyz`):
   она попадает в `From:` патчей и в коммиты.
   ```sh
   git checkout -b pe-1.14 v1.14.3
   git am -3 /path/podkop-engine/patches/v1.14/*.patch     # конфликты — поправить, git am --continue
   git format-patch v1.14.3 -o /path/podkop-engine/patches/v1.14/   # заменить старые файлы
   ```
   Для патча include (0035 в r9) проверить, не появились ли в `include/registry.go` новые
   регистрации: новый тип выхода — в `include/podkop_full.go` и `podkop_full_stub.go`, новый вход,
   DNS-сервер или служба — в `podkop_slim.go` и `podkop_slim_stub.go` (иначе он молча попадёт в
   `podkop-engine`); и что `cmd/sing-box/cmd_api*.go` по-прежнему исчерпывают CLI `api`
   (на 1.14 с r15 командная строка — пакет `cmd/sing-box/cli`, и её файлы `cmd_api*.go` закрыты
   ограничением сборки `!podkop_slim`: у нового файла `api` оно должно быть тоже).
   При новой версии cronet-go сверить `openwrt/podkop-engine/naive.pkgarchs` со строками
   `openwrt:` матрицы naive в `.github/workflows/build.yml` sing-box, а `LLD_URL`/`LLD_SHA256`
   в `versions.env` — с `CLANG_REVISION`/`CLANG_SUB_REVISION` в
   `src/tools/clang/scripts/update.py` naiveproxy той же версии cronet.
   Новая ветка (например 1.15): каталог `patches/v1.15`, строка в `LINES`.

   **Форки библиотек.** sing-vmess (обе линии) и sing-quic (только 1.13) берутся из форков
   [FiyeroT/sing-vmess](https://github.com/FiyeroT/sing-vmess) и
   [FiyeroT/sing-quic](https://github.com/FiyeroT/sing-quic): директивы `replace` в `go.mod`,
   патчи `go.mod: …`. Исправление в библиотеке — это коммит в ветке форка (sing-vmess:
   `pdk-1.13`, `pdk-1.14.3`; sing-quic: `pdk-1.13`), новый тег (sing-vmess: `v0.2.8-pdk13.N`
   и `v0.2.9-pdk.N`, sing-quic: `v0.6.5-pdk13.N`) и новые строки
   `go.mod` и `go.sum` в sing-box. Тег должен быть опубликован до сборки: SDK берёт модули
   через прокси Go. С r15 линия 1.14 стоит на 1.14.3, где исправления форка sing-quic уже в
   версии upstream: форк там не нужен.

2. **versions.env**: `SB_<ветка>_VERSION`, `SB_<ветка>_HASH`
   (`curl -sL https://codeload.github.com/SagerNet/sing-box/tar.gz/v<версия> | sha256sum`),
   `SB_<ветка>_RELEASE=1` для новой версии upstream или +1, если менялись только патчи.
   Если upstream поднял требуемый Go выше закреплённого — обновить `GOLANG_FEED_COMMIT`
   (последний коммит `lang/golang` в нужной ветке openwrt/packages).

3. **Проверить локально x86_64** (быстро, до CI):
   ```sh
   docker run --rm -v "$PWD:/src:ro" -v "$PWD/out:/out" openwrt/sdk:x86-64-v24.10.8 sh /src/scripts/sdk-build.sh 1.14
   for p in podkop-engine podkop-engine-full; do
     docker run --rm -e PKG=$p -v "$PWD/out:/pkgs:ro" -v "$PWD/lab/podkop-check:/t:ro" -v "$PWD/lab:/lab:ro" openwrt/rootfs:x86-64-24.10.8 sh /lab/pkg-test.sh
   done
   lab/fetch-bins.sh out lab/bin && lab/gate.sh lab/bin
   ```
   Свежий Xray для стенда: `XRAY_EXTRA="26.10.1" lab/fetch-bins.sh ...`.

4. **CI**: Actions → build → Run workflow на ветке выпуска (формат, `release` = true). В поле
   «Ветки» — только линии с новой ревизией (для r13: `1.13 1.14`): на первой линии, релиз
   которой уже есть (1.12 — `v1.12.25-r1`), `scripts/release.sh` останавливается и черновики
   остальных не создаёт. Workflow собирает все
   pkgarch, ставит x86_64-пакеты в OpenWrt 24.10 / 25.12 / snapshot вместе с podkop, прогоняет
   стенд и создаёт **черновики** релизов — по одному на ветку (`v<версия>-r<N>`), с пакетами,
   `SHA256SUMS` и описанием. Если релиз с таким тегом уже есть, job падает: поднимите `SB_<ветка>_RELEASE`.

5. Просмотреть черновики (список архитектур, лог стенда `lab-results`: строка `GATE: OK`).
   Перед публикацией перевести `main` на собранный коммит (`git push origin <коммит>:main`):
   тег `v<версия>-r<N>` GitHub создаёт при публикации, а описание ссылается на
   `docs/INSTALL.md` в `main`. Черновик создаётся с целью — коммитом запуска CI. Публиковать
   сначала старшие ревизии младших линий (`gh release edit <тег> --draft=false
   --latest=false`), последней — старшую линию (`--latest`). Только после публикации файлы
   скачиваются без авторизации (wget на роутере).

## Если стенд показал MISMATCH

- новый Xray отвергает клиента (`authentication failed or validation criteria not met` при `show`)
  — смотреть изменения в XTLS/REALITY между версиями (так нашлась причина 26.9.8);
- проверить, ведёт ли себя так же эталонный Xray-клиент той же версии (`xrayc-<версия>` в стенде):
  цель — вести себя как он.
