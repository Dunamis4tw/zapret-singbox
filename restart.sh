#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.yml"
SERVICE="zapret-singbox"

echo "Перезапуск контейнера $SERVICE..."
docker compose -f "$COMPOSE_FILE" restart "$SERVICE"

echo ""
docker compose -f "$COMPOSE_FILE" logs "$SERVICE"
