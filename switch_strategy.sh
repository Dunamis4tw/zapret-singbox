#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.yml"
SERVICE="zapret-singbox"
STRATEGIES_DIR="./configs/zapret"

# ── Получаем текущую стратегию из compose файла ────────────────────────────────
current=$(grep -oP 'ZAPRET_STRATEGY=\K\S+' "$COMPOSE_FILE" | head -1 || echo "")

# ── Читаем список стратегий ────────────────────────────────────────────────────
mapfile -t strategies < <(ls "$STRATEGIES_DIR" | sort)
total=${#strategies[@]}

if [ "$total" -eq 0 ]; then
    echo "❌ Стратегии не найдены в $STRATEGIES_DIR"
    exit 1
fi

# ── Вывод списка стратегий ─────────────────────────────────────────────────────
echo ""
echo "📋 Доступные стратегии:"
echo ""

# Функция: длина строки в символах (не байтах), для корректной работы с UTF-8
str_len() {
    echo -n "$1" | wc -m
}

# Ширина колонки — максимальная длина имени + отступ
max_len=0
for s in "${strategies[@]}"; do
    len=$(str_len "$s")
    (( len > max_len )) && max_len=$len
done
col_width=$(( max_len + 4 ))  # отступ между колонками

# Определяем количество колонок
if [ "$total" -le 20 ]; then
    COLS=1
else
    COLS=3
fi

# Количество строк в каждой колонке
rows=$(( (total + COLS - 1) / COLS ))

# Нумеруем и выводим построчно, по колонкам
for (( row=0; row<rows; row++ )); do
    line=""
    for (( col=0; col<COLS; col++ )); do
        idx=$(( col * rows + row ))
        if [ "$idx" -ge "$total" ]; then
            break
        fi
        name="${strategies[$idx]}"
        num=$(( idx + 1 ))

        # Метка текущей стратегии
        if [ "$name" = "$current" ]; then
            label="▶ ${num}) ${name}"
        else
            label="  ${num}) ${name}"
        fi

        # Дополняем пробелами до нужной ширины (по символам, не байтам)
        label_len=$(str_len "$label")
        pad=$(( col_width + 5 - label_len ))  # +5 для номера и скобки
        printf "%s" "$label"
        if [ $col -lt $(( COLS - 1 )) ] && [ $(( (col+1)*rows + row )) -lt "$total" ]; then
            printf "%${pad}s" ""
        fi
    done
    echo ""
done

echo ""
[ -n "$current" ] && echo "▶  — текущая стратегия: $current"
echo ""

# ── Выбор пользователя ─────────────────────────────────────────────────────────
while true; do
    read -rp "Введите номер стратегии [1-${total}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
        selected="${strategies[$(( choice - 1 ))]}"
        break
    fi
    echo "❌ Неверный ввод, попробуйте ещё раз."
done

echo ""
echo "⚙️  Выбрана стратегия: $selected"

if [ "$selected" = "$current" ]; then
    echo "⚠️  Это уже текущая стратегия. Всё равно перезапустить?"
    read -rp "[y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

# ── Подставляем стратегию в compose файл ──────────────────────────────────────
# Работает как с закомментированной строкой, так и с обычной
sed -i "s/ZAPRET_STRATEGY=.*/ZAPRET_STRATEGY=${selected}     # Стратегия/" "$COMPOSE_FILE"
echo "✅ docker-compose.yml обновлён"

# ── Перезапуск контейнера ──────────────────────────────────────────────────────
echo ""
echo "🔄 Перезапуск контейнера..."
docker compose -f "$COMPOSE_FILE" up -d --force-recreate "$SERVICE"

echo ""
echo "✅ Контейнер перезапущен со стратегией: $selected"
