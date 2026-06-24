#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

NEXT_PID=""
WORKER_PID=""

cleanup() {
  echo ""
  echo "[start] Shutting down..."
  [[ -n "$NEXT_PID" ]] && kill "$NEXT_PID" 2>/dev/null || true
  [[ -n "$WORKER_PID" ]] && kill "$WORKER_PID" 2>/dev/null || true
  wait 2>/dev/null || true
  echo "[start] Done."
}
trap cleanup SIGINT SIGTERM EXIT

echo "[start] Starting Next.js server..."
node_modules/.bin/next start 2>&1 | tee "$LOG_DIR/next.log" &
NEXT_PID=$!

echo "[start] Waiting for server to be ready on port 3000..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:3000 > /dev/null 2>&1; then
    echo "[start] Server is up."
    break
  fi
  sleep 1
done

echo "[start] Starting worker..."
node_modules/.bin/tsx scripts/worker.ts 2>&1 | tee "$LOG_DIR/worker.log" &
WORKER_PID=$!

echo "[start] All services running. Press Ctrl+C to stop."
echo "[start]   Next.js PID : $NEXT_PID"
echo "[start]   Worker PID  : $WORKER_PID"
echo "[start]   Logs        : $LOG_DIR"

wait -n "$NEXT_PID" "$WORKER_PID"
EXIT_CODE=$?

if ! kill -0 "$NEXT_PID" 2>/dev/null; then
  echo "[start] Next.js exited unexpectedly (code $EXIT_CODE)"
fi
if ! kill -0 "$WORKER_PID" 2>/dev/null; then
  echo "[start] Worker exited unexpectedly (code $EXIT_CODE)"
fi

exit $EXIT_CODE
