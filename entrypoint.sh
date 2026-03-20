#!/usr/bin/env bash
set -euo pipefail

ZAPRET_INIT="/opt/zapret/init.d/sysv/zapret"
SINGBOX_BIN="/opt/sing-box/sing-box"
SINGBOX_CONF="/opt/sing-box/configs/sing-box.conf"

ZAPRET_STRATEGY="${ZAPRET_STRATEGY:-general}"
ZAPRET_CONFIGS_DIR="/opt/zapret/zapret.cfgs/configurations"
ZAPRET_CONFIGS_BACKUP="/opt/zapret/zapret.cfgs/configurations.bak"
ZAPRET_CONFIG="/opt/zapret/config"

# ── Восстанавливаем конфиги zapret если volume пустой ──────────────────────────
if [ -z "$(ls -A "$ZAPRET_CONFIGS_DIR" 2>/dev/null)" ]; then
    echo "[entrypoint] Configurations dir is empty, restoring defaults..."
    cp -r "$ZAPRET_CONFIGS_BACKUP/." "$ZAPRET_CONFIGS_DIR/"
    echo "[entrypoint] Defaults restored"
fi

# ── Применяем стратегию ────────────────────────────────────────────────────────
if [ ! -f "$ZAPRET_CONFIGS_DIR/$ZAPRET_STRATEGY" ]; then
    echo "[entrypoint] ERROR: strategy '$ZAPRET_STRATEGY' not found in $ZAPRET_CONFIGS_DIR"
    echo "[entrypoint] Available strategies:"
    ls "$ZAPRET_CONFIGS_DIR"
    exit 1
fi

echo "[entrypoint] Applying strategy: $ZAPRET_STRATEGY"
cp "$ZAPRET_CONFIGS_DIR/$ZAPRET_STRATEGY" "$ZAPRET_CONFIG"

# ── Гарантируем FWTYPE=iptables ────────────────────────────────────────────────
if grep -q '^#*FWTYPE=' "$ZAPRET_CONFIG"; then
    sed -i "s/^#*FWTYPE=.*/FWTYPE=iptables/" "$ZAPRET_CONFIG"
else
    echo "FWTYPE=iptables" >> "$ZAPRET_CONFIG"
fi
echo "[entrypoint] FWTYPE=iptables confirmed"

# ── Graceful shutdown ──────────────────────────────────────────────────────────
cleanup() {
    echo "[entrypoint] Caught signal, shutting down..."
    kill "$SINGBOX_PID" 2>/dev/null || true
    "$ZAPRET_INIT" stop 2>/dev/null || true
    echo "[entrypoint] Done."
    exit 0
}
trap cleanup SIGTERM SIGINT

# ── 1. Стартуем zapret ─────────────────────────────────────────────────────────
echo "[entrypoint] Starting zapret..."
"$ZAPRET_INIT" start
echo "[entrypoint] zapret started"

# ── 2. Стартуем sing-box ───────────────────────────────────────────────────────
echo "[entrypoint] Starting sing-box..."
"$SINGBOX_BIN" run -c "$SINGBOX_CONF" &
SINGBOX_PID=$!
echo "[entrypoint] sing-box started (PID $SINGBOX_PID)"

# ── Ждём завершения sing-box ───────────────────────────────────────────────────
wait "$SINGBOX_PID"
echo "[entrypoint] sing-box exited, stopping zapret..."
"$ZAPRET_INIT" stop
