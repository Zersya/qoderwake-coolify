#!/bin/bash
set -e

QODERWAKE_HOME="$HOME/.qoderwake"
QODERWAKE_BIN="$QODERWAKE_HOME/qoderwake"

# Resolve the actual binary path
if [ ! -f "$QODERWAKE_BIN" ]; then
    QODERWAKE_BIN="$(command -v qoderwake 2>/dev/null || true)"
fi

if [ -z "$QODERWAKE_BIN" ] || [ ! -f "$QODERWAKE_BIN" ]; then
    echo "[FATAL] qoderwake binary not found. Build may have failed."
    exit 1
fi

echo "========================================"
echo "  QoderWake - Starting up..."
echo "========================================"

# Display version
echo "[INFO] QoderWake version:"
"$QODERWAKE_BIN" --version 2>/dev/null || echo "[WARN] Version check failed, continuing..."

# Handle authentication via Personal Access Token
if [ -n "$QODER_PERSONAL_ACCESS_TOKEN" ]; then
    echo "[INFO] Authenticating with Personal Access Token..."
    QODER_PERSONAL_ACCESS_TOKEN="$QODER_PERSONAL_ACCESS_TOKEN" \
        "$QODERWAKE_BIN" login --method token 2>&1 || {
        echo "[WARN] Token login failed. You can authenticate later via the Web UI."
    }
    echo "[INFO] Checking account..."
    "$QODERWAKE_BIN" whoami 2>&1 || echo "[WARN] Account check skipped."
elif [ -n "$QODER_TOKEN_FILE" ] && [ -f "$QODER_TOKEN_FILE" ]; then
    echo "[INFO] Authenticating with token file..."
    "$QODERWAKE_BIN" login --method file --token-file "$QODER_TOKEN_FILE" 2>&1 || {
        echo "[WARN] Token file login failed. You can authenticate later via the Web UI."
    }
else
    echo "[INFO] No QODER_PERSONAL_ACCESS_TOKEN or QODER_TOKEN_FILE set."
    echo "[INFO] You will need to authenticate via the Web UI after startup."
fi

# Determine host and port from environment or use defaults
HOST="${QODERWAKE_HOST:-0.0.0.0}"
PORT="${QODERWAKE_PORT:-19820}"

echo "[INFO] Starting QoderWake on ${HOST}:${PORT}..."

# Stop any existing instance first (ignore errors)
"$QODERWAKE_BIN" stop --force 2>/dev/null || true
sleep 1

# Start QoderWake — auto-confirm the 0.0.0.0 binding warning
echo "yes" | "$QODERWAKE_BIN" start --host "$HOST" --port "$PORT" 2>&1 || {
    echo "[WARN] First start attempt failed, retrying..."
    sleep 3
    echo "yes" | "$QODERWAKE_BIN" start --host "$HOST" --port "$PORT" 2>&1 || {
        echo "[FATAL] QoderWake failed to start."
        exit 1
    }
}

echo "========================================"
echo "  QoderWake is running!"
echo "  Web Console: http://<your-domain>:${PORT}/"
echo "========================================"

# Keep the container alive — QoderWake runs as a background service
while true; do
    if ! "$QODERWAKE_BIN" status 2>/dev/null | grep -qi "running"; then
        echo "[WARN] QoderWake stopped unexpectedly. Restarting..."
        echo "yes" | "$QODERWAKE_BIN" start --host "$HOST" --port "$PORT" 2>&1 || true
    fi
    sleep 30
done
