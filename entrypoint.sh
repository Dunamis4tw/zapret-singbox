#!/usr/bin/env bash
set -euo pipefail

ZAPRET_INIT="/opt/zapret/init.d/sysv/zapret"
SINGBOX_BIN="/opt/sing-box/sing-box"
SINGBOX_CONF="/opt/sing-box/configs/sing-box.conf"

# Стратегия по умолчанию используется если ZAPRET_STRATEGY не задан в environment
ZAPRET_STRATEGY="${ZAPRET_STRATEGY:-general}"
ZAPRET_CONFIGS_DIR="/opt/zapret/zapret.cfgs/configurations"
ZAPRET_CONFIGS_BACKUP="/opt/zapret/zapret.cfgs/configurations.bak"
ZAPRET_CONFIG="/opt/zapret/config"

SINGBOX_CONFIGS_DIR="/opt/sing-box/configs"
SINGBOX_CONFIGS_BACKUP="/opt/sing-box/configs.bak"

# ---------------------------------------------------------------------------
# Восстановление конфигов zapret
# Срабатывает если volume подключён но пустой, либо volume не подключён вовсе
# ---------------------------------------------------------------------------
if [ -z "$(ls -A "$ZAPRET_CONFIGS_DIR" 2>/dev/null)" ]; then
    echo "[entrypoint] Директория стратегий пуста, восстанавливаем дефолтные..."
    cp -r "$ZAPRET_CONFIGS_BACKUP/." "$ZAPRET_CONFIGS_DIR/"
    echo "[entrypoint] Стратегии восстановлены"
fi

# ---------------------------------------------------------------------------
# Восстановление конфига sing-box
# Срабатывает если volume подключён но пустой, либо volume не подключён вовсе
# ---------------------------------------------------------------------------
if [ -z "$(ls -A "$SINGBOX_CONFIGS_DIR" 2>/dev/null)" ]; then
    echo "[entrypoint] Директория конфигов sing-box пуста, восстанавливаем дефолтный..."
    cp -r "$SINGBOX_CONFIGS_BACKUP/." "$SINGBOX_CONFIGS_DIR/"
    echo "[entrypoint] Конфиг sing-box восстановлен"
fi

# ---------------------------------------------------------------------------
# Применение стратегии zapret
# ---------------------------------------------------------------------------
if [ ! -f "$ZAPRET_CONFIGS_DIR/$ZAPRET_STRATEGY" ]; then
    echo "[entrypoint] Ошибка: стратегия '$ZAPRET_STRATEGY' не найдена в $ZAPRET_CONFIGS_DIR"
    echo "[entrypoint] Доступные стратегии:"
    ls "$ZAPRET_CONFIGS_DIR"
    exit 1
fi

echo "[entrypoint] Применяем стратегию: $ZAPRET_STRATEGY"
cp "$ZAPRET_CONFIGS_DIR/$ZAPRET_STRATEGY" "$ZAPRET_CONFIG"

# ---------------------------------------------------------------------------
# Принудительно устанавливаем FWTYPE=iptables
# Часть стратегий может содержать другое значение или не содержать эту строку
# ---------------------------------------------------------------------------
if grep -q '^#*FWTYPE=' "$ZAPRET_CONFIG"; then
    sed -i "s/^#*FWTYPE=.*/FWTYPE=iptables/" "$ZAPRET_CONFIG"
else
    echo "FWTYPE=iptables" >> "$ZAPRET_CONFIG"
fi
echo "[entrypoint] FWTYPE=iptables установлен"

# ---------------------------------------------------------------------------
# Обработчик сигналов завершения
# ---------------------------------------------------------------------------
cleanup() {
    echo "[entrypoint] Получен сигнал завершения, останавливаем сервисы..."
    kill "$SINGBOX_PID" 2>/dev/null || true
    "$ZAPRET_INIT" stop 2>/dev/null || true
    echo "[entrypoint] Остановка завершена"
    exit 0
}
trap cleanup SIGTERM SIGINT

# ---------------------------------------------------------------------------
# Запуск zapret
# ---------------------------------------------------------------------------
echo "[entrypoint] Запускаем zapret..."
"$ZAPRET_INIT" start
echo "[entrypoint] zapret запущен"

# ---------------------------------------------------------------------------
# Запуск sing-box
# ---------------------------------------------------------------------------
echo "[entrypoint] Запускаем sing-box..."
"$SINGBOX_BIN" run -c "$SINGBOX_CONF" &
SINGBOX_PID=$!
echo "[entrypoint] sing-box запущен (PID $SINGBOX_PID)"

# Ожидаем завершения sing-box (нормального или по сигналу)
wait "$SINGBOX_PID"
echo "[entrypoint] sing-box завершился, останавливаем zapret..."
"$ZAPRET_INIT" stop