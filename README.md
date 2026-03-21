[English](README.en.md) | **Русский**
# zapret-singbox

Контейнер объединяет [zapret](https://github.com/bol-van/zapret) и [sing-box](https://github.com/SagerNet/sing-box) в единую изолированную среду. Запрет работает через sing-box — весь трафик проксируется через sing-box, а iptables внутри контейнера перехватывает его и отправляет через zapret. Система работает полностью внутри контейнера и не затрагивает хост.

Основное назначение — удобное развёртывание связки zapret + sing-box без ручной установки на хост. В комплект входят скрипты для подбора и тестирования стратегий.

**DNS.** По умолчанию sing-box использует DNS-over-HTTPS (`1.1.1.1`). Это предотвращает перехват DNS-запросов провайдером.

---

## Принцип работы

```
Приложение  ──►  sing-box :7890  ──►  iptables NFQUEUE  ──►  zapret (nfqws)  ──►  Интернет
                   mixed proxy        перехват трафика         DPI bypass
```

Приложение подключается к прокси на порту `7890`. sing-box принимает соединение, iptables перехватывает исходящий трафик через NFQUEUE и передаёт zapret, который применяет выбранную стратегию обхода DPI.

---

## Запуск

### Вариант 1 — `docker run` (быстрый старт, стратегия уже известна)

```bash
docker run -d \
  --name zapret-singbox \
  --restart unless-stopped \
  --privileged \
  -e ZAPRET_STRATEGY=general_fake_tls_auto_alt_3 \
  -p 7890:7890 \
  ghcr.io/dunamis4tw/zapret-singbox:latest
```

> Скрипты управления при этом не работают — они рассчитаны на `docker-compose.yml`.

### Вариант 2 — `docker compose` (рекомендуется; поддерживает скрипты, свои конфиги, логи)

Создание директории:

```bash
mkdir -p /opt/zapret-singbox && cd /opt/zapret-singbox
```

Файл `docker-compose.yml`:

```yaml
services:
  zapret-singbox:
    image: ghcr.io/dunamis4tw/zapret-singbox:latest
    container_name: zapret-singbox
    restart: unless-stopped
    privileged: true
    environment:
      - ZAPRET_STRATEGY=general_fake_tls_auto_alt     # использовать указанную стратегию
    ports:
      - "7890:7890"                                   # пробрасываемый порт из дефолтного конфига sing-box
    volumes:
      - ./configs/sing-box:/opt/sing-box/configs      # опционально: пользовательские конфиги sing-box
      - ./configs/zapret:/opt/zapret/zapret.cfgs/configurations  # опционально: пользовательские стратегии zapret
      - ./logs/sing-box:/opt/sing-box/logs            # опционально: просмотр логов sing-box
```

Запуск:

```bash
docker compose up -d
```

После запуска прокси доступен на `localhost:7890` (HTTP и SOCKS5).

### Смена стратегии

Если `ZAPRET_STRATEGY` не задан, используется `general`. Для смены стратегии отредактируйте переменную `ZAPRET_STRATEGY` в `docker-compose.yml` и перезапустите контейнер:

```bash
docker compose up -d
```

Список доступных стратегий:

```bash
docker compose exec zapret-singbox ls /opt/zapret/zapret.cfgs/configurations
```

Для подбора лучшей стратегии используйте скрипт `test_strategies.sh`, работа которого описана в разделе [Скрипты](#скрипты).

<details>
<summary>Актуальный список стратегий</summary>

```
DiscordFix
DiscordFix_ALT
DiscordFix_ALT2
DiscordFix_для_МГТС
GeneralFix
GeneralFix_ALT
GeneralFix_ALT3
GeneralFix_ALT4
RussiaFix
UltimateFix
UltimateFix_ALT
UltimateFix_ALT_EXTENDED
UltimateFix_ALT_v10
UltimateFix_ALT_v2
UltimateFix_ALT_v3
UltimateFix_ALT_v4
UltimateFix_ALT_v5
UltimateFix_ALT_v6
UltimateFix_ALT_v7
UltimateFix_ALT_v8
UltimateFix_ALT_v9
UltimateFix_Universal
UltimateFix_Universal_v2
UltimateFix_Universal_v3
UltimateFix_для_МГТС
YoutubeFix_ALT
discord
fix_v1
fix_v2
fix_v3
general
general_ALT
general_ALT10
general_ALT11
general_ALT2
general_ALT3
general_ALT4
general_ALT5
general_ALT6
general_ALT7
general_ALT8
general_ALT9
general_fake_tls_auto
general_fake_tls_auto_alt
general_fake_tls_auto_alt_2
general_fake_tls_auto_alt_3
general_old
general_simple_fake
general_simple_fake_alt
general_simple_fake_alt2
general_МГТС
general_МГТС2
preset_russia
```

</details>

---

## Пользовательские конфигурации

Подключите нужные volumes в `docker-compose.yml` (см. выше). При первом запуске в пустые директории автоматически копируются дефолтные конфиги.

### Конфиг sing-box

После первого запуска файл появится в `./configs/sing-box/sing-box.conf`. По умолчанию это mixed-прокси на порту `7890` с DoH. Отредактируйте файл под свои нужды: можно добавить любые входящие протоколы (VMess, VLESS, Trojan и другие), настроить роутинг, DNS и прочее. После редактирования конфига перезапустите контейнер:

```bash
docker compose restart
```

### Стратегии zapret

После первого запуска готовые стратегии появятся в `./configs/zapret/`. Можно редактировать существующие, удалять ненужные и добавлять собственные. Имя файла стратегии — это значение переменной `ZAPRET_STRATEGY`.

---

## Скрипты

Скрипты рассчитаны на работу с `docker-compose.yml` в текущей директории.

### Установка

```bash
cd /opt/zapret-singbox

curl -fsSL https://raw.githubusercontent.com/dunamis4tw/zapret-singbox/main/switch_strategy.sh -o switch_strategy.sh
curl -fsSL https://raw.githubusercontent.com/dunamis4tw/zapret-singbox/main/test_strategies.sh -o test_strategies.sh
curl -fsSL https://raw.githubusercontent.com/dunamis4tw/zapret-singbox/main/blockcheck.sh      -o blockcheck.sh

chmod +x switch_strategy.sh test_strategies.sh blockcheck.sh
```

Либо используйте клонирование репозитория — см. [Сборка из исходников](#сборка-из-исходников).

---

### `switch_strategy.sh` — смена стратегии

Интерактивный выбор стратегии из списка. Обновляет `docker-compose.yml` и перезапускает контейнер.

```bash
./switch_strategy.sh
```

<details>
<summary>Пример вывода</summary>

```

📋 Доступные стратегии:

  1) DiscordFix                       19) UltimateFix_ALT_v7              37) general_ALT4
  2) DiscordFix_ALT                   20) UltimateFix_ALT_v8              38) general_ALT5
  3) DiscordFix_ALT2                  21) UltimateFix_ALT_v9              39) general_ALT6
  4) DiscordFix_для_МГТС              22) UltimateFix_Universal           40) general_ALT7
  5) GeneralFix                       23) UltimateFix_Universal_v2        41) general_ALT8
  6) GeneralFix_ALT                   24) UltimateFix_Universal_v3        42) general_ALT9
  7) GeneralFix_ALT3                  25) UltimateFix_для_МГТС            43) general_fake_tls_auto
  8) GeneralFix_ALT4                  26) YoutubeFix_ALT                ▶ 44) general_fake_tls_auto_alt
  9) RussiaFix                        27) discord                         45) general_fake_tls_auto_alt_2
  10) UltimateFix                     28) fix_v1                          46) general_fake_tls_auto_alt_3
  11) UltimateFix_ALT                 29) fix_v2                          47) general_old
  12) UltimateFix_ALT_EXTENDED        30) fix_v3                          48) general_simple_fake
  13) UltimateFix_ALT_v10             31) general                         49) general_simple_fake_alt
  14) UltimateFix_ALT_v2              32) general_ALT                     50) general_simple_fake_alt2
  15) UltimateFix_ALT_v3              33) general_ALT10                   51) general_МГТС
  16) UltimateFix_ALT_v4              34) general_ALT11                   52) general_МГТС2
  17) UltimateFix_ALT_v5              35) general_ALT2                    53) preset_russia
  18) UltimateFix_ALT_v6              36) general_ALT3

▶  — текущая стратегия: general_fake_tls_auto_alt

Введите номер стратегии [1-53]: 42

⚙️  Выбрана стратегия: general_ALT9
✅ docker-compose.yml обновлён

🔄 Перезапуск контейнера...
[+] up 1/1
 ✔ Container zapret-singbox Started                                                                                                                                              1.9s

✅ Контейнер перезапущен со стратегией: general_ALT9

```

</details>

---

### `test_strategies.sh` — тестирование стратегий

Последовательно применяет выбранные стратегии и проверяет доступность сайтов через прокси. Результаты сохраняются в `./strategy_test_results/`.

```bash
./test_strategies.sh
```

<details>
<summary>Пример вывода</summary>

```

━━━ Шаг 1: Выбор стратегий ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1) discord                         19) general_ALT8                   37) UltimateFix
  2) DiscordFix                      20) general_ALT9                   38) UltimateFix_ALT
  3) DiscordFix_ALT                  21) general_fake_tls_auto          39) UltimateFix_ALT_EXTENDED
  4) DiscordFix_ALT2                 22) general_fake_tls_auto_alt      40) UltimateFix_ALT_v10
  5) DiscordFix_для_МГТС             23) general_fake_tls_auto_alt_2    41) UltimateFix_ALT_v2
  6) fix_v1                        ▶ 24) general_fake_tls_auto_alt_3    42) UltimateFix_ALT_v3
  7) fix_v2                          25) GeneralFix                     43) UltimateFix_ALT_v4
  8) fix_v3                          26) GeneralFix_ALT                 44) UltimateFix_ALT_v5
  9) general                         27) GeneralFix_ALT3                45) UltimateFix_ALT_v6
  10) general_ALT                    28) GeneralFix_ALT4                46) UltimateFix_ALT_v7
  11) general_ALT10                  29) general_old                    47) UltimateFix_ALT_v8
  12) general_ALT11                  30) general_simple_fake            48) UltimateFix_ALT_v9
  13) general_ALT2                   31) general_simple_fake_alt        49) UltimateFix_Universal
  14) general_ALT3                   32) general_simple_fake_alt2       50) UltimateFix_Universal_v2
  15) general_ALT4                   33) general_МГТС                   51) UltimateFix_Universal_v3
  16) general_ALT5                   34) general_МГТС2                  52) UltimateFix_для_МГТС
  17) general_ALT6                   35) preset_russia                  53) YoutubeFix_ALT
  18) general_ALT7                   36) RussiaFix

  ▶ — текущая стратегия: general_fake_tls_auto_alt_3

Введите номера стратегий [1-53] (диапазоны: 1,3,10-20 | Enter = все): 9,23-24

  Выбрано стратегий: 3

━━━ Шаг 2: Выбор сайтов ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   1) https://rutracker.org
   2) https://discord.com
   3) https://youtube.com
   4) https://x.com
   5) https://instagram.com
   6) https://t.me
   7) https://store.steampowered.com

Добавить свои сайты? (через запятую, или Enter чтобы пропустить): google.com,bbc.com

Введите номера сайтов [1-9] (диапазоны: 1,3-5 | Enter = все): 1-3,7-9

  Выбрано сайтов: 6
    • https://rutracker.org
    • https://discord.com
    • https://youtube.com
    • https://store.steampowered.com
    • google.com
    • bbc.com

━━━ Запуск тестирования ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Лог: ./strategy_test_results/2026-03-21_15-19-14_test.log

Начать? [Y/n]: y

[1/3] Стратегия: general
────────────────────────────────────────────
  Ждём 4с после перезапуска...
    ✘  rutracker.org              TIMEOUT (>5s)
    ✘  discord.com                TIMEOUT (>5s)
    ✘  youtube.com                TIMEOUT (>5s)
    ✘  store.steampowered.com     TIMEOUT (>5s)
    ✘  google.com                 TIMEOUT (>5s)
    ✘  bbc.com                    TIMEOUT (>5s)
────────────────────────────────────────────

[2/3] Стратегия: general_fake_tls_auto_alt_2
────────────────────────────────────────────
  Ждём 4с после перезапуска...
    ✘  rutracker.org              TIMEOUT (>5s)
    ✘  discord.com                TIMEOUT (>5s)
    ✘  youtube.com                TIMEOUT (>5s)
    ✘  store.steampowered.com     TIMEOUT (>5s)
    ✘  google.com                 TIMEOUT (>5s)
    ✘  bbc.com                    TIMEOUT (>5s)
────────────────────────────────────────────

[3/3] Стратегия: general_fake_tls_auto_alt_3
────────────────────────────────────────────
  Ждём 4с после перезапуска...
    ✔  rutracker.org              HTTP 200
    ✔  discord.com                HTTP 200
    ✔  youtube.com                HTTP 200
    ✔  store.steampowered.com     HTTP 200
    ✔  google.com                 HTTP 200
    ✔  bbc.com                    HTTP 200
────────────────────────────────────────────

━━━ Готово ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Результаты: ./strategy_test_results/2026-03-21_15-19-14_test.log

  ✔ = HTTP 2xx/3xx   ~ = HTTP 4xx/5xx или TLS   ✘ = таймаут / нет соединения

Восстановить исходную стратегию (general_fake_tls_auto_alt_3)? [Y/n]: n

```

</details>

---

### `blockcheck.sh` — поиск стратегии для конкретного сайта

Запускает встроенный `blockcheck.sh` из zapret внутри контейнера. Определяет, какой метод обхода работает для конкретного домена. Результат сохраняется в `./blockcheck_results/`.

```bash
./blockcheck.sh
```

> Скрипт остановит zapret на время проверки. Blockcheck запрашивает домен и работает несколько минут. По результату можно составить собственную стратегию или выбрать подходящую из готовых.

---

## Сборка из исходников

```bash
git clone https://github.com/dunamis4tw/zapret-singbox.git /opt/zapret-singbox
cd /opt/zapret-singbox

docker compose build
docker compose up -d
docker compose logs -f
```

Версии компонентов задаются через `ARG` в `Dockerfile`:

```dockerfile
ARG ZAPRET_VERSION=v72.10
ARG SINGBOX_VERSION=1.13.0
```

<details>
<summary>Пересборка с другими версиями</summary>

```bash
docker compose build \
  --build-arg ZAPRET_VERSION=v72.11 \
  --build-arg SINGBOX_VERSION=1.14.0
```

</details>

---

## Устранение неполадок

**1. Прокси недоступен**

```bash
docker compose ps
docker compose logs zapret-singbox
ss -tlnp | grep 7890   # порт занят другим процессом?
```

**2. Стратегия не найдена**

Контейнер завершается с ошибкой:
```
[entrypoint] Ошибка: стратегия 'my_strategy' не найдена
```
Проверьте значение `ZAPRET_STRATEGY` — список доступных стратегий выводится в лог сразу после ошибки. Если используете кастомные стратегии через volume — убедитесь, что файл с нужным именем существует в `./configs/zapret/`.

**3. Конфиги не появляются в смонтированных директориях**

Дефолтные конфиги копируются только если директория **пустая** при старте. Если в ней уже есть файлы — автокопирование не срабатывает. Для сброса к дефолтным:

```bash
docker compose down
rm -rf ./configs/sing-box/* ./configs/zapret/*
docker compose up -d
```

**4. sing-box падает с ошибкой конфига**

```bash
docker compose logs zapret-singbox
tail -f ./logs/sing-box/sing-box.log   # если подключён volume
```
Проверьте корректность JSON в `sing-box.conf` — файл должен быть валидным JSON.

**5. Контейнер не работает без `privileged: true`**

`privileged: true` обязателен — zapret использует `iptables` и `NFQUEUE` внутри контейнера. Без этого флага правила не применятся.

---

## Использованные компоненты

| Компонент | Автор | Репозиторий | Лицензия |
|---|---|---|---|
| zapret | bol-van | [github.com/bol-van/zapret](https://github.com/bol-van/zapret) | MIT |
| sing-box | SagerNet | [github.com/SagerNet/sing-box](https://github.com/SagerNet/sing-box) | GPL-3.0 |
| zapret.cfgs | Snowy-Fluffy | [github.com/Snowy-Fluffy/zapret.cfgs](https://github.com/Snowy-Fluffy/zapret.cfgs) | — |

---

## Лицензия

MIT License. См. файл [LICENSE](LICENSE).

Проект является обёрткой над сторонними компонентами. Каждый компонент распространяется под собственной лицензией (см. таблицу выше).
