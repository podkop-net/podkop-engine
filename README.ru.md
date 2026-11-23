# podkop-engine

[English](README.md)

Неофициальная сборка [sing-box](https://github.com/SagerNet/sing-box) для
[podkop](https://github.com/itdoginfo/podkop) на OpenWrt. **Проект не связан с sing-box и его
авторами.** Пакет называется иначе, потому что лицензия sing-box запрещает производным работам
использовать его имя. Бинарь по-прежнему ставится как `/usr/bin/sing-box`, пакет объявляет
`PROVIDES: sing-box`, поэтому зависимость podkop от `sing-box` выполняется.

Кто им пользуется:

- **podkop 0.7.x** работает на нём, если поставить его вместо `sing-box` из OpenWrt; для podkop
  0.7.24 — 1.14.4-r26 и новее. Ссылки XHTTP и резервные выходы URLTest в podkop работают только с этой сборкой.
- **[podkop-exp](https://github.com/podkop-net/podkop-experimental)** собирает тот же код в свой
  бэкенд, пакет ему не нужен. На что он опирается, записано в
  [docs/EMBEDDING.md](docs/EMBEDDING.md) (на английском).

## Что добавляет к sing-box

- **Современные серверы Xray.** REALITY отправляет ключ X25519MLKEM768, клиент ведёт себя как Xray
  26.9.9. Отпечатки uTLS совпадают с Xray (`firefox` = Firefox 148, `safari` = Safari 26.3),
  `randomized` согласован.
- **Ответы ТСПУ.** Автосмена отпечатка (по умолчанию выключена, podkop-exp её включает) пробует
  другие ClientHello, когда на один нет ответа, и запоминает рабочий. `tls.spoof` (поддельный ClientHello из upstream) работает и с REALITY, как
  и `fragment` и `record_fragment`.
- **Протоколы Xray:** транспорт XHTTP и шифрование VLESS. `sing-box tools decode-link` превращает
  ссылки всех протоколов в outbound.
- **Старт без списков.** Remote rule-set, который не скачался, больше не останавливает sing-box: он
  стартует с пустым списком и докачивает его. Список, который не приходит напрямую, может прийти
  через другие выходы (`http_clients`).
- **Большие списки в малой памяти.** Домены хранятся в компактном дереве, подсети — диапазонами.
  Списки лежат в файлах рядом с файлом кэша, а не внутри него.
- **DNS, который отвечает.** Свой сокет на каждый запрос, повтор запросов, DNS провайдера как
  резервный (в podkop-exp — каждого аплинка), группы серверов по порядку или сначала самый быстрый. AAAA
  отдаётся, если у имени нет IPv4 (`ipv6_if_no_ipv4`).
- **urltest:** резервные выходы (и `block`), проверка загрузкой перед переключением, несколько
  адресов проверки с медианой, режимы `loss` и `balance` (и для участников по QUIC), не больше 4
  проверок сразу.
- **Замена выходов на ходу**, так что изменённая подписка не обрывает открытые соединения (для
  программ, встраивающих движок, например podkop-exp).
- **FakeIP** отвечает из памяти и пишет на диск в фоне. Соединение к адресу FakeIP без записи идёт
  по имени, которое нашёл сниффер.
- **Память:** лимит памяти Go следует за памятью, которую система ещё может дать. Простаивающие
  соединения TLS, QUIC и gRPC ждут данных без буфера.
- **Снифферы:** BitTorrent опознаётся по uTP и DHT, туннель WireGuard больше не принимается за
  BitTorrent. Специально собранный пакет не роняет sing-box: сбой сниффера стоит только его
  соединения.
- **Детектор блокировок** читает, что делает каждый сервер, и сообщает это дашборду podkop-exp.
- **Два пакета поменьше** (ниже) и служба failsafe. Если sing-box падает раз за разом, служба
  останавливает podkop, и роутеру возвращается его DNS.
- **Исправления** в DNS, транспортах v2ray, Clash API и другом — в [истории изменений](CHANGELOG.ru.md).

Все опции описаны в [docs/FEATURES.ru.md](docs/FEATURES.ru.md), замеры против sing-box без патчей —
в [docs/BENCHMARKS.ru.md](docs/BENCHMARKS.ru.md).

## Пакеты

Пакетов два, ставится один.

| | `podkop-engine` | `podkop-engine-full` |
|---|---|---|
| Входы | tproxy, direct, mixed | те же |
| Выходы | direct, socks, shadowsocks, trojan, vless, hysteria2, tuic, http, selector, urltest, block | те же и ещё vmess, snell, tor (нужен пакет tor), ssh, shadowtls, anytls, hysteria, naive (NaiveProxy, [не на всех архитектурах](docs/INSTALL.ru.md#naiveproxy)) |
| Пакет, r29: x86_64 / aarch64_cortex-a53 / mipsel_24kc | 9,8 / 8,8 / 8,8 МБ | 15,6 / 14,3 / 15,4 МБ |

Чего нет ни в одном пакете по сравнению с полным sing-box: других серверных входов, TUN, WireGuard и
Tailscale внутри sing-box (WireGuard и AmneziaWG в podkop подключаются интерфейсом OpenWrt), DNS-серверов
DoQ, DoH3 и DHCP, ACME, служб (API, SSM API, OOM killer и других). Конфиг с типом, которого в пакете нет, не проходит
`sing-box check` с понятной ошибкой, например
`vmess outbound is not included in this build (podkop_slim), install podkop-engine-full or rebuild
with -tags podkop_full`.

## Установка

Файл под свою архитектуру (`opkg print-architecture` или `apk --print-arch`) берётся из
[последнего релиза](https://github.com/podkop-net/podkop-engine/releases/latest), в описании
которого есть команда в одну строку для opkg и apk. Переход между пакетами, обновление и возврат к
sing-box из OpenWrt — в [docs/INSTALL.ru.md](docs/INSTALL.ru.md).

## Версии

- Теги — `v<версия sing-box>-r<ревизия>`, например `v1.14.4-r29`. Ревизия — номер выпуска
  podkop-engine, один на все линии, собранные в нём.
- Поддерживается линия **1.14** (sing-box 1.14.4, 71 патч). У 1.12.25 был один выпуск (r1, два
  патча). Линия 1.13 закончилась на `v1.13.21-r18`.
- `sing-box version` печатает `1.14.4-pdk-r29` и строку `Features:` — что добавляет эта сборка.
- Форк — это тег upstream плюс [патчи](docs/PATCHES.md) и ничего больше: ветка
  `podkop-engine-1.14` в [podkop-net/sing-box](https://github.com/podkop-net/sing-box).
- Собирается Go 1.26.8 из openwrt/packages: `.ipk` — в SDK OpenWrt 24.10, `.apk` — в SDK 25.12,
  под все архитектуры, для которых sing-box есть в репозитории OpenWrt.

## Совместимость с серверами

Клиент ведёт себя как Xray-core 26.9.9 и работает с серверами Xray 25.5.16 и новее. Xray
24.x–25.4.30 принимает первый ClientHello автосмены отпечатка (без X25519MLKEM768); без автосмены
такой сервер отказывает, если его сайт-прикрытие выбирает X25519MLKEM768 (так делает большинство
крупных сайтов). Лечится обновлением Xray на сервере.

## Документация

| | |
|---|---|
| [docs/INSTALL.ru.md](docs/INSTALL.ru.md) | установка, переход между пакетами, обновление, удаление; служба failsafe; архитектуры NaiveProxy |
| [CHANGELOG.ru.md](CHANGELOG.ru.md) | что изменилось в каждом выпуске, r1 … r29 |
| [docs/FEATURES.ru.md](docs/FEATURES.ru.md) | опции и инструменты этой сборки, с примерами |
| [docs/PATCHES.md](docs/PATCHES.md) | каждый патч к sing-box и что он меняет (на английском) |
| [docs/BENCHMARKS.ru.md](docs/BENCHMARKS.ru.md) | замеры против sing-box без патчей |
| [docs/LINKS.md](docs/LINKS.md) | ссылки, которые читает `decode-link`, ключ за ключом |
| [docs/EMBEDDING.md](docs/EMBEDDING.md) | для программ, встраивающих движок (podkop-exp): Go API, опции, переменные окружения и тексты, на которые они опираются (на английском) |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | устройство репозитория, сборка, проверки (на английском) |
| [docs/RELEASE.md](docs/RELEASE.md) | как делается выпуск |

## Лицензия

GPL-3.0-or-later (`LICENSE`); лицензия sing-box — в `LICENSE.sing-box`. Упаковка основана на
`net/sing-box` из openwrt/packages.
