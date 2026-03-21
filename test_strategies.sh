#!/usr/bin/env bash
#set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# НАСТРОЙКИ — редактируй здесь
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PROXY="http://127.0.0.1:7890"           # sing-box mixed proxy
CURL_TIMEOUT=5                          # секунд на весь запрос
CURL_CONNECT_TIMEOUT=4                  # секунд на установку соединения
RESTART_WAIT=4                          # секунд ждать после перезапуска контейнера

# Список сайтов для проверки (URL или домен — скрипт сам добавит https://)
DEFAULT_SITES=(
    "https://rutracker.org"
    "https://discord.com"
    "https://youtube.com"
    "https://x.com"
    "https://instagram.com"
    "https://t.me"
    "https://store.steampowered.com"
    # Добавляй свои сайты сюда:
    # "https://example.com"
)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

COMPOSE_FILE="docker-compose.yml"
SERVICE="zapret-singbox"
RESULTS_DIR="./strategy_test_results"
STRATEGIES_DIR="./configs/zapret"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Вспомогательные функции ────────────────────────────────────────────────────

str_len() { echo -n "$1" | wc -m; }

log() {
    local msg="$1"
    local file="$2"
    echo -e "$msg" | tee -a "$file"
}

log_plain() {
    local msg="$1"
    local file="$2"
    # В файл — без ANSI escape-кодов
    echo -e "$msg" >> "$file"
    echo -e "$msg"
}

strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# ── Вывод пронумерованного списка в колонки ────────────────────────────────────
print_list() {
    local -n _arr=$1
    local current="${2:-}"
    local total=${#_arr[@]}

    local max_len=0
    for s in "${_arr[@]}"; do
        local len; len=$(str_len "$s")
        (( len > max_len )) && max_len=$len
    done

    local COLS
    if [ "$total" -le 20 ]; then COLS=1; else COLS=3; fi
    local rows=$(( (total + COLS - 1) / COLS ))
    local col_width=$(( max_len + 8 ))

    for (( row=0; row<rows; row++ )); do
        local line=""
        for (( col=0; col<COLS; col++ )); do
            local idx=$(( col * rows + row ))
            [ "$idx" -ge "$total" ] && break
            local name="${_arr[$idx]}"
            local num=$(( idx + 1 ))

            if [ "$name" = "$current" ]; then
                local label="▶ ${num}) ${name}"
            else
                local label="  ${num}) ${name}"
            fi

            local label_len; label_len=$(str_len "$label")
            local pad=$(( col_width - label_len ))
            printf "%s" "$label"
            if [ $col -lt $(( COLS - 1 )) ] && [ $(( (col+1)*rows + row )) -lt "$total" ]; then
                printf "%${pad}s" ""
            fi
        done
        echo ""
    done
}

# ── Парсинг диапазонов типа "1,3,10-20,22" ────────────────────────────────────
parse_selection() {
    local input="$1"
    local max="$2"
    local -a result=()

    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        part="${part// /}"
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local from="${BASH_REMATCH[1]}"
            local to="${BASH_REMATCH[2]}"
            for (( i=from; i<=to; i++ )); do
                (( i >= 1 && i <= max )) && result+=("$i")
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            (( part >= 1 && part <= max )) && result+=("$part")
        fi
    done

    # Уникальные значения, отсортированные
    printf '%s\n' "${result[@]}" | sort -un | tr '\n' ' '
}

# ── Проверка одного сайта через curl ──────────────────────────────────────────
check_site() {
    local url="$1"
    local logfile="$2"

    # Добавляем https:// если не указан протокол
    [[ "$url" =~ ^https?:// ]] || url="https://${url}"

    local http_code exit_code curl_error
    local tmpfile; tmpfile=$(mktemp)

    http_code=$(curl \
        --proxy "$PROXY" \
        --max-time "$CURL_TIMEOUT" \
        --connect-timeout "$CURL_CONNECT_TIMEOUT" \
        --silent \
        --output /dev/null \
        --write-out "%{http_code}" \
        --location \
        --insecure \
        2>"$tmpfile" \
        "$url") || exit_code=$?
    exit_code="${exit_code:-0}"
    curl_error=$(cat "$tmpfile")
    rm -f "$tmpfile"

    local short_url
    short_url=$(echo "$url" | sed 's|https\?://||;s|/.*||')
    local padded
    padded=$(printf "%-25s" "$short_url")

    if [ "$exit_code" -eq 0 ] && [[ "$http_code" =~ ^[23] ]]; then
        local msg="    ${GREEN}✔${NC}  ${padded}  HTTP ${http_code}"
        echo -e "$msg"
        echo "    ✔  ${padded}  HTTP ${http_code}" >> "$logfile"
    elif [ "$exit_code" -eq 0 ] && [[ "$http_code" =~ ^[45] ]]; then
        local msg="    ${YELLOW}~${NC}  ${padded}  HTTP ${http_code} (сайт ответил, но ошибка)"
        echo -e "$msg"
        echo "    ~  ${padded}  HTTP ${http_code} (сайт ответил, но ошибка)" >> "$logfile"
    elif [ "$exit_code" -eq 28 ]; then
        local msg="    ${RED}✘${NC}  ${padded}  TIMEOUT (>${CURL_TIMEOUT}s)"
        echo -e "$msg"
        echo "    ✘  ${padded}  TIMEOUT (>${CURL_TIMEOUT}s)" >> "$logfile"
    elif [ "$exit_code" -eq 7 ]; then
        local msg="    ${RED}✘${NC}  ${padded}  Не удалось подключиться к прокси"
        echo -e "$msg"
        echo "    ✘  ${padded}  Не удалось подключиться к прокси" >> "$logfile"
    elif [ "$exit_code" -eq 35 ] || [ "$exit_code" -eq 60 ]; then
        local msg="    ${YELLOW}~${NC}  ${padded}  TLS ошибка (exit ${exit_code})"
        echo -e "$msg"
        echo "    ~  ${padded}  TLS ошибка (exit ${exit_code})" >> "$logfile"
    else
        local msg="    ${RED}✘${NC}  ${padded}  Ошибка (exit ${exit_code}: ${curl_error})"
        echo -e "$msg"
        echo "    ✘  ${padded}  Ошибка (exit ${exit_code}: ${curl_error})" >> "$logfile"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Проверяем что контейнер запущен
container_id=$(docker compose -f "$COMPOSE_FILE" ps -q "$SERVICE" 2>/dev/null || true)
if [ -z "$container_id" ]; then
    echo -e "${RED}❌ Контейнер $SERVICE не запущен.${NC}"
    exit 1
fi

# Текущая стратегия
current_strategy=$(grep -oP 'ZAPRET_STRATEGY=\K\S+' "$COMPOSE_FILE" | head -1 || echo "")

# Список стратегий
mapfile -t all_strategies < <(ls "$STRATEGIES_DIR" | sort)
total_strats=${#all_strategies[@]}

# ── Шаг 1: выбор стратегий ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━ Шаг 1: Выбор стратегий ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
print_list all_strategies "$current_strategy"
echo ""
[ -n "$current_strategy" ] && echo -e "  ${DIM}▶ — текущая стратегия: $current_strategy${NC}"
echo ""
read -rp "Введите номера стратегий [1-${total_strats}] (диапазоны: 1,3,10-20 | Enter = все): " strat_input

if [ -z "$strat_input" ]; then
    selected_strat_indices=$(seq 1 "$total_strats" | tr '\n' ' ')
else
    selected_strat_indices=$(parse_selection "$strat_input" "$total_strats")
fi

if [ -z "$selected_strat_indices" ]; then
    echo -e "${RED}❌ Не выбрано ни одной стратегии.${NC}"
    exit 1
fi

# Собираем массив выбранных стратегий
selected_strategies=()
for i in $selected_strat_indices; do
    selected_strategies+=("${all_strategies[$(( i - 1 ))]}")
done

echo ""
echo -e "  Выбрано стратегий: ${BOLD}${#selected_strategies[@]}${NC}"

# ── Шаг 2: выбор сайтов ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━ Шаг 2: Выбор сайтов ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

site_list=("${DEFAULT_SITES[@]}")
for i in "${!site_list[@]}"; do
    printf "  %2d) %s\n" "$(( i + 1 ))" "${site_list[$i]}"
done
echo ""

read -rp "Добавить свои сайты? (через запятую, или Enter чтобы пропустить): " extra_sites
if [ -n "$extra_sites" ]; then
    IFS=',' read -ra extras <<< "$extra_sites"
    for s in "${extras[@]}"; do
        s="${s// /}"
        [ -n "$s" ] && site_list+=("$s")
    done
fi

total_sites=${#site_list[@]}
echo ""
read -rp "Введите номера сайтов [1-${total_sites}] (диапазоны: 1,3-5 | Enter = все): " site_input

if [ -z "$site_input" ]; then
    selected_site_indices=$(seq 1 "$total_sites" | tr '\n' ' ')
else
    selected_site_indices=$(parse_selection "$site_input" "$total_sites")
fi

if [ -z "$selected_site_indices" ]; then
    echo -e "${RED}❌ Не выбрано ни одного сайта.${NC}"
    exit 1
fi

selected_sites=()
for i in $selected_site_indices; do
    selected_sites+=("${site_list[$(( i - 1 ))]}")
done

echo ""
echo -e "  Выбрано сайтов: ${BOLD}${#selected_sites[@]}${NC}"
for s in "${selected_sites[@]}"; do echo "    • $s"; done

# ── Подготовка файла результатов ──────────────────────────────────────────────
mkdir -p "$RESULTS_DIR"
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
logfile="${RESULTS_DIR}/${timestamp}_test.log"

{
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Тест стратегий zapret"
    echo "Дата: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Стратегий: ${#selected_strategies[@]}"
    echo "Сайтов: ${#selected_sites[@]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
} >> "$logfile"

echo ""
echo -e "${BOLD}━━━ Запуск тестирования ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${DIM}Лог: $logfile${NC}"
echo ""
read -rp "Начать? [Y/n]: " confirm
[[ "$confirm" =~ ^[Nn]$ ]] && exit 0

# ── Сводная таблица результатов (в памяти) ────────────────────────────────────
declare -A summary   # summary[strategy|site] = "✔"|"~"|"✘"

# ── Шаг 3: перебираем стратегии ───────────────────────────────────────────────
strat_num=0
for strategy in "${selected_strategies[@]}"; do
    (( strat_num++ ))

    echo "" | tee -a "$logfile"
    echo -e "${CYAN}${BOLD}[${strat_num}/${#selected_strategies[@]}] Стратегия: ${strategy}${NC}" | tee -a "$logfile"
    echo "────────────────────────────────────────────" | tee -a "$logfile"

    # Меняем стратегию в compose и перезапускаем контейнер
    sed -i "s/ZAPRET_STRATEGY=.*/ZAPRET_STRATEGY=${strategy}     # Стратегия/" "$COMPOSE_FILE"
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate "$SERVICE" > /dev/null 2>&1
    echo -e "  ${DIM}Ждём ${RESTART_WAIT}с после перезапуска...${NC}"
    sleep "$RESTART_WAIT"

    # Проверяем каждый сайт
    for site in "${selected_sites[@]}"; do
        check_site "$site" "$logfile"
    done

    echo "────────────────────────────────────────────" | tee -a "$logfile"
done

# ── Сводка ────────────────────────────────────────────────────────────────────
echo "" | tee -a "$logfile"
echo -e "${BOLD}━━━ Готово ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$logfile"
echo -e "📁 Результаты: ${logfile}" | tee -a "$logfile"
echo "" | tee -a "$logfile"
echo -e "${DIM}  ${GREEN}✔${NC}${DIM} = HTTP 2xx/3xx   ${YELLOW}~${NC}${DIM} = HTTP 4xx/5xx или TLS   ${RED}✘${NC}${DIM} = таймаут / нет соединения${NC}"

# Восстанавливаем исходную стратегию если она была
if [ -n "$current_strategy" ]; then
    echo ""
    read -rp "Восстановить исходную стратегию ($current_strategy)? [Y/n]: " restore
    if [[ ! "$restore" =~ ^[Nn]$ ]]; then
        sed -i "s/ZAPRET_STRATEGY=.*/ZAPRET_STRATEGY=${current_strategy}     # Стратегия/" "$COMPOSE_FILE"
        docker compose -f "$COMPOSE_FILE" up -d --force-recreate "$SERVICE" > /dev/null 2>&1
        echo -e "✅ Восстановлена стратегия: ${current_strategy}"
    fi
fi
