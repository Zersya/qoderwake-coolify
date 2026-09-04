#!/bin/bash
set -euo pipefail
# EverMeMOS stdio MCP launcher.
#
# QoderWake spawns stdio MCP servers with an allowlisted environment
# (HOME, LOGNAME, PATH, SHELL, TERM, USER) plus the connector's own env
# block, and the Console UI refuses connector env keys that look sensitive
# (token / secret / password / auth / credential), while evermemos-mcp
# hardcodes its key to EVERMEMOS_API_KEY. Credentials therefore cannot be
# delivered through the connector env block.
#
# Instead, entrypoint.sh writes them at container start (from the Coolify
# env vars) to $HOME/.qoderwake/.everos/credentials.env, and this launcher
# injects them before exec'ing the real server. Point the connector's
# "Command" at this file with empty args.
CREDS="${EVEROS_CREDS_FILE:-$HOME/.qoderwake/.everos/credentials.env}"
if [ -f "$CREDS" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$CREDS"
    set +a
fi
exec /home/qoderwake/.local/bin/uvx --with "mcp<2" --from "evermemos-mcp@latest" evermemos-mcp
