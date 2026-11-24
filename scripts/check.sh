#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="hw3-test-$$"
export APP_PORT=0
STAGE="initialization"

dc() {
    docker compose -p "$PROJECT" "$@"
}

cleanup() {
    local result=$?
    trap - EXIT

    if [ "$result" -ne 0 ]; then
        echo "FAILED: $STAGE" >&2
    fi

    dc down -v --remove-orphans || {
        echo "FAILED: cleanup" >&2
        result=1
    }

    if [ "$result" -eq 0 ]; then
        echo "ALL CHECKS PASSED"
    fi

    exit "$result"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

wait_ready() {
    for ((i=0; i<30; i++)); do
        if curl -fsS --max-time 3 "$URL/readyz" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

get_count() {
    curl -fsS --max-time 5 "$URL/" |
        dc exec -T app python -c \
        'import json, sys; print(json.load(sys.stdin)["count"])'
}

check_status() {
    local actual
    actual=$(curl -sS --max-time 5 -o /dev/null \
        -w '%{http_code}' -X "$1" "$URL$2")
    test "$actual" = "$3"
}

STAGE="startup"
dc up -d --build --wait --wait-timeout 90
PORT=$(dc port app 8000)
PORT=${PORT##*:}
URL="http://127.0.0.1:$PORT"

wait_ready

STAGE="initial counter"
test "$(get_count)" = 0
echo "Initial counter: 0"

STAGE="increment"
N=3
for ((i=1; i<=N; i++)); do
    curl -fsS --max-time 5 -X POST "$URL/increment"
    echo
done

test "$(get_count)" = "$N"
echo "Counter after increments: $N"

STAGE="app recreation"
dc up -d --no-deps --force-recreate app

PORT=$(dc port app 8000)
PORT=${PORT##*:}
URL="http://127.0.0.1:$PORT"

wait_ready
test "$(get_count)" = "$N"
echo "Counter survived app recreation"

STAGE="Redis failure"
dc stop redis

check_status GET /healthz 200
check_status GET /readyz 503
check_status GET / 503
check_status POST /increment 503
echo "Redis failure checks passed"

STAGE="Redis recovery"
dc start redis
wait_ready

test "$(get_count)" = "$N"

curl -fsS --max-time 5 -X POST "$URL/increment"
echo

test "$(get_count)" = "$((N+1))"
echo "Redis recovery passed"

STAGE="backup"
mkdir -p backups

dc stop app
dc stop redis

REDIS_ID=$(dc ps -a -q redis)
BACKUP="$PWD/backups/$PROJECT.tar.gz"

docker run --rm \
    --volumes-from "$REDIS_ID":ro \
    -v "$PWD/backups:/backup" \
    redis:7.4-alpine \
    tar -czf "/backup/$PROJECT.tar.gz" -C /data .

test -s "$BACKUP"
echo "Backup created: $BACKUP"

STAGE="cleanup"
