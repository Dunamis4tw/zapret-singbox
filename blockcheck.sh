#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.yml"
SERVICE="zapret-singbox"
RESULTS_DIR="./blockcheck_results"

# ── Определяем текущую стратегию ──────────────────────────────────────────────
current=$(grep -oP 'ZAPRET_STRATEGY=\K\S+' "$COMPOSE_FILE" | head -1 || echo "unknown")

# ── Имя файла с датой и стратегией ────────────────────────────────────────────
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p "$RESULTS_DIR"
outfile="${RESULTS_DIR}/${timestamp}_${current}.log"

# ── Проверяем что контейнер запущен ───────────────────────────────────────────
container_id=$(docker compose -f "$COMPOSE_FILE" ps -q "$SERVICE" 2>/dev/null || true)
if [ -z "$container_id" ]; then
    echo "Контейнер $SERVICE не запущен. Запустите его сначала."
    exit 1
fi

echo "Запуск blockcheck в контейнере $SERVICE"
echo "Стратегия: $current"
echo "Лог сохраняется в: $outfile"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Останавливаем zapret внутри контейнера ────────────────────────────────────
echo "Останавливаем zapret внутри контейнера..."
docker compose -f "$COMPOSE_FILE" exec "$SERVICE" \
    /opt/zapret/init.d/sysv/zapret stop 2>&1 | tee -a "$outfile"

echo ""
echo "Запускаем blockcheck.sh (это займёт много времени)..."
echo ""

# ── Запускаем blockcheck с интерактивным TTY + одновременной записью в файл ───
# script -q /dev/null нужен чтобы blockcheck думал что есть TTY (для цветов и prompt'ов)
# tee пишет одновременно в консоль и файл
docker compose -f "$COMPOSE_FILE" exec -it "$SERVICE" \
    bash -c "bash /opt/zapret/blockcheck.sh 2>&1" \
    | tee -a "$outfile"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Blockcheck завершён."
echo "Результат сохранён в: $outfile"
