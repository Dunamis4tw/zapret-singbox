#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.yml"
SERVICE="zapret-singbox"

echo "Сборка образа..."
docker compose -f "$COMPOSE_FILE" build

echo ""
echo "Запуск контейнера..."
docker compose -f "$COMPOSE_FILE" up -d "$SERVICE"

echo ""
docker compose -f "$COMPOSE_FILE" logs "$SERVICE"
