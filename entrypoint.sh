#!/bin/bash
set -e

echo "========================================"
echo "  QoderWake - Starting up..."
echo "========================================"

# Display version
echo "[INFO] QoderWake version:"
~/.qoderwake/bin/qoderwake --version 2>/dev/null || echo "[WARN] Version check failed, continuing..."

# Handle authentication via Personal Access Token
if [ -n "$QODER_PERSONAL_ACCESS_TOKEN" ]; then
    echo "[INFO] Authenticating with Personal Access Token..."
    QODER_PERSONAL_ACCESS_TOKEN="$QODER_PERSONAL_ACCESS_TOKEN" \
        ~/.qoderwake/bin/qoderwake login --method token 2>/dev/null || {
        echo "[WARN] Token login failed. You can authenticate later via the Web UI."
    }
    echo "[INFO] Checking account..."
    ~/.qoderwake/bin/qoderwake whoami 2>/dev/null || echo "[WARN] Account check skipped."
elif [ -n "$QODER_TOKEN_FILE" ] && [ -f "$QODER_TOKEN_FILE" ]; then
    echo "[INFO] Authenticating with token file..."
    ~/.qoderwake/bin/qoderwake login --method file --token-file "$QODER_TOKEN_FILE" 2>/dev/null || {
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
echo "[INFO] Web Console will be available at http://<your-domain>:${PORT}/"

# Start QoderWake and accept the network exposure prompt automatically
# Using 'yes' to auto-confirm the 0.0.0.0 binding warning
echo "yes" | ~/.qoderwake/bin/qoderwake start --host "$HOST" --port "$PORT" 2>&1 || {
    echo "[ERROR] Failed to start QoderWake. Attempting restart..."
    ~/.qoderwake/bin/qoderwake stop --force 2>/dev/null || true
    sleep 2
    echo "yes" | ~/.qoderwake/bin/qoderwake start --host "$HOST" --port "$PORT" 2>&1 || {
        echo "[FATAL] QoderWake failed to start."
        exit 1
    }
}

echo "========================================"
echo "  QoderWake is running!"
echo "  Web Console: http://<your-domain>:${PORT}/"
echo "========================================"

# Keep the container alive by tailing the log or waiting
# QoderWake runs as a background service, so we need to keep the container running
while true; do
    # Check if QoderWake is still running
    if ! ~/.qoderwake/bin/qoderwake status 2>/dev/null | grep -qi "running"; then
        echo "[WARN] QoderWake service stopped unexpectedly. Restarting..."
        echo "yes" | ~/.qoderwake/bin/qoderwake start --host "$HOST" --port "$PORT" 2>&1 || true
    fi
    sleep 30
done
