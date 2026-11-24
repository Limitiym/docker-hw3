# ДЗ 3 по ИПР — Docker

## Запуск

cp .env.example .env
docker compose up -d --build

## Настройки

APP_PORT — порт приложения на хосте.
GREETING — текст приветствия.

## Проверка

curl http://localhost:8080/
curl -X POST http://localhost:8080/increment
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz

## Остановка

docker compose down

## Запуск с SQLite

docker compose -f compose.sqlite.yaml up -d --build

## Автоматическая проверка

./scripts/check.sh

Резервные копии сохраняются в backups/.
