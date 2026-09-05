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

# Write EverMeMOS credentials for the everos stdio MCP launcher.
# stdio MCP children do not inherit container env vars and the Console UI
# rejects connector env keys such as EVERMEMOS_API_KEY, so the launcher
# (evermemos-launch.sh) reads these from a file instead. Refreshed on every
# start, so rotating EVEROS_API_KEY in Coolify + redeploy is enough.
if [ -n "${EVEROS_API_KEY:-}" ] || [ -n "${EVERMEMOS_API_KEY:-}" ]; then
    echo "[INFO] Writing EverMeMOS credentials file for the everos MCP launcher..."
    python3 - <<'PY'
import os, shlex
vals = {
    "EVERMEMOS_API_KEY": os.environ.get("EVEROS_API_KEY") or os.environ.get("EVERMEMOS_API_KEY") or "",
    "EVERMEMOS_USER_ID": os.environ.get("EVERMEMOS_USER_ID") or "omp-user",
    "EVERMEMOS_BASE_URL": os.environ.get("EVERMEMOS_BASE_URL") or "https://api.evermind.ai",
}
path = os.path.expanduser("~/.qoderwake/.everos/credentials.env")
os.makedirs(os.path.dirname(path), exist_ok=True)
os.chmod(os.path.dirname(path), 0o700)
with open(path, "w") as f:
    f.write("".join(f"export {k}={shlex.quote(v)}\n" for k, v in vals.items() if v))
os.chmod(path, 0o600)
PY
else
    echo "[WARN] EVEROS_API_KEY not set - the everos MCP connector will not authenticate."
fi

# Enable the browser connector and prepare the Chrome extension for download.
# The browser connector relay (port 16789) lets QoderWake control the user's
# local Chrome via a browser extension. We enable it here so it's ready when
# the daemon starts, and run the extension setup script so the files are
# packaged and waiting for `docker cp`.
echo "[INFO] Enabling browser connector..."
"$QODERWAKE_BIN" connector enable browser 2>/dev/null \
    || echo "[WARN] Could not auto-enable browser connector — enable it manually in the Console."

if [ -f "$HOME/.qoderwake/bin/setup-browser-extension.sh" ]; then
    echo "[INFO] Preparing browser extension for download..."
    bash "$HOME/.qoderwake/bin/setup-browser-extension.sh" 2>&1 || echo "[WARN] Extension setup failed — run setup-browser-extension.sh manually."
fi

# Determine host and port from environment or use defaults
HOST="${QODERWAKE_HOST:-0.0.0.0}"
PORT="${QODERWAKE_PORT:-19820}"

echo "[INFO] Starting QoderWake daemon on ${HOST}:${PORT}..."

# Stop any existing instance first (ignore errors)
"$QODERWAKE_BIN" stop --force 2>/dev/null || true
sleep 1

echo "========================================"
echo "  QoderWake is running!"
echo "  Web Console: http://<your-domain>:${PORT}/"
echo "========================================"

# Run the daemon directly as PID 1 — bypass the `start` command which
# tries to manage the process via systemd (unavailable in containers).
# `__daemon` is the actual HTTP server process that `start` spawns internally.
exec "$QODERWAKE_BIN" __daemon --host "$HOST" --port "$PORT"
