# zapret-singbox

Docker-контейнер, объединяющий [zapret](https://github.com/bol-van/zapret) (обход DPI) и [sing-box](https://github.com/SagerNet/sing-box) (прокси-сервер) в единый сетевой шлюз. Предназначен для пользователей в России, которым нужно обходить блокировки и при этом направлять трафик через настраиваемый прокси.

## Принцип работы

```
Клиент → sing-box (порт 7890) → zapret (обход DPI) → Интернет
```

sing-box принимает HTTP/SOCKS5 подключения на порту 7890. Трафик затем проходит через zapret, который применяет стратегии обхода DPI перед отправкой к заблокированным ресурсам.

## Требования

- Docker и Docker Compose
- Linux-хост (необходима поддержка iptables)
- Готовый конфиг sing-box

## Быстрый старт

**1. Клонировать репозиторий**

```bash
git clone https://github.com/ВАШ_ЮЗЕРНЕЙМ/zapret-singbox.git
cd zapret-singbox
```

**2. Добавить стратегии zapret**

Склонировать набор стратегий в `./configs/zapret/`:

```bash
git clone https://github.com/Snowy-Fluffy/zapret.cfgs configs/zapret-src
cp -r configs/zapret-src/configurations/* configs/zapret/
```

Или положить собственные файлы стратегий в `./configs/zapret/`.

**3. Настроить sing-box**

Отредактировать `./configs/sing-box/sing-box.conf`. По умолчанию контейнер открывает порт `7890` как mixed-прокси (HTTP + SOCKS5).

**4. Выбрать стратегию и запустить**

Открыть `docker-compose.yml` и указать нужную стратегию:

```yaml
environment:
  - ZAPRET_STRATEGY=general   # имя файла из ./configs/zapret/
```

Затем собрать и запустить:

```bash
./start.sh
# или вручную:
docker compose up -d --build
```

## Скрипты управления

| Скрипт | Описание |
|---|---|
| `./start.sh` | Сборка образа и запуск контейнера |
| `./restart.sh` | Перезапуск контейнера |
| `./switch_strategy.sh` | Интерактивная смена стратегии |
| `./test_strategies.sh` | Автоматическое тестирование стратегий через прокси |
| `./blockcheck.sh` | Запуск диагностики `blockcheck.sh` внутри контейнера |

### switch_strategy.sh

Выводит пронумерованный список всех доступных стратегий (текущая выделена), позволяет выбрать нужную, автоматически обновляет `docker-compose.yml` и перезапускает контейнер.

```bash
./switch_strategy.sh
```

### test_strategies.sh

Перебирает выбранные стратегии по очереди: для каждой перезапускает контейнер и проверяет список URL через прокси с помощью `curl`. Результаты выводятся в консоль и сохраняются в `./strategy_test_results/`.

```bash
./test_strategies.sh
```

### blockcheck.sh

Останавливает zapret внутри запущенного контейнера и запускает встроенный диагностический скрипт `blockcheck.sh` в интерактивном режиме. Вывод сохраняется в `./blockcheck_results/` с именем файла, содержащим дату и текущую стратегию.

```bash
./blockcheck.sh
```

## Структура директорий

```
zapret-singbox/
├── configs/
│   ├── sing-box/
│   │   └── sing-box.conf       # Конфиг sing-box
│   └── zapret/                 # Файлы стратегий (не отслеживается git)
├── logs/
│   └── sing-box/               # Логи sing-box (не отслеживается git)
├── blockcheck_results/         # Результаты диагностики blockcheck
├── strategy_test_results/      # Результаты тестирования стратегий
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── start.sh
├── restart.sh
├── switch_strategy.sh
├── test_strategies.sh
└── blockcheck.sh
```

## Конфигурация

### docker-compose.yml

```yaml
services:
  zapret-singbox:
    environment:
      - ZAPRET_STRATEGY=general   # имя файла из ./configs/zapret/
    ports:
      - "7890:7890"               # порт прокси
```

### Настройки прокси на клиенте

```
HTTP прокси:   http://IP_ХОСТА:7890
SOCKS5 прокси: socks5://IP_ХОСТА:7890
```

## Аргументы сборки

| ARG | По умолчанию | Описание |
|---|---|---|
| `ZAPRET_VERSION` | `v72.10` | Тег релиза zapret |
| `SINGBOX_VERSION` | `1.13.0` | Версия sing-box |

Сборка с другими версиями:

```bash
docker compose build \
  --build-arg ZAPRET_VERSION=v72.11 \
  --build-arg SINGBOX_VERSION=1.13.1
```

## Передача образа другу

**Архив файлов проекта** (без логов и конфигов стратегий):

```bash
tar -czvf zapret-singbox.tar.gz \
    --exclude='./logs' \
    --exclude='./configs/zapret' \
    --exclude='.git' \
    --exclude='./strategy_test_results' \
    --exclude='./blockcheck_results' \
    .
```

**Экспорт готового Docker-образа** (без необходимости пересборки):

```bash
docker save zapret-singbox-zapret-singbox | gzip > zapret-singbox-image.tar.gz
# у получателя:
docker load < zapret-singbox-image.tar.gz
```

## Устранение неполадок

**Контейнер сразу завершается** — убедись, что `ZAPRET_STRATEGY` совпадает с именем существующего файла в `./configs/zapret/`.

**Порт 7890 недоступен** — проверь, что брандмауэр на хосте не блокирует порт.

**Все сайты не открываются** — возможно, конфиг sing-box некорректен, или стратегия не подходит для твоего провайдера. Попробуй `./switch_strategy.sh` или запусти `./blockcheck.sh` для диагностики.

**Ошибки iptables в логах** — контейнер требует `privileged: true` в compose-файле. Не убирай этот параметр.

## Авторы используемых компонентов

- [zapret](https://github.com/bol-van/zapret) — bol-van
- [sing-box](https://github.com/SagerNet/sing-box) — SagerNet
- Конфиги стратегий: [Snowy-Fluffy/zapret.cfgs](https://github.com/Snowy-Fluffy/zapret.cfgs)

## Лицензия

MIT
